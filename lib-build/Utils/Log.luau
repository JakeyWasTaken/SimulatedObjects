local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Rich = RunService:IsStudio() and true

local Log = {}

local function createLogFunction(levelName: string, logFn: (...string) -> (), Color: Color3, PrintOutDev: boolean)
	return function(...: any)

		-- Get the full path of the module (Path.To.Module), and then take the
		-- final segment as the name (`Module`).
		


local modulePath = debug.info(2, "s"):split(".")
		local moduleName = #modulePath == 0 and "" or `{modulePath[#modulePath - 1]}][{modulePath[#modulePath]}`
		local date = DateTime.now():ToLocalTime()

		local Hour = string.format("%02d", date.Hour)
		local Minute = string.format("%02d", date.Minute)
		local Second = string.format("%02d", date.Second)
		local Millisecond = string.format("%03d", date.Millisecond)

		local RichOpen = Rich
				and `<font color="rgb({math.floor(Color.R * 255)}, {math.floor(Color.G * 255)}, {math.floor(Color.B * 255)})"><font weight="SemiBold">`
			or ""
		local RichClose = Rich and "</font>" or ""
		local Time = Rich and `{Hour}:{Minute}:{Second}.{Millisecond}: ` or ""

		logFn(`{Time}{RichOpen}{levelName}[{moduleName}]:{RichClose}`, ..., `{RichClose}`)
	end
end

local DebugColor = Color3.fromRGB(96, 190, 77)
local InfoColor = Color3.fromRGB(255, 255, 255)
local WarnColor = Color3.fromRGB(255, 148, 33)
local FatalColor = Color3.fromRGB(255, 85, 85)

local FatalFunction = function(...)
	print(...)
	Player:Kick("Fatal error; ", ...)
end

--- Log function prefixed with [SIMOBJ][DEBUG] that only passes through if DEV global is true
Log.debug = createLogFunction("[SIMOBJ][DEBUG]", print, DebugColor, false)
--- Log function prefixed with [SIMOBJ][INFO]
Log.info = createLogFunction("[SIMOBJ][INFO]", print, InfoColor, true)
--- Log function prefixed with [SIMOBJ][WARN]
Log.warn = createLogFunction("[SIMOBJ][WARN]", warn, WarnColor, true)
--- Log function prefixed with [SIMOBJ][FATAL], also kicks the player
Log.fatal = createLogFunction("[SIMOBJ][FATAL]", FatalFunction, FatalColor, true)

return Log
