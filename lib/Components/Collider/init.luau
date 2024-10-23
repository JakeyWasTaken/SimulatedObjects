--[[

The Secondary Axis (Y) of the Root attachment defines the up vector of the object, It should point towards the apex. the look vector should be aligned to the front of the object.

]]

local General = require(script.Parent.Parent.Utils.General)
local Gizmo = require(script.Parent.Parent.Dependencies.Gizmo)
local Log = require(script.Parent.Parent.Utils.Log)
local Types = require(script.Parent.Parent.Types)
local _Octree = require(script.Parent.Parent.Dependencies.Octree)

local CCollider = {}
CCollider.__index = CCollider

export type CCollider = {
	Shape: Types.Shapes,
	Data: Types.ColliderData,
	Id: Types.Id,
	m_Streaming: { Types.Id },

	m_Center: CFrame,
	m_LastGetCenterCall: number,
} & typeof(CCollider)

function CCollider.new(Data: Types.ColliderData): CCollider
	assert(Data, "Expected ObjectData")

	local AssertParameter = function(Key, ValueType, Optional)
		General.AssertTableParameter(Data, "ObjectData", Key, ValueType, Optional)
	end

	AssertParameter("Shape", "string")
	AssertParameter("StreamingRadius", "number")

	if Data.Shape == "Box" then
		AssertParameter("Center", "Instance")
		AssertParameter("Size", "Vector3")
		assert(Data.Center:IsA("Attachment"), "Expected 'Center' instance of ColliderData to be an attachment")
	elseif Data.Shape == "Sphere" then
		AssertParameter("Center", "Instance")
		AssertParameter("Radius", "number")
		assert(Data.Center:IsA("Attachment"), "Expected 'Center' instance of ColliderData to be an attachment")
	elseif Data.Shape == "Capsule" then
		AssertParameter("Start", "Instance")
		AssertParameter("End", "Instance")
		AssertParameter("Radius", "number")
		assert(Data.Start:IsA("Attachment"), "Expected 'Start' instance of ColliderData to be an attachment")
		assert(Data.End:IsA("Attachment"), "Expected 'End' instance of ColliderData to be an attachment")
	elseif Data.Shape == "RoundedFrustum" then
		AssertParameter("Start", "Instance")
		AssertParameter("End", "Instance")
		AssertParameter("StartRadius", "number")
		AssertParameter("EndRadius", "number")
		assert(Data.Start:IsA("Attachment"), "Expected 'Start' instance of ColliderData to be an attachment")
		assert(Data.End:IsA("Attachment"), "Expected 'End' instance of ColliderData to be an attachment")
	end

	-- ----------------------------- Class Creation ----------------------------- --

	local self = setmetatable({}, CCollider)

	self.Shape = Data.Shape
	self.Data = Data
	self.Id = nil
	self.m_Streaming = {}

	self.m_Center = CFrame.identity
	self.m_LastGetCenterCall = -1

	return self
end

function CCollider:GetCenter(): CFrame
	if self.m_LastGetCenterCall == shared.__FRAME_COUNT then
		return self.m_Center
	end

	local Data: Types.ColliderData = self.Data
	local Center
	if Data.Shape == "Box" or Data.Shape == "Sphere" then
		Center = Data.Center.WorldCFrame
	elseif Data.Shape == "Capsule" or Data.Shape == "RoundedFrustum" then
		local p0 = Data.Start.WorldCFrame
		local p1 = Data.End.WorldCFrame
		Center = CFrame.lookAt(p0, p1, Data.Start.WorldCFrame.UpVector)
	end

	self.m_Center = Center
	return Center
end

-- Assigns objects that this collider is responsible for streaming
function CCollider:AssignObjects(ObjectIds: { Types.Id })
	General.AppendIntoTable(self.m_Streaming, ObjectIds)
end

-- FIXME: optimise a bit maybe?
function CCollider:ReleaseObjects(ObjectIds: { Types.Id })
	if #self.m_Streaming == 0 then
		return
	end

	local NewTable = {}

	for _, ObjectId in self.m_Streaming do
		if table.find(ObjectIds, ObjectId) then
			continue
		end

		table.insert(NewTable, ObjectId)
	end

	self.m_Streaming = NewTable
end

-- Returns all the objects the collider was streaming
function CCollider:ReleaseAllObjects(): { Types.Id }
	local Clone = table.clone(self.m_Streaming)
	table.clear(self.m_Streaming)

	return Clone
end

--- @return { Id }, { Id } -- StreamIn, StreamOut
function CCollider:GetStreamables(ObjectOctree: typeof(_Octree.new())): ({ Types.Id }, { Types.Id })
	local StreamingObjects = self.m_Streaming
	local StreamingRadius = self.Data.StreamingRadius
	local Center = self:GetCenter().Position

	local StreamOut = {}
	local StreamIn = {}

	-- Gizmo.SetStyle(Color3.new(1))
	-- Gizmo.Sphere:Draw(CFrame.new(Center), StreamingRadius, 20, 360)

	local ObjectIds: { Types.Id } = ObjectOctree:RadiusSearch(Center, StreamingRadius)

	-- -------------------------------- Stream In ------------------------------- --

	for _, ObjectId in ObjectIds do
		if table.find(StreamingObjects, ObjectId) then
			continue
		end

		table.insert(StreamIn, ObjectId)
	end

	-- ------------------------------- Stream Out ------------------------------- --

	for _, ObjectId in StreamingObjects do
		if table.find(ObjectIds, ObjectId) then
			continue
		end

		table.insert(StreamOut, ObjectId)
	end

	return StreamIn, StreamOut
end

return CCollider
