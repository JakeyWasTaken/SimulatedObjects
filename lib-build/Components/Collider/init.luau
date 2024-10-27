--!native
--[[

The Secondary Axis (Y) of the Root attachment defines the up vector of the object, It should point towards the apex. the look vector should be aligned to the front of the object.

]]

local General = require(script.Parent.Parent.Utils.General)
local Gizmo = require(script.Parent.Parent.Dependencies.Gizmo)
local Log = require(script.Parent.Parent.Utils.Log)
local Types = require(script.Parent.Parent.Types)
local _Octree = require(script.Parent.Parent.Dependencies.Octree)

local ShapeBox = require(script.Parent.Shapes.Box)
local ShapeCapsule = require(script.Parent.Shapes.Capsule)
local ShapeRoundedFrustum = require(script.Parent.Shapes.RoundedFrustum)
local ShapeSphere = require(script.Parent.Shapes.Sphere)

local CCollider = {}
CCollider.__index = CCollider

export type CCollider = {
	Shape: Types.Shapes,
	Data: Types.ColliderData,
	Id: Types.Id,
	m_Streaming: { Types.Id },
	m_StreamingHashMap: { [Types.Id]: boolean },

	m_Center: CFrame,
	m_CenterLastFrame: CFrame,
	m_LastGetCenterCall: number
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
	self.m_StreamingHashMap = {}

	self.m_Center = CFrame.identity
	self.m_CenterLastFrame = CFrame.identity
	self.m_LastGetCenterCall = -1
	
return self
end

-- Returns center, SameCFrameAsLastFrame
function CCollider:GetCenter(): (CFrame, boolean)
	if self.m_LastGetCenterCall == shared.__FRAME_COUNT then
		return self.m_Center, self.m_Center == self.m_CenterLastFrame
	end

	local Data: Types.ColliderData = self.Data
	local Center
	if Data.Shape == "Box" or Data.Shape == "Sphere" then
		Center = Data.Center.WorldCFrame
	elseif Data.Shape == "Capsule" or Data.Shape == "RoundedFrustum" then
		local p0 = Data.Start.WorldPosition
		local p1 = Data.End.WorldPosition
		Center = CFrame.lookAt(p0, p1, Data.Start.WorldCFrame.UpVector)
	end

	self.m_CenterLastFrame = self.m_Center
	self.m_Center = Center
	self.m_LastGetCenterCall = shared.__FRAME_COUNT
	return Center, Center == self.m_CenterLastFrame
end

-- Assigns objects that this collider is responsible for streaming
function CCollider:AssignObjects(ObjectIds: { Types.Id })
	General.AppendIntoTable(self.m_Streaming, ObjectIds)
end

-- When this function is called you want to pass in as many collider id's as possible
function CCollider:ReleaseObjects(ObjectIds: { Types.Id })
	if #self.m_Streaming == 0 then
		return
	end

	local NewTable = {}

	for _, ObjectId in self.m_Streaming do
		if table.find(ObjectIds, ObjectId) then
			self.m_StreamingHashMap[ObjectId] = nil
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
	table.clear(self.m_StreamingHashMap)

	return Clone
end

--- @return { Id }, { Id } -- StreamIn, StreamOut
function CCollider:GetStreamables(ObjectOctree: typeof(_Octree.new()), JustActive: boolean): ({ Types.Id }, { Types.Id })
	local StreamingObjects = self.m_Streaming
	local StreamingObjectsHashMap = self.m_StreamingHashMap
	local StreamingRadius = self.Data.StreamingRadius
	local Center, SameAsLastFrame = self:GetCenter()

	if SameAsLastFrame and not JustActive then
		return {}, {}
	end

	Center = Center.Position

	local StreamOut = {}
	local StreamIn = {}

	-- Gizmo.SetStyle(Color3.new(1))
	-- Gizmo.Sphere:Draw(CFrame.new(Center), StreamingRadius, 20, 360)

	local ObjectIds: { Types.Id } = ObjectOctree:RadiusSearch(Center, StreamingRadius)
	local ObjectIdsHashmap: { [Types.Id]: boolean } = {}

	-- -------------------------------- Stream In ------------------------------- --

	for _, ObjectId in ObjectIds do
		ObjectIdsHashmap[ObjectId] = true

		if StreamingObjectsHashMap[ObjectId] then
			continue
		end

		StreamingObjectsHashMap[ObjectId] = true
		table.insert(StreamIn, ObjectId)
	end

	-- ------------------------------- Stream Out ------------------------------- --

	for _, ObjectId in StreamingObjects do
		if ObjectIdsHashmap[ObjectId] then
			continue
		end

		StreamingObjectsHashMap[ObjectId] = false
		table.insert(StreamOut, ObjectId)
	end

	return StreamIn, StreamOut
end

--- Alpha is a value between 0 - 1; 0 being the point is in the middle of the shape and 1 being it on the surface.
--- Returns IsInside, Position, Normal, Alpha
function CCollider:GetClosestPoint(Point: Vector3, PointRadius: number): (boolean, Vector3, Vector3, number)
do end	
local Center = self.m_Center -- we do this here because we just assume its been cached at this point
	local Data = self.Data

	if self.Shape == "Sphere" then
		local IsInside, Position, Normal, Alpha = ShapeSphere(Center.Position, Data.Radius, Point, PointRadius)
do end		
return IsInside, Position, Normal, Alpha
	elseif self.Shape == "Box" then
		local IsInside, Position, Normal, Alpha = ShapeBox(Center, Data.Size, Point, PointRadius)
do end		
return IsInside, Position, Normal, Alpha
	elseif self.Shape == "Capsule" then
		local p0 = Data.Start.WorldPosition
		local p1 = Data.End.WorldPosition
		local IsInside, Position, Normal, Alpha = ShapeCapsule(p0, p1, Data.Radius, Point, PointRadius)
do end		
return IsInside, Position, Normal, Alpha
	elseif self.Shape == "RoundedFrustum" then
		local p0 = Data.Start.WorldPosition
		local p1 = Data.End.WorldPosition
		local r0 = Data.StartRadius
		local r1 = Data.EndRadius
		local IsInside, Position, Normal, Alpha = ShapeRoundedFrustum(p0, p1, r0, r1, Point, PointRadius)
do end		
return IsInside, Position, Normal, Alpha
	end

	warn(`Invalid shape for collider "{self.Shape}"`)
do end	
return false, Point, Vector3.yAxis, 0
end

function CCollider:DrawDebug()
do		
return
end






















end

return CCollider
