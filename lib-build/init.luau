--!native

local SPRING_POOL_SIZE = 4096
local MAX_FRAME_COUNT = 131072

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

function SimulatedObjects.RemoveCollider(ColliderId: Types.Id)
	if not SimulatedObjects.Colliders[ColliderId] then
		return
	end

	SimulatedObjects.RemovingColliders[ColliderId] = true
end

function SimulatedObjects.Step(Delta: number)
	shared.__FRAME_COUNT = shared.__FRAME_COUNT + 1 % MAX_FRAME_COUNT
do end
	

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
do end do end	



for _, Collider in SimulatedObjects.Colliders do
local _=Collider.Id		
local Center = Collider:GetCenter()

		if (CameraPosition - Center.Position).Magnitude <= CAMERA_ACTIVE_RADIUS then
do end			
table.insert(ActiveColliders, Collider.Id)
			ActiveColliderHashMap[Collider.Id] = true
do end		
end
do end	
end
do end do end
	


local function ReleaseCollider(ColliderId)
do end		
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
do end	
end
do end	

for _, ColliderId in RemovingColliders do
do end		
ReleaseCollider(ColliderId)
		WorldColliders[ColliderId] = nil
do end	
end
do end do end	-- Find what colliders are no longer active and give them stream jobs
	


for _, ColliderId in ActiveColliderIdsLastFrame do
		if ActiveColliderHashMap[ColliderId] then
			continue
		end
do end		

ReleaseCollider(ColliderId)
do end	
end
do end do end	-- Get streamables of active colliders
	


for _, ColliderId in ActiveColliders do
do end		
local Collider = WorldColliders[ColliderId]

		local StreamIn, StreamOut = Collider:GetStreamables(ObjectOctree, not ActiveColliderIdsLastFrame[ColliderId])

		if #StreamIn > 0 then
			table.insert(AssignStreamJobs, { ColliderId = ColliderId, ObjectIds = StreamIn })
		end

		if #StreamOut > 0 then
			table.insert(ReleaseStreamJobs, { ColliderId = ColliderId, ObjectIds = StreamOut })
		end
do end	
end
do end
	
SimulatedObjects.ActiveColliderIdsLastFrame = ActiveColliders
do end
	-- ------------------------ Resolve relationship jobs ----------------------- --

	

if #ReleaseStreamJobs > 0 or #AssignStreamJobs > 0 or BulkObjectJobsCount > 0 then
do end do end		


for _, Job in ReleaseStreamJobs do
			local ColliderId = Job.ColliderId
			local ObjectIds = Job.ObjectIds
do end			

local Collider = WorldColliders[ColliderId]
			Collider:ReleaseObjects(ObjectIds)

			for _, ObjectId in ObjectIds do
				if BulkObjectReleaseJobs[ObjectId] then
					table.insert(BulkObjectReleaseJobs[ObjectId], ColliderId)
				else
					BulkObjectReleaseJobs[ObjectId] = { ColliderId }
				end
			end
do end		
end
do end do end		


for _, Job in AssignStreamJobs do
			local ColliderId = Job.ColliderId
			local ObjectIds = Job.ObjectIds
do end			

local Collider = WorldColliders[ColliderId]
			Collider:AssignObjects(ObjectIds)

			for _, ObjectId in ObjectIds do
				if BulkObjectAssignJobs[ObjectId] then
					table.insert(BulkObjectAssignJobs[ObjectId], ColliderId)
				else
					BulkObjectAssignJobs[ObjectId] = { ColliderId }
				end
			end
do end		
end
do end do end do end		






for ObjectId, ColliderIds in BulkObjectReleaseJobs do
do end			
local Object = WorldObjects[ObjectId]
			Object:ReleaseSimulatingColliders(ColliderIds)

			if Object:CanStreamOut() then
				StreamOutJobs[ObjectId] = true
				StreamingJobsCount += 1
			end
do end		
end
do end do end		


for ObjectId, ColliderIds in BulkObjectAssignJobs do
do end			
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
do end		
end
do end do end do end	



end

	-- ------------------------- Resolve streaming jobs ------------------------- --

	if StreamingJobsCount > 0 then
do end do end		


for ObjectId in StreamOutJobs do
do end			
local Object = WorldObjects[ObjectId]
			local SpringId, NeedsResetJob = Object:StreamOut()

			if NeedsResetJob then
				table.insert(StreamingResetJobs, { Object = Object.Object, IsModel = Object.IsModel, InitialTransform = Object.InitialTransform })
			end

			local Spring = HotSpringPool[SpringId]
			HotSpringPool[SpringId] = nil
			table.insert(FreeSpringPool, Spring)

			SimulatingObjectIds[ObjectId] = nil
do end		
end
do end do end		


for ObjectId in StreamInJobs do
do end			
local Object = WorldObjects[ObjectId]

			local Spring = table.remove(FreeSpringPool)
			local SpringId = #HotSpringPool + 1

			table.insert(HotSpringPool, Spring)

			SimulatingObjectIds[ObjectId] = ObjectId

			Object:StreamIn(Spring, SpringId)
do end		
end
do end do end	


end

	if #StreamingResetJobs > 0 then
do end
		
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
do end	

end
do end do end do end
	









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
do end		
local ObjectNodesInWindRadius = ObjectOctree:SearchRadius(CameraPosition, WIND_ACTIVE_RADIUS)
do end
		
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
do end
	
for ObjectId, Simulating in SimulatingObjectIds do
do end		




local Object = WorldObjects[ObjectId]

		local ObjectDelta = Time - Object.LastUpdateTime
		local Rate

		do -- Update rate
			local Distance = (CameraPosition - Object.SpringTransform.Position).Magnitude

			if Distance > CAMERA_ACTIVE_RADIUS then
do end				
continue
			elseif Distance <= THROTTLING_START_RADIUS then
				Rate = OBJECT_UPDATE_RATE
			else
				local Alpha = (Distance - THROTTLING_START_RADIUS) / (CAMERA_ACTIVE_RADIUS - THROTTLING_START_RADIUS)
				Rate = OBJECT_UPDATE_RATE + (THROTTLED_OBJECT_UPDATE_RATE - OBJECT_UPDATE_RATE) * Alpha
			end
		end

		if ObjectDelta < Rate then
do end			
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
do end	

end
do end do end
	







workspace:BulkMoveTo(BulkObjects, BulkCFrames)

	for ModelIndex, Model in BulkModels do
		Model:PivotTo(BulkModelCFrames[ModelIndex])
	end

	table.clear(BulkObjects)
	table.clear(BulkCFrames)
	table.clear(BulkModels)
	table.clear(BulkModelCFrames)
do end do end


















end

-- Populate Spring Pool
Log.debug(`Populating free spring pool with {SPRING_POOL_SIZE} springs`)
for _ = 1, SPRING_POOL_SIZE do
	table.insert(SimulatedObjects.FreeSpringPool, Spring.create())
end

return SimulatedObjects
