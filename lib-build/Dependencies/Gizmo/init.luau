local Gizmo = require(script.Gizmo)




type ICeive = Gizmo.ICeive & { Init: nil }

local Wrapper: ICeive = setmetatable({}, {
	__index = function(_, Index)
do			


local PossibleIndexs = {
				SetStyle = true,
				AddDebrisInSeconds = true,
				PushProperty = true,
				PopProperty = true,
				AddDebrisInFrames = true,
				SetEnabled = true,
				DoCleaning = true,
				ScheduleCleaning = true,
				TweenProperties = true,
			}

			if PossibleIndexs[Index] then
				return function() end
			end

			return {
				Draw = function() end,
				Create = function() end,
			}
end	
end,
}) :: any

return table.freeze(Wrapper)
