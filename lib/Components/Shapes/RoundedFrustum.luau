--!native
local function SafeUnit(v3)
	if v3.Magnitude == 0 then
		return Vector3.zero
	end

	return v3.Unit
end

local function solve(p0, d0, len, p1)
	local v = p1 - p0
	local k = v * d0
	k = math.clamp(k, -len, len)
	local t = (k / len) * 0.5 + 0.5
	return p0 + d0 * k, t
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

--- Alpha is a value between 0 - 1; 0 being the point is in the middle of the shape and 1 being it on the surface.
--- Returns IsInside, Position, Normal, Alpha
return function(p0: Vector3, p1: Vector3, radius0: number, radius1: number, point: Vector3, pointRadius: number)
	local diff = (p1 - p0)
	local l0, t = solve((p0 + p1) * 0.5, diff.Unit, diff.Magnitude * 0.5, point)

	local radius = lerp(radius0, radius1, t)
	local distance = (l0 - point).Magnitude
	local normal = SafeUnit(point - l0)
	local is_inside = (distance < radius + pointRadius)
	local alpha = math.min(distance / radius, 1)

	return is_inside, l0 + (normal * radius), normal, alpha
end
