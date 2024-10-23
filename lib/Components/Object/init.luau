--[[

The Secondary Axis (Y) of the Root attachment defines the up vector of the object, It should point towards the apex. the look vector should be aligned to the front of the object.

]]

local General = require(script.Parent.Parent.Utils.General)
local Gizmo = require(script.Parent.Parent.Dependencies.Gizmo)
local Log = require(script.Parent.Parent.Utils.Log)
local Types = require(script.Parent.Parent.Types)
local _Defaults = require(script.Parent.Parent.Defaults)

local _Spring = require(script.Parent.Parent.Dependencies.Spring)

local Defaults = _Defaults.Object

local CObject = {}
CObject.__index = CObject

type Spring = typeof(_Spring.create())

export type CObject = {
	Object: BasePart | Model,
	IsModel: boolean,
	PrimaryPart: BasePart,

	RootOffset: CFrame,
	ApexOffset: CFrame,
	InitialTransform: CFrame,

	Id: Types.Id,

	SimulatedBy: { Types.Id }, -- Id's of colliders which streamed this object in
	Simulating: boolean,
	m_Spring: Spring?,
	m_SpringId: number,

	-- Propertys from ObjectData
	ApexRadius: number,
	MaxAngle: number,

	-- Flags
	Orients: boolean,

	-- Spring propertys
	Mass: number,
	Speed: number,
	Force: number,
	Damping: number,
} & typeof(CObject)

function CObject.new(Data: Types.ObjectData): CObject
	assert(Data, "Expected ObjectData")

	local AssertParameter = function(Key, ValueType, Optional)
		General.AssertTableParameter(Data, "ObjectData", Key, ValueType, Optional)
	end

	AssertParameter("MaxAngle", "number")
	AssertParameter("ApexRadius", "number")

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

	self.Id = nil

	self.Simulating = false
	self.m_SimulatedBy = {}
	self.m_Spring = nil
	self.m_SpringId = -1

	-- Propertys from ObjectData
	self.ApexRadius = Data.ApexRadius
	self.MaxAngle = Data.MaxAngle

	-- Flags
	self.Orients = Data.Orients

	-- Spring propertys
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

	print(`Stream in, spring id: {SpringId}`)

	self.Simulating = true
	self.m_Spring = Spring
	self.m_SpringId = SpringId

	local InitialWorldUp = (self.InitialTransform * self.RootOffset).YVector

	Spring.Mass = self.Mass
	Spring.Speed = self.Speed
	Spring.Force = self.Force
	Spring.Damping = self.Damping

	Spring:reset(InitialWorldUp, InitialWorldUp) -- Resets the spring to have no velocity and acceleration, also sets the current position and target
end

-- We need to return out the spring id here so it can be released from the hot spring pool
-- We also need to return out if we need a stream out job
function CObject:StreamOut(): (number, boolean)
	local NeedsStreamOutJob = not self.m_Spring.Position:FuzzyEq(self.m_Spring.Target)

	self.Simulating = false
	self.m_Spring = nil

	print(`Stream out, spring id: {self.m_SpringId}, needs job: {NeedsStreamOutJob}`)

	return self.m_SpringId, NeedsStreamOutJob
end

function CObject:CanStreamOut(): boolean
	return #self.m_SimulatedBy == 0
end

function CObject:AssignSimulatingColliders(ColliderIds: { Types.Id })
	General.AppendIntoTable(self.m_SimulatedBy, ColliderIds)
end

-- FIXME: optimise a bit maybe?
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

function CObject:Step(Delta: number, Colliders)
	if not self.Simulating then
		return
	end

	self = self :: CObject -- Types

	self.m_Spring:update(Delta)
end

return CObject
