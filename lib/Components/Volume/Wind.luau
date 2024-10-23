local General = require(script.Parent.Parent.Parent.Utils.General)
local Types = require(script.Parent.Parent.Parent.Types)

local CVolume = {}
CVolume.__index = CVolume

function CVolume.new(Data: Types.VolumeWindData): typeof(CVolume)
	local AssertParameter = function(Key, ValueType, Optional)
		General.AssertTableParameter(Data, "VolumeWindData", Key, ValueType, Optional)
	end

	local self = setmetatable({}, CVolume)

	return self
end

return CVolume
