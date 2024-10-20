local Types = require(script.Parent.Parent.Types)
local Utils = require(script.Parent.Parent.Utils)

local Volume = {}
Volume.__index = Volume

function Volume.new(Data: Types.VolumeForceData): typeof(Volume)
	local AssertParameter = function(Key, ValueType)
		Utils.AssertTableParameter(Data, "VolumeForceData", Key, ValueType)
	end

	AssertParameter("Force", "number")

	local self = setmetatable({}, Volume)

	return self
end

return Volume
