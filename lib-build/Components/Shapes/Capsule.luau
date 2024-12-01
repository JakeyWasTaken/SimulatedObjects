--!native
local dot = vector.dot
local clamp = math.clamp
local norm = vector.normalize
local mag = vector.magnitude

local function SafeUnit(v3)
	if mag(v3) > 0 then
		return norm(v3)
	end

	return vector.zero
end

local function solve(p0, d0, len, p1)
	local v = p1 - p0
	local k = dot(v, d0)
	k = clamp(k, -len, len)
	return p0 + d0 * k
end

--- Alpha is a value between 0 - 1; 0 being the point is in the middle of the shape and 1 being it on the surface.
--- Returns IsInside, Position, Normal, Alpha
return function(p0: vector, p1: vector, radius: number, point: vector, pointRadius: number): (boolean, vector, vector, number)
	local diff = (p1 - p0)
	local l0 = solve((p0 + p1) * 0.5, norm(diff), mag(diff) * 0.5, point)

	local distance = mag(l0 - point)
	local normal = SafeUnit(point - l0)
	local is_inside = (distance < radius + pointRadius)
	local unbound_alpha = distance / radius
	local alpha = unbound_alpha < 1 and unbound_alpha or 1

	return is_inside, l0 + (normal * radius), normal, alpha
end
