local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Gizmo = require(game:GetService("ReplicatedStorage"):WaitForChild("SimulatedObjects"):WaitForChild("Dependencies"):WaitForChild("Gizmo"))

local SimulatedObjects = require(game:GetService("ReplicatedStorage"):WaitForChild("SimulatedObjects"))

local CornFolder = workspace:WaitForChild("CORN")
local WheatFolder = workspace:WaitForChild("WHEAT")
local GlowFolder = workspace:WaitForChild("GLOW")
local ColliderA = workspace:WaitForChild("ColliderA")
local ColliderB = workspace:WaitForChild("ColliderB")
local Capsule = workspace:WaitForChild("Capsule")

--[[
	Mass = mass or 5,
	Force = force or 50,
	Damping = damping or 4,
	Speed = speed or 4,
]]

local function InInstance(Instance: Instance, Callback: (Instance) -> ())
	for _, Inst in Instance:GetChildren() do
		Callback(Inst)
	end

	Instance.ChildAdded:Connect(Callback)
end

-- InInstance(CornFolder, function(Corn)
-- 	SimulatedObjects.AddObject({ Object = Corn, ApexRadius = 0.25, MaxAngle = 12.5, Orients = false, Mass = 9, Speed = 4 })
-- end)

-- InInstance(WheatFolder, function(Wheat)
-- 	SimulatedObjects.AddObject({ Object = Wheat, ApexRadius = 0.25, MaxAngle = 20, Orients = false })
-- end)

-- InInstance(GlowFolder, function(Glow)
-- 	SimulatedObjects.AddObject({ Object = Glow, ApexRadius = 0.25, MaxAngle = 20, Orients = false, Damping = 3.5 })
-- end)

SimulatedObjects.AddObject({ Object = workspace:WaitForChild("Debug"), ApexRadius = 0.25, MaxAngle = 25, Orients = true })

-- SimulatedObjects.AddCollider({ Shape = "Sphere", Center = ColliderA.Center, Radius = ColliderA.Size.X / 2, StreamingRadius = ColliderA.Size.X + 5 })
-- SimulatedObjects.AddCollider({ Shape = "Box", Center = ColliderB.Center, Size = ColliderB.Size, StreamingRadius = ColliderB.Size.X + 5 })
-- SimulatedObjects.AddCollider({
-- 	Shape = "RoundedFrustum",
-- 	Start = Capsule.p0,
-- 	End = Capsule.p1,
-- 	StartRadius = 1.6 / 2,
-- 	EndRadius = 1.6,
-- 	StreamingRadius = ColliderB.Size.X * 2,
-- })

RunService.RenderStepped:Connect(function(delta)
	SimulatedObjects.Step(delta)
end)

-- TODO: make it so colliders can be removed
local Character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local Root = Character.HumanoidRootPart
SimulatedObjects.AddCollider({ Shape = "Capsule", Start = Root.p0, End = Root.p1, Radius = 1.769, StreamingRadius = 10 })

local Iris = require(script.Parent.Iris)
Iris.Init()

Iris:Connect(function()
	Iris.Window({ "debug" })

	Iris.Text(`Free Springs: {#SimulatedObjects.FreeSpringPool}`)
	Iris.Text(`Hot Springs: {2 ^ 11 - #SimulatedObjects.FreeSpringPool}`)

	Iris.End()
end)

-- WIND TEST
-- RunService.RenderStepped:Connect(function(delta)
-- 	local workspaceWind = workspace.GlobalWind
-- 	local windDirection = workspaceWind.Unit
-- 	local windSpeed, windPower = 0, 0

-- 	local windMagnitude = workspaceWind.Magnitude
-- 	if windMagnitude > 0 then
-- 		windPower = if windMagnitude > 1 then math.log10(windMagnitude) + 0.2 else 0.3
-- 		windSpeed = if windMagnitude < 100 then (windMagnitude * 1.2) + 5 else 125
-- 	end

-- 	local seed = 1
-- 	local now = os.clock()
-- 	local amp = windPower * 0.2
-- 	local freq = now * windSpeed * 0.08
-- 	local animValue = (math.noise(freq, 0, seed) + 0.4) * amp
-- 	local lowAmp = amp / 3

-- 	local Rotation = CFrame.Angles(math.noise(seed, 0, freq) * lowAmp, math.noise(seed, freq, 0) * lowAmp, math.noise(freq, seed, 0) * lowAmp)
-- 	--+ (windDirection * animValue * (amp * 2))

-- 	local Origin = Vector3.yAxis * 3
-- 	local length = 3
-- 	local cf = CFrame.new(Origin) * Rotation * CFrame.Angles(math.pi / 2, 0, 0)

-- 	Gizmo.SetStyle(Color3.new(1))
-- 	Gizmo.Ray:Draw(cf.Position, cf.Position + cf.LookVector * length)
-- end)
