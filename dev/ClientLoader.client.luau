local RunService = game:GetService("RunService")

_G.DEV = RunService:IsStudio()

local SimulatedObjects = require(game:GetService("ReplicatedStorage"):WaitForChild("SimulatedObjects"))

local Corn = workspace:WaitForChild("Objects"):WaitForChild("Corn")
local Collider = workspace:WaitForChild("Collider")

SimulatedObjects.AddObject({ Object = Corn, ApexRadius = 0.5, MaxAngle = 25, Orients = false })
SimulatedObjects.AddCollider({ Shape = "Sphere", Center = Collider.Center, Radius = Collider.Size.X / 2, StreamingRadius = Collider.Size.X * 2 })

RunService.RenderStepped:Connect(function(delta)
	SimulatedObjects.Step(delta)
end)

-- local Iris = require(script.Parent.Iris)
-- Iris.Init()

-- local lines = Iris.State({ 0 })

-- Iris:Connect(function()
-- 	Iris.Window({ "hello world" })

-- 	local t = {}
-- 	for i = 1, 250 do
-- 		table.insert(t, math.sin(os.clock() + i) * 75)
-- 	end
-- 	lines:set(t)

-- 	Iris.PlotLines({ "hi", -100, 100, 50 }, { values = lines })

-- 	Iris.End()
-- end)
