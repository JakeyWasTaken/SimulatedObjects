--[[

AddObject: () -> ()
AddVolume: () -> ()
AddCollider: () -> ()

]]

local ClassTypes = require(script.ClassTypes)
local Types = require(script.Types)

local Gizmo = require(script.Dependencies.Gizmo)
local Volume = require(script.Volume)

Gizmo.Init()

local SimulatedObjects = {}

function SimulatedObjects.AddObject(Object: BasePart | Model) end

function SimulatedObjects.AddVolume(VolumeData: Types.VolumeData)
	assert(VolumeData, "Expected volume data")
	Volume(VolumeData)
end

function SimulatedObjects.AddCollider() end

return SimulatedObjects
