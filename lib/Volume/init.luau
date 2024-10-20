local Types = require(script.Parent.Types)

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

local KnownVolumes = table.concat(_VolumeArray, ", ")

return function(Data: Types.VolumeData)
	assert(Data, "Expected volume data")
	assert(Data.Type, "Expected volume data type")

	assert(Volumes[Data.Type], `Unknown volume type '{Data.Type}', expected one of the following '{KnownVolumes}'`)

	return Volumes[Data.Type].new(Data)
end
