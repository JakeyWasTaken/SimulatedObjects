--[[

AddObject: () -> ()
AddVolume: () -> ()
AddCollider: () -> ()

]]

local SPRING_POOL_SIZE = 2 ^ 9
local MAX_FRAME_COUNT = 2 ^ 17

shared.__FRAME_COUNT = 0

local HttpService = game:GetService("HttpService")

local Types = require(script.Types)

local Log = require(script.Utils.Log)
local Octree = require(script.Dependencies.Octree)
local Spring = require(script.Dependencies.Spring)

local Collider = require(script.Components.Collider)
local Object = require(script.Components.Object)
local Volume = require(script.Components.Volume)

local SimulatedObjects = {
	FreeSpringPool = {}, -- Pool of springs not in use
	HotSpringPool = {}, -- Pool of springs in use
	Objects = {},
	Volumes = {},
	Colliders = {},
	ActiveColliderIdsLastFrame = {},
	Octree = Octree.new(),
}

function SimulatedObjects.GenerateId(): Types.Id
	return HttpService:GenerateGUID(false):sub(1, 8)
end

function SimulatedObjects.AddObject(ObjectData: Types.ObjectData)
	local Id = SimulatedObjects.GenerateId()
	local Object = Object.new(ObjectData)
	Object.Id = Id

	SimulatedObjects.Objects[Id] = Object
	SimulatedObjects.Octree:CreateNode((Object.InitialTransform * Object.ApexOffset).Position, Id)
end

function SimulatedObjects.AddVolume(VolumeData: Types.VolumeData)
	local Id = SimulatedObjects.GenerateId()
	local Volume = Volume(VolumeData)
	Volume.Id = Id

	SimulatedObjects.Volumes[Id] = Volume
end

function SimulatedObjects.AddCollider(ColliderData: Types.ColliderData)
	local Id = SimulatedObjects.GenerateId()
	local Collider = Collider.new(ColliderData)
	Collider.Id = Id

	SimulatedObjects.Colliders[Id] = Collider
end

function SimulatedObjects.Step(Delta: number)
	shared.__FRAME_COUNT = shared.__FRAME_COUNT + 1 % MAX_FRAME_COUNT

	--[[
		Function flow
		- Figure out what colliders are within our check radius
		- If a collider we checked last frame isnt in this frame then un assign all its stuff
		- Check collider streamables
		-

	]]

	local CHECK_RADIUS = 100
	local Camera = workspace.CurrentCamera

	local FreeSpringPool = SimulatedObjects.FreeSpringPool
	local HotSpringPool = SimulatedObjects.HotSpringPool

	local ObjectOctree = SimulatedObjects.Octree
	local WorldObjects = SimulatedObjects.Objects
	local WorldColliders = SimulatedObjects.Colliders
	local ActiveColliders: { Types.Id } = {}

	for _, Collider in SimulatedObjects.Colliders do
		local Center = Collider:GetCenter()

		if (Camera.CFrame.Position - Center.Position).Magnitude <= CHECK_RADIUS then
			table.insert(ActiveColliders, Collider.Id)
		end
	end

	debug.profilebegin("Get relationship streaming jobs")

	local ReleaseStreamJobs: Types.StreamRelationshipJobs = {}
	local AssignStreamJobs: Types.StreamRelationshipJobs = {}

	debug.profilebegin("In-active colliders")
	-- Find what colliders are no longer active and give them stream jobs
	for _, ColliderId in SimulatedObjects.ActiveColliderIdsLastFrame do
		if table.find(ActiveColliders, ColliderId) then
			continue
		end

		debug.profilebegin(ColliderId)
		local Collider = WorldColliders[ColliderId]
		local WasStreaming = Collider:GetStreaming()

		if #WasStreaming > 0 then
			table.insert(ReleaseStreamJobs, { ColliderId = ColliderId, ObjectIds = WasStreaming })
		end
		debug.profileend()
	end
	debug.profileend()

	debug.profilebegin("Active colliders")
	-- Get streamables of active colliders
	for _, ColliderId in ActiveColliders do
		debug.profilebegin(ColliderId)
		local Collider = WorldColliders[ColliderId]

		local StreamIn, StreamOut = Collider:GetStreamables(ObjectOctree)

		if #StreamIn > 0 then
			table.insert(AssignStreamJobs, { ColliderId = ColliderId, ObjectIds = StreamIn })
		end

		if #StreamOut > 0 then
			table.insert(ReleaseStreamJobs, { ColliderId = ColliderId, ObjectIds = StreamOut })
		end
		debug.profileend()
	end
	debug.profileend()

	debug.profileend()

	-- ------------------------ Resolve relationship jobs ----------------------- --
	local StreamOutJobs: Types.StreamOutJobs = {}
	local StreamInJobs: Types.StreamInJobs = {}
	local StreamingJobsCount = 0

	if #ReleaseStreamJobs > 0 or #AssignStreamJobs > 0 then
		debug.profilebegin("Resolve relationship jobs")

		local BulkObjectReleaseJobs: Types.BulkObjectStreamRelationshipJobs = {}
		local BulkObjectAssignJobs: Types.BulkObjectStreamRelationshipJobs = {}

		debug.profilebegin("Release")
		for _, Job in ReleaseStreamJobs do
			local ColliderId = Job.ColliderId
			local ObjectIds = Job.ObjectIds

			debug.profilebegin(ColliderId)
			local Collider = WorldColliders[ColliderId]
			Collider:ReleaseObjects(ObjectIds)

			for _, ObjectId in ObjectIds do
				if BulkObjectReleaseJobs[ObjectId] then
					table.insert(BulkObjectReleaseJobs[ObjectId], ColliderId)
				else
					BulkObjectReleaseJobs[ObjectId] = { ColliderId }
				end
			end
			debug.profileend()
		end
		debug.profileend()

		debug.profilebegin("Assign")
		for _, Job in AssignStreamJobs do
			local ColliderId = Job.ColliderId
			local ObjectIds = Job.ObjectIds

			debug.profilebegin(ColliderId)
			local Collider = WorldColliders[ColliderId]
			Collider:AssignObjects(ObjectIds)

			for _, ObjectId in ObjectIds do
				if BulkObjectAssignJobs[ObjectId] then
					table.insert(BulkObjectAssignJobs[ObjectId], ColliderId)
				else
					BulkObjectAssignJobs[ObjectId] = { ColliderId }
				end
			end
			debug.profileend()
		end
		debug.profileend()

		-- Manage bulk object jobs

		debug.profilebegin("Manage bulk object jobs")

		debug.profilebegin("Release")
		for ObjectId, ColliderIds in BulkObjectReleaseJobs do
			debug.profilebegin(ObjectId)
			local Object = WorldObjects[ObjectId]
			Object:ReleaseSimulatingColliders(ColliderIds)

			if Object:CanStreamOut() then
				StreamOutJobs[ObjectId] = true
				StreamingJobsCount += 1
			end
			debug.profileend()
		end
		debug.profileend()

		debug.profilebegin("Assign")
		for ObjectId, ColliderIds in BulkObjectAssignJobs do
			debug.profilebegin(ObjectId)
			local Object = WorldObjects[ObjectId]
			Object:AssignSimulatingColliders(ColliderIds)

			-- This covers a very specific edge case where the same frame where a
			-- collider releases this object another is assigned to it.
			if StreamOutJobs[ObjectId] then
				StreamOutJobs[ObjectId] = nil
				StreamingJobsCount -= 1
			end

			if not Object.Simulating then
				StreamInJobs[ObjectId] = true
				StreamingJobsCount += 1
			end
			debug.profileend()
		end
		debug.profileend()

		debug.profileend()
		debug.profileend()
	end

	-- ------------------------- Resolve streaming jobs ------------------------- --
	if StreamingJobsCount > 0 then
		for ObjectId in StreamOutJobs do
			local Object = WorldObjects[ObjectId]
			local SpringId, NeedsReset = Object:StreamOut()

			-- TODO: add the code to bulk move to / pivot to the objects back to their initial transforms

			local Spring = HotSpringPool[SpringId]
			HotSpringPool[SpringId] = nil

			table.insert(FreeSpringPool, Spring)
		end

		for ObjectId in StreamInJobs do
			local Object = WorldObjects[ObjectId]

			local Spring = table.remove(FreeSpringPool)
			local SpringId = #HotSpringPool + 1

			table.insert(HotSpringPool, Spring)

			Object:StreamIn(Spring, SpringId)
		end
	end
end

-- Populate Spring Pool
Log.debug(`Populating free spring pool with {SPRING_POOL_SIZE} springs`)
for _ = 1, SPRING_POOL_SIZE do
	table.insert(SimulatedObjects.FreeSpringPool, Spring.create())
end

return SimulatedObjects
