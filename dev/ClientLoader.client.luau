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

InInstance(CornFolder, function(Corn)
	SimulatedObjects.AddObject({ Object = Corn, ApexRadius = 0.25, MaxAngle = 12.5, Orients = false, Mass = 9, Speed = 4 })
end)

InInstance(WheatFolder, function(Wheat)
	SimulatedObjects.AddObject({ Object = Wheat, ApexRadius = 0.25, MaxAngle = 20, Orients = false })
end)

InInstance(GlowFolder, function(Glow)
	SimulatedObjects.AddObject({ Object = Glow, ApexRadius = 0.25, MaxAngle = 20, Orients = false, Damping = 3.5 })
end)

-- for _, Zombie in workspace:WaitForChild("Zombies"):GetChildren() do
-- 	local Root = Zombie.HumanoidRootPart
-- 	SimulatedObjects.AddCollider({ Shape = "Capsule", Start = Root.p0, End = Root.p1, Radius = 1.769, StreamingRadius = 10 })
-- end

SimulatedObjects.AddObject({ Object = workspace:WaitForChild("Debug"), ApexRadius = 0.25, MaxAngle = 25, Orients = true })

-- SimulatedObjects.AddCollider({ Shape = "Sphere", Center = ColliderA.Center, Radius = ColliderA.Size.X / 2, StreamingRadius = ColliderA.Size.X + 5 })
-- SimulatedObjects.AddCollider({ Shape = "Box", Center = ColliderB.Center, Size = ColliderB.Size, StreamingRadius = ColliderB.Size.X + 5 })
-- SimulatedObjects.AddCollider({
-- 	Shape = "Box",
-- 	Center = workspace:WaitForChild("DebugCollider"):WaitForChild("Center"),
-- 	Size = workspace:WaitForChild("DebugCollider").Size,
-- 	StreamingRadius = workspace:WaitForChild("DebugCollider").Size.X + 5,
-- })
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

local Wind = Iris.State(Vector3.new(1.25, 0, 3.25))

Wind:onChange(function()
	workspace.GlobalWind = Wind:get()
end)

Iris:Connect(function()
	Iris.Window({ "debug" })

	Iris.Text(`Free Springs: {#SimulatedObjects.FreeSpringPool}`)
	Iris.Text(`Hot Springs: {2 ^ 12 - #SimulatedObjects.FreeSpringPool}`)
	Iris.Text(`Wind Simulated: {SimulatedObjects.WindSimulated}`)

	Iris.DragVector3({ "Wind Speed", Vector3.one * 0.1, nil, nil, "%.3f" }, { number = Wind })

	Iris.End()
end)
