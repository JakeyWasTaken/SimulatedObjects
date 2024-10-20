local Types = require(script.Parent.Parent.Types)
local Utils = require(script.Parent.Parent.Utils)

local Volume = {}
Volume.__index = Volume

function Volume.new(Data: Types.VolumeWindData): typeof(Volume)
	local AssertParameter = function(Key, ValueType)
		Utils.AssertTableParameter(Data, "VolumeWindData", Key, ValueType)
	end

	local self = setmetatable({}, Volume)

	return self
end

return Volume
