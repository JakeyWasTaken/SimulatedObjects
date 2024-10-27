local Gizmo = require(script.Gizmo)
do	
Gizmo.Init()
end

type ICeive = Gizmo.ICeive & { Init: nil }

local Wrapper: ICeive = setmetatable({}, {
	__index = function(_, Index)
do			
return Gizmo[Index]
end	





















end,
}) :: any

return table.freeze(Wrapper)
