-- This exists to require all the classes and return their definitions, no class should require this as to avoid cyclic dependencies

local ForceVolume = require(script.Parent.Volume.Force)
local WindVolume = require(script.Parent.Volume.Wind)

export type ForceVolume = typeof(ForceVolume)
export type WindVolume = typeof(WindVolume)
export type Volume = ForceVolume | WindVolume

return true
