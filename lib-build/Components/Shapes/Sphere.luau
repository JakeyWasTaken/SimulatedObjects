--!native
local mag = vector.magnitude
local norm = vector.normalize

local function SafeUnit(v3)
	if mag(v3) > 0 then
		return norm(v3)
	end

	return vector.zero
end

--- Alpha is a value between 0 - 1; 0 being the point is in the middle of the shape and 1 being it on the surface.
--- Returns IsInside, Position, Normal, Alpha
return function(Center: vector, Radius: number, Point: vector, PointRadius: number): (boolean, vector, vector, number)
	local Distance = mag(Point - Center)
	local Direction = SafeUnit(Point - Center)
	local UnboundAlpha = Distance / Radius
	local Alpha = UnboundAlpha < 1 and UnboundAlpha or 1

	return Distance < Radius + PointRadius, Center + Direction * Radius, Direction, Alpha
end
