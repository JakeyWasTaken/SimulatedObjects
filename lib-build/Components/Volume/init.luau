local Log = require(script.Parent.Parent.Utils.Log)
local Types = require(script.Parent.Parent.Types)

local ForceVolume = require(script.Force)
local WindVolume = require(script.Wind)

local Volumes = {
	Force = ForceVolume,
	Wind = WindVolume,
}

local _VolumeArray = {}
for VolumeName in Volumes do
	table.insert(_VolumeArray, VolumeName)
end

return function(Data: Types.VolumeData): typeof(ForceVolume) | typeof(WindVolume)
	assert(Data, "Expected VolumeData")
	assert(Data.Type, "Expected VolumeData type")

	assert(Volumes[Data.Type], `Unknown volume type '{Data.Type}', expected one of the following '{table.concat(_VolumeArray, "', '")}'`)

	Log.debug(`Creating {Data.Type} volume.`)
	return Volumes[Data.Type].new(Data)
end
