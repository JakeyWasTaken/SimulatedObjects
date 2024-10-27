--!native
--- Alpha is a value between 0 - 1; 0 being the point is in the middle of the shape and 1 being it on the surface.
--- Returns IsInside, Position, Normal, Alpha
return function(Center: Vector3, Radius: number, Point: Vector3, PointRadius: number): (boolean, Vector3, Vector3, number)
	local Distance = (Point - Center).Magnitude
	local Direction = (Point - Center).Unit
	local Alpha = math.min(Distance / Radius, 1)

	return Distance < Radius + PointRadius, Center + Direction * Radius, Direction, Alpha
end
