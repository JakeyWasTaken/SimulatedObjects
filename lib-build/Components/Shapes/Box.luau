--!native
local vec3 = vector.create
local mag = vector.magnitude
local norm = vector.normalize

local function SafeUnit(v3)
	if mag(v3) > 0 then
		return norm(v3)
	end

	return vector.zero
end

-- TODO: add alpha here
local function ClosestPointFunc(cframe: CFrame, size: vector, point: vector): (boolean, Vector3, Vector3)
do end	
local rel = cframe:PointToObjectSpace(point)
	local sx, sy, sz = size.X, size.Y, size.Z
	local rx, ry, rz = rel.X, rel.Y, rel.Z

	-- constrain to within the box
	local cx = math.clamp(rx, -sx * 0.5, sx * 0.5)
	local cy = math.clamp(ry, -sy * 0.5, sy * 0.5)
	local cz = math.clamp(rz, -sz * 0.5, sz * 0.5)

	if not (cx == rx and cy == ry and cz == rz) then
do end		
local closestPoint = cframe * vector.create(cx, cy, cz)
		local normal = SafeUnit(point - closestPoint)
do end do end		

return false, closestPoint, normal
	end

	-- else, they are intersecting, find the surface the point is closest to

	local posX = rx - sx * 0.5
	local posY = ry - sy * 0.5
	local posZ = rz - sz * 0.5
	local negX = -rx - sx * 0.5
	local negY = -ry - sy * 0.5
	local negZ = -rz - sz * 0.5

	--local old_max = math.max(posX, posY, posZ, negX, negY, negZ)
	local max = (posX > posY and posX > posZ and posX > negX and posX > negY and posX > negZ) and posX
		or (
			(posY > posX and posY > posZ and posY > negX and posY > negY and posY > negZ) and posY
			or (
				(posZ > posX and posZ > posY and posZ > negX and posZ > negY and posZ > negZ) and posZ
				or (negX > negY and negX > negZ and negX > posX and negX > posY and negX > posZ) and negX
				or ((negY > negX and negY > negZ and negY > posX and negY > posY and negY > posZ) and negY or negZ)
			)
		)
	if max == posX then
		local closestPoint = cframe * vec3(sx * 0.5, ry, rz)
do end		
return true, closestPoint, cframe.XVector
	elseif max == posY then
		local closestPoint = cframe * vec3(rx, sy * 0.5, rz)
do end		
return true, closestPoint, cframe.YVector
	elseif max == posZ then
		local closestPoint = cframe * vec3(rx, ry, sz * 0.5)
do end		
return true, closestPoint, cframe.ZVector
	elseif max == negX then
		local closestPoint = cframe * vec3(-sx * 0.5, ry, rz)
do end		
return true, closestPoint, -cframe.XVector
	elseif max == negY then
		local closestPoint = cframe * vec3(rx, -sy * 0.5, rz)
do end		
return true, closestPoint, -cframe.YVector
	elseif max == negZ then
		local closestPoint = cframe * vec3(rx, ry, -sz * 0.5)
do end		
return true, closestPoint, -cframe.ZVector
	end

	-- Shouldn't reach
	warn("CLOSEST POINT ON BOX FAIL")
do end	
return false, cframe.Position, vec3(0, 0, 0)
end

--- Alpha is a value between 0 - 1; 0 being the point is in the middle of the shape and 1 being it on the surface.
--- Returns IsInside, Position, Normal, Alpha
return function(CFrame: CFrame, Size: vector, Point: vector, PointRadius: number): (boolean, vector, vector, number)
	local Inside, ClosestPoint, Normal = ClosestPointFunc(CFrame, Size, Point)
	local Alpha

	ClosestPoint = vec3(ClosestPoint.X, ClosestPoint.Y, ClosestPoint.Z)
	Normal = vec3(Normal.X, Normal.Y, Normal.Z)

	-- This may kill perf
	local WorldSize = CFrame * Size
	local AxisSize = mag(WorldSize * Normal) * 0.5
	local UnboundAlpha = 1 - mag(ClosestPoint - Point) / AxisSize
	Alpha = UnboundAlpha < 1 and UnboundAlpha or 1

	if not Inside then
		Inside = mag(ClosestPoint - Point) < PointRadius
	end

	return Inside, ClosestPoint, Normal, Alpha
end
