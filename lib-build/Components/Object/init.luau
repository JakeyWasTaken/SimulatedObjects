--!native
--[[

The Look Vector (-Z) of the root attachment defines the up vector of the object,
it should point towards the apex. The Secondary Axis (Y) should point towards the front of the object

]]

local Config = require(script.Parent.Parent.Config)
local General = require(script.Parent.Parent.Utils.General)
local Gizmo = require(script.Parent.Parent.Dependencies.Gizmo)
local Log = require(script.Parent.Parent.Utils.Log)
local Types = require(script.Parent.Parent.Types)
local _Collider = require(script.Parent.Collider)
local _Defaults = require(script.Parent.Parent.Defaults)

local _Spring = require(script.Parent.Parent.Dependencies.Spring)

local Defaults = _Defaults.Object
local WIND_SEED_WRAP = Config.WIND_SEED_WRAP

local Vec3 = vector.create
local Mag = vector.magnitude
local Norm = vector.normalize
local Dot = vector.dot

local function ConvertVector(Vector: Vector3 | vector): vector
	return vector.create(Vector.X, Vector.Y, Vector.Z)
end

local function SafeUnit(v3)
	if Mag(v3) > 0 then
		return Norm(v3)
	end

	return vector.zero
end

local function Slerp(q0, q1, t)
	q0 = q0.unit
	q1 = q1.unit --only unit quaternions are valid Rotations; normalize to avoid undefined behavior
	local xx = q0.x
	local xy = q0.y
	local xz = q0.z
	local px = q1.x
	local py = q1.y
	local pz = q1.z
	local dot = xx * px + xy * py + xz * pz
	if dot > 0.9999 then
		local t0 = 1 - t
		return Vec3(xx * t0 + px * t, xy * t0 + py * t, xz * t0 + pz * t)
	end

	local yx = px - dot * xx
	local yy = py - dot * xy
	local yz = pz - dot * xz
	local a = math.acos(dot) * t
	local c = math.cos(a)
	local s = math.sin(a) / (yx * yx + yy * yy + yz * yz) ^ 0.5
	return Vec3(xx * c + yx * s, xy * c + yy * s, xz * c + yz * s)
end

local CObject = {
	-- WindCache = {},
	-- WindCacheFrame = -1,
}
CObject.__index = CObject

type Spring = typeof(_Spring.create())

export type CObject = {
	Object: BasePart | Model,
	IsModel: boolean,
	PrimaryPart: BasePart,

	RootOffset: CFrame,
	ApexOffset: CFrame,
	InitialTransform: CFrame,
	SpringTransform: CFrame, -- Our springs transform, this carries over from frame to frame

	InitialUp: vector,

	Id: Types.Id,
	WindSeed: number,
	LastUpdateTime: number, -- os.clock() time of when this object was last updated
	LastContactState: boolean, -- boolean of if we were contacting anything last frame
	OrientSign: number, -- Sign of our orient (-1, 0, 1); Set on initial contact

	m_SimulatedBy: { Types.Id }, -- Id's of colliders which streamed this object in
	Simulating: boolean,
	m_Spring: Spring?,
	m_SpringId: number,

	m_LastSurfaceNormal: vector?,

	-- Property's from ObjectData
	ApexRadius: number,
	MaxAngle: number,

	WindInfluence: number,

	-- Flags
	Orients: boolean,

	-- Spring property's
	Mass: number,
	Speed: number,
	Force: number,
	Damping: number
} & typeof(CObject)

function CObject.new(Data: Types.ObjectData): CObject
	assert(Data, "Expected ObjectData")

	local AssertParameter = function(Key, ValueType, Optional)
		General.AssertTableParameter(Data, "ObjectData", Key, ValueType, Optional)
	end

	AssertParameter("MaxAngle", "number")
	AssertParameter("ApexRadius", "number")

	AssertParameter("WindInfluence", "number", true)

	AssertParameter("Mass", "number", true)
	AssertParameter("Damping", "number", true)
	AssertParameter("Speed", "number", true)
	AssertParameter("Force", "number", true)

	AssertParameter("Orients", "boolean")

	local IsModel = Data.Object:IsA("Model")
	local PrimaryPart

	if IsModel then
		assert((Data.Object :: Model).PrimaryPart, `Object of type model must have a primary part assigned; '{Data.Object:GetFullName()}'`)
		PrimaryPart = (Data.Object :: Model).PrimaryPart
	else
		PrimaryPart = Data.Object
	end

	-- ----------------------------- Class Creation ----------------------------- --

	local self = setmetatable({}, CObject)

	self.Object = Data.Object
	self.IsModel = IsModel
	self.PrimaryPart = PrimaryPart

	local RootAttachment = PrimaryPart:FindFirstChild("Root")
	local ApexAttachment = PrimaryPart:FindFirstChild("Apex")

	assert(RootAttachment, `Object is missing the root attachment; '{Data.Object:GetFullName()}'`)
	assert(ApexAttachment, `Object is missing the apex attachment; '{Data.Object:GetFullName()}'`)

	assert(RootAttachment, `Object has a child called 'Root' but it is not an attachment; '{Data.Object:GetFullName()}'`)
	assert(ApexAttachment, `Object has a child called 'Apex' but it is not an attachment; '{Data.Object:GetFullName()}'`)

	self.RootOffset = RootAttachment.CFrame
	self.ApexOffset = ApexAttachment.CFrame
	self.InitialTransform = PrimaryPart.CFrame
	self.SpringTransform = PrimaryPart.CFrame

	self.InitialUp = Norm(ApexAttachment.WorldPosition - RootAttachment.WorldPosition)

	self.Id = nil
	self.WindSeed = math.random(1, WIND_SEED_WRAP)
	self.LastUpdateTime = os.clock() + (math.random() - 0.5) * 0.1 -- Add some offset to avoid a large amount of objects pooling up on one frame
	self.LastContactState = false
	self.OrientSign = 1

	self.Simulating = false
	self.m_SimulatedBy = {}
	self.m_Spring = nil
	self.m_SpringId = -1
	-- Property's from ObjectData
	
self.ApexRadius = Data.ApexRadius
	self.MaxAngle = math.rad(Data.MaxAngle)

	self.WindInfluence = Data.WindInfluence or Defaults.WindInfluence

	-- Flags
	self.Orients = Data.Orients

	-- Spring property's
	self.Mass = Data.Mass or Defaults.Mass
	self.Speed = Data.Speed or Defaults.Speed
	self.Force = Data.Force or Defaults.Force
	self.Damping = Data.Damping or Defaults.Damping

	return self
end

-- Spring is passed in along with its reference id for the hot spring pool
function CObject:StreamIn(Spring: Spring, SpringId: number)
	if self.Simulating then
		Log.warn(`A spring has been assigned to an object that is already simulating; spring id {SpringId}`)
		return
	end

	self.Simulating = true
	self.m_Spring = Spring
	self.m_SpringId = SpringId

	Spring.Mass = self.Mass
	Spring.Speed = self.Speed
	Spring.Force = self.Force
	Spring.Damping = self.Damping

	Spring:reset(self.InitialUp, self.InitialUp) -- Resets the spring to have no velocity and acceleration, also sets the current position and target
end

-- We need to return out the spring id here so it can be released from the hot spring pool
-- We also need to return out if we need a reset job
function CObject:StreamOut(): (number, boolean)
	local NeedsResetJob = not self.m_Spring.Position:FuzzyEq(self.m_Spring.Target)

	self.Simulating = false
	self.m_Spring = nil

	self.SpringTransform = self.InitialTransform

	return self.m_SpringId, NeedsResetJob
end

function CObject:CanStreamOut(): boolean
	return #self.m_SimulatedBy == 0
end

-- Assign colliders which simulate this object
function CObject:AssignSimulatingColliders(ColliderIds: { Types.Id })
	General.AppendIntoTable(self.m_SimulatedBy, ColliderIds)
end

-- When this function is called you want to pass in as many collider id's as possible
function CObject:ReleaseSimulatingColliders(ColliderIds: { Types.Id })
	local NewTable = {}

	for _, ColliderId in self.m_SimulatedBy do
		if table.find(ColliderIds, ColliderId) then
			continue
		end

		table.insert(NewTable, ColliderId)
	end

	self.m_SimulatedBy = NewTable
end

-- Returns rotation cframe, UNUSED
-- function CObject:SolveWind(Amplitude, Frequency, LowAmp): CFrame
-- 	debug.profilebegin("CObject::SolveWind")
-- 	local Seed = self.WindSeed
-- 	local CachedWind = CObject.WindCache[Seed]
-- 	local FrameCount = shared.__FRAME_COUNT
-- 	if CObject.WindCacheFrame == FrameCount and CachedWind then
-- 		debug.profileend()
-- 		return CachedWind
-- 	elseif CObject.WindCacheFrame ~= FrameCount then
-- 		table.clear(CObject.WindCache)
-- 		CObject.WindCacheFrame = FrameCount
-- 	end

-- 	local Rotation
-- 	if Amplitude < 1e-5 or Frequency < 1e-5 then
-- 		Rotation = CFrame.identity
-- 	else
-- 		Rotation =
-- 			CFrame.Angles(math.noise(Seed, 0, Frequency) * LowAmp, math.noise(Seed, Frequency, 0) * LowAmp, math.noise(Frequency, Seed, 0) * LowAmp)
-- 	end

-- 	CObject.WindCache[Seed] = Rotation
-- 	debug.profileend()
-- 	return Rotation
-- end

-- Returns cframe which should be applied
function CObject:Step(Delta: number, WindCFrame: CFrame, Colliders: { typeof(_Collider.new({} :: any)) }): CFrame
	if not self.Simulating then
		return self.InitialTransform
	end

	self = self :: CObject -- Types
	debug.profilebegin("CObject::Step")

	local InitialUp = self.InitialUp
	local RootCFrame = self.InitialTransform * self.RootOffset
	local ApexCFrameNow = self.SpringTransform * self.ApexOffset
	local Spring = self.m_Spring

	local ApexFramePosition = ConvertVector(ApexCFrameNow.Position)
	local ApexFrameNormal
	local IsColliding = false

	debug.profilebegin("Iterate Colliders")
	for _, Collider in Colliders do
		debug.profilebegin(Collider.Id)
		-- We add 0.01 to radius to prevent a small bouncing as the apex is pushed to the surface of the object
		local IsInside, Position, Normal = Collider:GetClosestPoint(ApexFramePosition, self.ApexRadius + 0.01)

		if IsInside then
			IsColliding = true
			ApexFramePosition = Position + Normal * self.ApexRadius

			if ApexFrameNormal then
				ApexFrameNormal = ApexFrameNormal:Lerp(Normal, 0.5)
			else
				ApexFrameNormal = Normal
			end
		end
		debug.profileend()
	







end
	debug.profileend()

	if self.LastContactState ~= IsColliding then
		self.LastContactState = IsColliding

		self.OrientSign = IsColliding and math.sign(Dot(ApexFrameNormal, self.SpringTransform.UpVector)) or self.OrientSign
	end

	local RawTargetVector = IsColliding and Norm(ApexFramePosition - RootCFrame.Position) or InitialUp
	local UpVector = self.Orients and self.SpringTransform.UpVector or self.InitialTransform.UpVector

	if self.Orients then
		-- An issue occurs here where as a collider "backs" off (in the case where it stops colliding with the apex) the object will
		-- start to spin back around towards its initial orientation; I don't think its a big deal
		local TargetVector
		if ApexFrameNormal then
			TargetVector = ApexFrameNormal * self.OrientSign
		else
			TargetVector = self.InitialTransform.UpVector
		end
		UpVector = Slerp(UpVector, TargetVector, math.min(Delta * (IsColliding and 10 or 7.5), 1))
	end

	-- -------------------- Limit angle of the target vector -------------------- --
	





debug.profilebegin("Limit Vector")
	local VectorAngle = math.acos(Dot(InitialUp, RawTargetVector))
	local MaxAngle = self.MaxAngle
	local TargetVector
	if VectorAngle >= MaxAngle then
		TargetVector = InitialUp
			+ math.tan(MaxAngle)
				* (RawTargetVector - Dot(RawTargetVector, InitialUp) * InitialUp)
				/ Mag(RawTargetVector - Dot(RawTargetVector, InitialUp) * InitialUp)
	else
		TargetVector = RawTargetVector
	end
	debug.profileend()

	Spring.Target = TargetVector
	debug.profilebegin("Spring Update")
	local SpringPosition = Spring:update(Delta)
	debug.profileend()

	-- ------------------------------ Apply spring ------------------------------ --
	local SpringVector = SafeUnit(SpringPosition)
	local Transform = CFrame.lookAlong(vector.zero, SpringVector, UpVector) * WindCFrame
	self.SpringTransform = CFrame.new(RootCFrame.Position) * Transform * CFrame.new(self.RootOffset.Position):Inverse()

	debug.profileend()

	return self.SpringTransform
end

function CObject:DrawDebug()
do		
return
end













































end

return CObject
