--!native
-- TODO: replace this with a better more accurate spring model that doesnt fall apart at high dt

-- Constants

local ITERATIONS = 8
local MAX_DT = 0.1
-- Module


local SPRING = {}

-- Functions

function SPRING.create(mass: number?, force: number?, damping: number?, speed: number?)
	local spring = {
		Target = Vector3.zero,
		Position = Vector3.zero,
		Velocity = Vector3.zero,
		_Acceleration = Vector3.zero,

		Mass = mass or 5,
		Force = force or 50,
		Damping = damping or 4,
		Speed = speed or 4,
	}

	function spring.reset(self, InitialPosition, InitialTarget)
		self.Position = InitialPosition
		self.Target = InitialTarget
		self.Velocity = Vector3.zero
		self._Acceleration = Vector3.zero
	end

	function spring.shove(self, Force: Vector3)
		local x, y, z = Force.X, Force.Y, Force.Z
		if x ~= x or x == math.huge or x == -math.huge then
			x = 0
		end
		if y ~= y or y == math.huge or y == -math.huge then
			y = 0
		end
		if z ~= z or z == math.huge or z == -math.huge then
			z = 0
		end
		self.Velocity = self.Velocity + Vector3.new(x, y, z)
	end

	function spring.applyForce(self, Force: Vector3)
		local x, y, z = Force.X, Force.Y, Force.Z
		if x ~= x or x == math.huge or x == -math.huge then
			x = 0
		end
		if y ~= y or y == math.huge or y == -math.huge then
			y = 0
		end
		if z ~= z or z == math.huge or z == -math.huge then
			z = 0
		end
		self._Acceleration += Vector3.new(x, y, z) / self.Mass
	end

	function spring.update(self, dt: number): Vector3
		local scaledDeltaTime = math.min(dt, 1) * self.Speed / ITERATIONS

		if scaledDeltaTime > MAX_DT then
			scaledDeltaTime = MAX_DT
		end

		for _ = 1, ITERATIONS do
			local iterationForce = self.Target - self.Position
			local acceleration = (iterationForce * self.Force) / self.Mass

			acceleration -= self.Velocity * self.Damping
			acceleration += self._Acceleration
			self._Acceleration = Vector3.zero

			self.Velocity += acceleration * scaledDeltaTime
			self.Position += self.Velocity * scaledDeltaTime
		end
		return self.Position
	end

	function spring.Destroy(self)
		self = nil
	end

	return spring
end

-- Return

return SPRING
