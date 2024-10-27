--!native
local function SafeUnit(v)
	if v.Magnitude > 0 then
		return v.Unit
	end

	return Vector3.zero
end

local function ClosestPointFunc(cframe, size, point)
	debug.profilebegin("box")
	local rel = cframe:pointToObjectSpace(point)
	local sx, sy, sz = size.x, size.y, size.z
	local rx, ry, rz = rel.x, rel.y, rel.z

	-- constrain to within the box
	local cx = math.clamp(rx, -sx * 0.5, sx * 0.5)
	local cy = math.clamp(ry, -sy * 0.5, sy * 0.5)
	local cz = math.clamp(rz, -sz * 0.5, sz * 0.5)

	if not (cx == rx and cy == ry and cz == rz) then
		debug.profilebegin("early return")
		local closestPoint = cframe * Vector3.new(cx, cy, cz)
		local normal = SafeUnit(point - closestPoint)
		debug.profileend()
		debug.profileend()
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
		local closestPoint = cframe * Vector3.new(sx * 0.5, ry, rz)
		debug.profileend()
		return true, closestPoint, cframe.XVector
	elseif max == posY then
		local closestPoint = cframe * Vector3.new(rx, sy * 0.5, rz)
		debug.profileend()
		return true, closestPoint, cframe.YVector
	elseif max == posZ then
		local closestPoint = cframe * Vector3.new(rx, ry, sz * 0.5)
		debug.profileend()
		return true, closestPoint, cframe.ZVector
	elseif max == negX then
		local closestPoint = cframe * Vector3.new(-sx * 0.5, ry, rz)
		debug.profileend()
		return true, closestPoint, -cframe.XVector
	elseif max == negY then
		local closestPoint = cframe * Vector3.new(rx, -sy * 0.5, rz)
		debug.profileend()
		return true, closestPoint, -cframe.YVector
	elseif max == negZ then
		local closestPoint = cframe * Vector3.new(rx, ry, -sz * 0.5)
		debug.profileend()
		return true, closestPoint, -cframe.ZVector
	end

	-- Shouldnt reach
	warn("CLOSEST POINT ON BOX FAIL")
	debug.profileend()
	return false, cframe.Position, Vector3.zero
end

--- Alpha is a value between 0 - 1; 0 being the point is in the middle of the shape and 1 being it on the surface.
--- Returns IsInside, Position, Normal, Alpha
return function(CFrame: CFrame, Size: Vector3, Point: Vector3, PointRadius: number)
	local Inside, ClosestPoint, Normal = ClosestPointFunc(CFrame, Size, Point)
	local Alpha

	-- This may kill perf
	local WorldSize = CFrame * Size
	local AxisSize = (WorldSize * Normal).Magnitude * 0.5
	Alpha = math.min(1 - (ClosestPoint - Point).Magnitude / AxisSize, 1)

	if not Inside then
		Inside = (ClosestPoint - Point).Magnitude < PointRadius
	end

	return Inside, ClosestPoint, Normal, Alpha
end
