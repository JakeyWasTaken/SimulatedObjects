--!optimize 2
--- General helper class to contain small pure functions

local General = {}

--- Callback assert.
--- Returns true if the assertion failed
function General.CBASSERT(condition: boolean, callback: ((...any) -> ())?, ...: any?): boolean
	if not condition then
		if callback then
			callback(...)
		end
		return true
	end
	return false
end

--- Warn assert.
--- Returns true if the assertion failed
function General.WASSERT(condition: boolean, ...: string): boolean
	if not condition then
		warn("(ASSERTION FAILED): ", ..., `\n{debug.traceback(nil, 2)}`)
		return true
	end
	return false
end

function General.SafeUnitV3(Vector: Vector3): Vector3
	if Vector.Magnitude > 0 then
		return Vector.Unit
	end

	return Vector3.zero
end

function General.SafeUnitV2(Vector: Vector2): Vector2
	if Vector.Magnitude > 0 then
		return Vector.Unit
	end

	return Vector2.zero
end

function General.LimitRadianAngle(Angle: number): number
	local TwoPi = math.pi * 2

	while Angle < -math.pi do
		Angle += TwoPi
	end
	while Angle > math.pi do
		Angle -= TwoPi
	end

	return Angle
end

function General.GetAtanOfXY(x: number, y: number): number
	if x == 0 or y == 0 then
		return 0
	end

	local xabs = math.abs(x)
	local yabs = math.abs(y)

	if xabs < yabs then
		if y > 0 then
			if x > 0 then
				return 0.5 * math.pi - math.atan2(x / y, 1)
			else
				return 0.5 * math.pi + math.atan2(-x / y, 1)
			end
		else
			if x > 0 then
				return 1.5 * math.pi + math.atan2(x / -y, 1)
			else
				return 1.5 * math.pi - math.atan2(-x / -y, 1)
			end
		end
	else
		if y > 0 then
			if x > 0 then
				return math.atan2(y / x, 1)
			else
				return math.pi - math.atan2(y / -x, 1)
			end
		else
			if x > 0 then
				return 2 * math.pi - math.atan2(-y / x, 1)
			else
				return math.pi + math.atan2(-y / -x, 1)
			end
		end
	end
end

function General.SignedAngleBetween(a: Vector3, b: Vector3, up: Vector3): number
	local cos = a:Dot(b)
	local sin = a:Cross(b).Magnitude
	local cross = a:Cross(b)

	local angle = math.atan2(sin, cos)

	if up:Dot(cross) < 0 then
		angle = -angle
	end

	return angle
end

function General.AngleBetween(a: Vector3, b: Vector3): number
	local cos = a:Dot(b)
	local sin = a:Cross(b).Magnitude
	return math.atan2(sin, cos)
end

--- This assumes that the normal vector is normalized.
function General.ProjectOntoPlane(v: Vector3, n: Vector3): Vector3
	return v - v:Dot(n) / 1 * n
end

function General.FormatNumbers(decimal: number, ...: number): string
	decimal = math.floor(decimal)

	local sout = ""
	for i, v in ipairs(table.pack(...)) do
		sout ..= `{i == 1 and "" or ", "}{string.format(`%.{decimal}f`, v)}`
	end

	return sout
end

function General.RayPlaneIntersection(PlaneO: Vector3, PlaneN: Vector3, RayO: Vector3, RayN: Vector3): Vector3
	local d = PlaneO:Dot(-PlaneN)
	local t = -(d + RayO:Dot(PlaneN)) / RayN:Dot(PlaneN)
	return RayO + t * RayN
end

function General.MapValue(n: number, start: number, stop: number, newStart: number, newStop: number, Clamp: boolean)
	local v = ((n - start) / (stop - start)) * (newStop - newStart) + newStart

	if Clamp then
		if newStart < newStop then
			return math.clamp(v, newStart, newStop)
		else
			return math.clamp(v, newStop, newStart)
		end
	else
		return v
	end
end

function General.Map<T>(Array: { T }, Func: (T) -> any)
	local NewArray = {}

	for _, Value in Array do
		table.insert(NewArray, Func(Value))
	end

	return NewArray
end

function General.ReflectVector(Vector: Vector3, Normal: Vector3): Vector3
	return Vector - 2 * (Vector:Dot(Normal)) * Normal
end

--- @return (boolean, Vector3, Vector3) -- IsInside, ClosestPoint, Normal
function General.ClosestPointOnBox(CFrame: CFrame, Size: Vector3, Point: Vector3): (boolean, Vector3, Vector3)
	local rel = CFrame:PointToObjectSpace(Point)
	local sx, sy, sz = Size.X, Size.Y, Size.Z
	local rx, ry, rz = rel.X, rel.Y, rel.Z

	-- constrain to within the box
	local cx = math.clamp(rx, -sx * 0.5, sx * 0.5)
	local cy = math.clamp(ry, -sy * 0.5, sy * 0.5)
	local cz = math.clamp(rz, -sz * 0.5, sz * 0.5)

	if not (cx == rx and cy == ry and cz == rz) then
		local closestPoint = CFrame * Vector3.new(cx, cy, cz)
		local normal = General.SafeUnitV3(Point - closestPoint)
		return false, closestPoint, normal
	end

	-- else, they are intersecting, find the surface the Point is closest to

	local posX = rx - sx * 0.5
	local posY = ry - sy * 0.5
	local posZ = rz - sz * 0.5
	local negX = -rx - sx * 0.5
	local negY = -ry - sy * 0.5
	local negZ = -rz - sz * 0.5

	local max = math.max(posX, posY, posZ, negX, negY, negZ)
	if max == posX then
		local closestPoint = CFrame * Vector3.new(sx * 0.5, ry, rz)
		return true, closestPoint, CFrame.XVector
	elseif max == posY then
		local closestPoint = CFrame * Vector3.new(rx, sy * 0.5, rz)
		return true, closestPoint, CFrame.YVector
	elseif max == posZ then
		local closestPoint = CFrame * Vector3.new(rx, ry, sz * 0.5)
		return true, closestPoint, CFrame.ZVector
	elseif max == negX then
		local closestPoint = CFrame * Vector3.new(-sx * 0.5, ry, rz)
		return true, closestPoint, -CFrame.XVector
	elseif max == negY then
		local closestPoint = CFrame * Vector3.new(rx, -sy * 0.5, rz)
		return true, closestPoint, -CFrame.YVector
	elseif max == negZ then
		local closestPoint = CFrame * Vector3.new(rx, ry, -sz * 0.5)
		return true, closestPoint, -CFrame.ZVector
	end

	return false, Vector3.zero, Vector3.zero
end

--- @param a0 Vector3
--- @param a1 Vector3
--- @param point Vector3
--- @param lead number -- Percentage of how far extra we should push the closest point along the line segment
function General.ClosestPointOnLineSegment(a0: Vector3, a1: Vector3, point: Vector3, lead: number)
	local Distance = (a0 - a1).Magnitude

	if Distance == 0 then
		return a0
	end

	local Direction = (a1 - a0).Unit
	local LeadDistance = (lead or 0) * Distance

	local ProjectedDistance = ((point - a0):Dot(Direction) / Direction.Magnitude ^ 2) + LeadDistance
	ProjectedDistance = math.clamp(ProjectedDistance, 0, Distance)

	return a0 + Direction * ProjectedDistance
end

function General.Lerp(a: number, b: number, t: number)
	return a + (b - a) * t
end

function General.CallForIndex<T>(Array: { T }, Callback: (T, number) -> ())
	for i, Item in Array do
		Callback(Item, i)
	end
end

function General.AppendTables(...: { [any]: any })
	local Length = select("#", ...)
	local NewArray = {}

	for i = 1, Length do
		local Array = select(i, ...)

		for k, v in Array do
			if type(k) == "number" then
				table.insert(NewArray, v)
			else
				NewArray[k] = v
			end
		end
	end

	return NewArray
end

function General.AppendIntoTable(Table: { [any]: any }, ...: { [any]: any })
	local Length = select("#", ...)

	for i = 1, Length do
		local Array = select(i, ...)

		for k, v in Array do
			if type(k) == "number" then
				table.insert(Table, v)
			else
				Table[k] = v
			end
		end
	end

	return Table
end

function General.AssertTableParameter(Table: { [any]: any }, TableName: string, Key: any, ValueType: string, Optional: boolean)
	local Exists = Table[Key] ~= nil

	if not Optional then
		assert(Exists, `Expected key of type '{typeof(Key)}' with value '{Key}' in {TableName}`)
	elseif not Exists then
		return
	end

	assert(
		typeof(Table[Key]) == ValueType,
		`Expected {Optional and "optional " or ""}value to be of type '{ValueType}' under key '{Key}' :: '{typeof(Key)}' in {TableName}`
	)
end

return General
