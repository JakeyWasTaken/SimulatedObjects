--!native

local SPRING_POOL_SIZE = 2 ^ 12
local MAX_FRAME_COUNT = 2 ^ 17

shared.__FRAME_COUNT = 0

local HttpService = game:GetService("HttpService")

local Config = require(script.Config)
local Types = require(script.Types)

local Log = require(script.Utils.Log)
local Octree = require(script.Dependencies.Octree)
local Spring = require(script.Dependencies.Spring)

local Collider = require(script.Components.Collider)
local Object = require(script.Components.Object)
local Volume = require(script.Components.Volume)

local function ConvertVector(Vector): vector
	return vector.create(Vector.X, Vector.Y, Vector.Z)
end

local CAMERA_ACTIVE_RADIUS = Config.CAMERA_ACTIVE_RADIUS
local WIND_ACTIVE_RADIUS = Config.WIND_ACTIVE_RADIUS
local OBJECT_UPDATE_RATE = Config.OBJECT_UPDATE_RATE
local THROTTLED_OBJECT_UPDATE_RATE = Config.THROTTLED_OBJECT_UPDATE_RATE
local THROTTLING_START_RADIUS = Config.THROTTLING_START_RADIUS
local WIND_SEED_WRAP = Config.WIND_SEED_WRAP

local SimulatedObjects = {
	FreeSpringPool = {}, -- Pool of springs not in use
	HotSpringPool = {}, -- Pool of springs in use, non-contiguous
	SimulatingObjectIds = {}, -- Dictionary of object ids that are streamed in

	RemovingColliders = {}, -- Dictionary of colliders to be removed on the next step cycle
	ActiveColliderIdsLastFrame = {},

	-- Wind Related
	WindCache = {}, -- Dictionary of [WindSeed] = RotationCFrame for objects
	WindSimulatedLastFrame = {},
	WindSimulated = 0,

	BulkObjects = table.create(500),
	BulkCFrames = table.create(500),
	BulkModels = table.create(500),
	BulkModelCFrames = table.create(500),

	-- World
	Objects = {},
	Volumes = {},
	Colliders = {},
	Octree = Octree.new(),
}

function SimulatedObjects.GenerateId(Prefix: string): Types.Id
	return `{Prefix}{HttpService:GenerateGUID(false):sub(1, 8)}`
end

function SimulatedObjects.AddObject(ObjectData: Types.ObjectData)
	local Id = SimulatedObjects.GenerateId("o_")
	local Object = Object.new(ObjectData)
	Object.Id = Id

	SimulatedObjects.Objects[Id] = Object
	SimulatedObjects.Octree:CreateNode(ConvertVector((Object.InitialTransform * Object.ApexOffset).Position), Id)
end

function SimulatedObjects.AddVolume(VolumeData: Types.VolumeData)
	local Id = SimulatedObjects.GenerateId("v_")
	local Volume = Volume(VolumeData)
	Volume.Id = Id

	SimulatedObjects.Volumes[Id] = Volume
end

function SimulatedObjects.AddCollider(ColliderData: Types.ColliderData)
	local Id = SimulatedObjects.GenerateId("c_")
	local Collider = Collider.new(ColliderData)
	Collider.Id = Id

	SimulatedObjects.Colliders[Id] = Collider
end

--- Removes on the next Step cycle
function SimulatedObjects.RemoveCollider(ColliderId: Types.Id)
	if not SimulatedObjects.Colliders[ColliderId] then
		return
	end

	SimulatedObjects.RemovingColliders[ColliderId] = true
end

function SimulatedObjects.Step(Delta: number)
	shared.__FRAME_COUNT = shared.__FRAME_COUNT + 1 % MAX_FRAME_COUNT

	debug.profilebegin("SimulatedObjects::Step")

	local Camera = workspace.CurrentCamera
	local CameraCFrame = Camera.CFrame
	local CameraPosition = CameraCFrame.Position

	local Time = os.clock()

	local FreeSpringPool = SimulatedObjects.FreeSpringPool
	local HotSpringPool = SimulatedObjects.HotSpringPool
	local SimulatingObjectIds = SimulatedObjects.SimulatingObjectIds

	local ObjectOctree = SimulatedObjects.Octree
	local WorldObjects = SimulatedObjects.Objects
	local WorldColliders = SimulatedObjects.Colliders

	local BulkObjects = SimulatedObjects.BulkObjects
	local BulkCFrames = SimulatedObjects.BulkCFrames
	local BulkModels = SimulatedObjects.BulkModels
	local BulkModelCFrames = SimulatedObjects.BulkModelCFrames

	local ActiveColliderIdsLastFrame = SimulatedObjects.ActiveColliderIdsLastFrame
	local RemovingColliders = SimulatedObjects.RemovingColliders
	local ActiveColliders: { Types.Id } = {}
	local ActiveColliderHashMap: { [Types.Id]: boolean } = {}

	-- -------------------------------------------------------------------------- --
	--                                  Streaming                                 --
	-- -------------------------------------------------------------------------- --

	local ReleaseStreamJobs: Types.StreamRelationshipJobs = {}
	local AssignStreamJobs: Types.StreamRelationshipJobs = {}

	local StreamOutJobs: Types.StreamOutJobs = {}
	local StreamInJobs: Types.StreamInJobs = {}
	local StreamingJobsCount = 0

	local BulkObjectReleaseJobs: Types.BulkObjectStreamRelationshipJobs = {}
	local BulkObjectAssignJobs: Types.BulkObjectStreamRelationshipJobs = {}
	local BulkObjectJobsCount = 0

	local StreamingResetJobs: Types.StreamingResetJobs = {}

	debug.profilebegin("Streaming")

	debug.profilebegin("Gather active colliders")
	for _, Collider in SimulatedObjects.Colliders do
		debug.profilebegin(Collider.Id)
		local Center = Collider:GetCenter()

		if (CameraPosition - Center.Position).Magnitude <= CAMERA_ACTIVE_RADIUS then
			debug.profilebegin("Add active")
			table.insert(ActiveColliders, Collider.Id)
			ActiveColliderHashMap[Collider.Id] = true
			debug.profileend()
		end
		debug.profileend()
	end
	debug.profileend()

	debug.profilebegin("Get relationship streaming jobs")

	local function ReleaseCollider(ColliderId)
		debug.profilebegin("Release collider")
		local Collider = WorldColliders[ColliderId]
		-- We use release all objects because its faster than using a job if we need to get rid of every streamable
		local WasStreaming = Collider:ReleaseAllObjects()

		for _, ObjectId in WasStreaming do
			if BulkObjectReleaseJobs[ObjectId] then
				table.insert(BulkObjectReleaseJobs[ObjectId], ColliderId)
			else
				BulkObjectReleaseJobs[ObjectId] = { ColliderId }
				BulkObjectJobsCount += 1
			end
		end
		debug.profileend()
	end

	debug.profilebegin("Removing colliders")
	for _, ColliderId in RemovingColliders do
		debug.profilebegin(ColliderId)
		ReleaseCollider(ColliderId)
		WorldColliders[ColliderId] = nil
		debug.profileend()
	end
	debug.profileend()

	debug.profilebegin("In-active colliders")
	-- Find what colliders are no longer active and give them stream jobs
	for _, ColliderId in ActiveColliderIdsLastFrame do
		if ActiveColliderHashMap[ColliderId] then
			continue
		end

		debug.profilebegin(ColliderId)
		ReleaseCollider(ColliderId)
		debug.profileend()
	end
	debug.profileend()

	debug.profilebegin("Active colliders")
	-- Get streamables of active colliders
	for _, ColliderId in ActiveColliders do
		debug.profilebegin(ColliderId)
		local Collider = WorldColliders[ColliderId]

		local StreamIn, StreamOut = Collider:GetStreamables(ObjectOctree, not ActiveColliderIdsLastFrame[ColliderId])

		if #StreamIn > 0 then
			table.insert(AssignStreamJobs, { ColliderId = ColliderId, ObjectIds = StreamIn })
		end

		if #StreamOut > 0 then
			table.insert(ReleaseStreamJobs, { ColliderId = ColliderId, ObjectIds = StreamOut })
		end
		debug.profileend()
	end
	debug.profileend()

	SimulatedObjects.ActiveColliderIdsLastFrame = ActiveColliders

	debug.profileend()

	-- ------------------------ Resolve relationship jobs ----------------------- --

	if #ReleaseStreamJobs > 0 or #AssignStreamJobs > 0 or BulkObjectJobsCount > 0 then
		debug.profilebegin("Resolve relationship jobs")

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
		debug.profilebegin("Resolve streaming jobs")

		debug.profilebegin("Stream out")
		for ObjectId in StreamOutJobs do
			debug.profilebegin(ObjectId)
			local Object = WorldObjects[ObjectId]
			local SpringId, NeedsResetJob = Object:StreamOut()

			if NeedsResetJob then
				table.insert(StreamingResetJobs, { Object = Object.Object, IsModel = Object.IsModel, InitialTransform = Object.InitialTransform })
			end

			local Spring = HotSpringPool[SpringId]
			HotSpringPool[SpringId] = nil
			table.insert(FreeSpringPool, Spring)

			SimulatingObjectIds[ObjectId] = nil
			debug.profileend()
		end
		debug.profileend()

		debug.profilebegin("Stream in")
		for ObjectId in StreamInJobs do
			debug.profilebegin(ObjectId)
			local Object = WorldObjects[ObjectId]

			local Spring = table.remove(FreeSpringPool)
			local SpringId = #HotSpringPool + 1

			table.insert(HotSpringPool, Spring)

			SimulatingObjectIds[ObjectId] = ObjectId

			Object:StreamIn(Spring, SpringId)
			debug.profileend()
		end
		debug.profileend()

		debug.profileend()
	end

	if #StreamingResetJobs > 0 then
		debug.profilebegin("Streaming reset jobs")

		for _, Job in StreamingResetJobs do
			local Object = Job.Object
			local Transform = Job.InitialTransform

			if not Job.IsModel then
				table.insert(BulkObjects, Object)
				table.insert(BulkCFrames, Transform)
			else
				table.insert(BulkModels, Object)
				table.insert(BulkModelCFrames, Transform)
			end
		end

		debug.profileend()
	end

	debug.profileend()

	-- -------------------------------------------------------------------------- --
	--                               Object Updating                              --
	-- -------------------------------------------------------------------------- --

	debug.profilebegin("Object Step")

	debug.profilebegin("Wind")

	SimulatedObjects.WindSimulated = 0

	-- TODO: make work with wind volumes eventually
	local Identity = CFrame.identity
	local WorkspaceWind = workspace.GlobalWind
	local WindSpeed, WindPower = 0, 0

	local WindMagnitude = WorkspaceWind.Magnitude
	if WindMagnitude > 0 then
		WindPower = if WindMagnitude > 1 then math.log10(WindMagnitude) + 0.2 else 0.3
		WindSpeed = if WindMagnitude < 100 then (WindMagnitude * 1.2) + 5 else 125
	end

	local Amplitude = WindPower * 0.2
	local Frequency = Time * WindSpeed * 0.08
	local LowAmp = Amplitude / 3
	local WindActive = WindMagnitude > 1e-5

	local WindCache = {}

	for WindSeed = 1, WIND_SEED_WRAP do
		WindCache[WindSeed] = WindActive
				and CFrame.Angles(
					math.noise(WindSeed, 0, Frequency) * LowAmp,
					math.noise(WindSeed, Frequency, 0) * LowAmp,
					math.noise(Frequency, WindSeed, 0) * LowAmp
				)
			or Identity
	end

	if WindActive then
		debug.profilebegin("Octree Search")
		local ObjectNodesInWindRadius = ObjectOctree:SearchRadius(CameraPosition, WIND_ACTIVE_RADIUS)
		debug.profileend()

		for _, ObjectNode in ObjectNodesInWindRadius do
			local ObjectId = ObjectNode.Object

			if SimulatingObjectIds[ObjectId] or SimulatedObjects.WindSimulatedLastFrame[ObjectId] or SimulatedObjects.WindSimulated > 100 then
				continue
			end

			SimulatedObjects.WindSimulatedLastFrame[ObjectId] = true

			local Object = WorldObjects[ObjectId]
			local ObjectDelta = Time - Object.LastUpdateTime
			local Jitter = (1 / math.random(60, 120))
			local Rate

			do -- Wind update rate
				local Distance = (CameraPosition - Object.SpringTransform.Position).Magnitude

				-- if Distance > WIND_ACTIVE_RADIUS then
				-- 	continue
				-- end

				local Alpha = Distance / WIND_ACTIVE_RADIUS
				Rate = OBJECT_UPDATE_RATE + (THROTTLED_OBJECT_UPDATE_RATE - OBJECT_UPDATE_RATE) * Alpha
			end

			if ObjectDelta + Jitter < Rate then
				continue
			end

			Object.LastUpdateTime = Time
			SimulatedObjects.WindSimulated += 1

			local WindRotation = WindCache[Object.WindSeed]
			local RootOffset = Object.RootOffset
			local Transform = (Object.InitialTransform * RootOffset) * WindRotation * CFrame.new(RootOffset.Position):Inverse()

			if Object.IsModel then
				table.insert(BulkModels, Object.Object)
				table.insert(BulkModelCFrames, Transform)
			else
				table.insert(BulkObjects, Object.Object)
				table.insert(BulkCFrames, Transform)
			end
		end

		table.clear(SimulatedObjects.WindSimulatedLastFrame)
	end
	debug.profileend()

	for ObjectId, Simulating in SimulatingObjectIds do
		-- if not InViewObjects[ObjectId] then
		-- 	continue
		-- end

		debug.profilebegin(ObjectId)
		local Object = WorldObjects[ObjectId]

		local ObjectDelta = Time - Object.LastUpdateTime
		local Rate

		do -- Update rate
			local Distance = (CameraPosition - Object.SpringTransform.Position).Magnitude

			if Distance > CAMERA_ACTIVE_RADIUS then
				debug.profileend()
				continue
			elseif Distance <= THROTTLING_START_RADIUS then
				Rate = OBJECT_UPDATE_RATE
			else
				local Alpha = (Distance - THROTTLING_START_RADIUS) / (CAMERA_ACTIVE_RADIUS - THROTTLING_START_RADIUS)
				Rate = OBJECT_UPDATE_RATE + (THROTTLED_OBJECT_UPDATE_RATE - OBJECT_UPDATE_RATE) * Alpha
			end
		end

		if ObjectDelta < Rate then
			debug.profileend()
			continue
		end

		Object.LastUpdateTime = Time

		local Colliders = {}

		for _, ColliderId in Object.m_SimulatedBy do
			table.insert(Colliders, WorldColliders[ColliderId])
		end

		local Transform = Object:Step(ObjectDelta, WindCache[Object.WindSeed], Colliders)

		if Object.IsModel then
			table.insert(BulkModels, Object.Object)
			table.insert(BulkModelCFrames, Transform)
		else
			table.insert(BulkObjects, Object.Object)
			table.insert(BulkCFrames, Transform)
		end

		debug.profileend()
	end

	debug.profileend()

	-- -------------------------------------------------------------------------- --
	--                              Object Transform                              --
	-- -------------------------------------------------------------------------- --

	debug.profilebegin("Object Transform")

	workspace:BulkMoveTo(BulkObjects, BulkCFrames)

	for ModelIndex, Model in BulkModels do
		Model:PivotTo(BulkModelCFrames[ModelIndex])
	end

	table.clear(BulkObjects)
	table.clear(BulkCFrames)
	table.clear(BulkModels)
	table.clear(BulkModelCFrames)

	debug.profileend()

	debug.profileend()

	-- ---------------------------------- Debug --------------------------------- --
	if _G.DEV then
		for _, ColliderId in ActiveColliders do
			local Collider = WorldColliders[ColliderId]

			Collider:DrawDebug()
		end

		for _, ObjectId in SimulatingObjectIds do
			local Object = WorldObjects[ObjectId]

			Object:DrawDebug()
		end
	end
end

-- Populate Spring Pool
Log.debug(`Populating free spring pool with {SPRING_POOL_SIZE} springs`)
for _ = 1, SPRING_POOL_SIZE do
	table.insert(SimulatedObjects.FreeSpringPool, Spring.create())
end

return SimulatedObjects
