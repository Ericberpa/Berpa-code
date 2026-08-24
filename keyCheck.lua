-- Project Stark - Legacy compatibility entry point
-- The old key system has been removed. This file now forwards directly to Main.lua.

local compiler = loadstring or load
if type(compiler) ~= "function" then
	return
end

local ok, source = pcall(function()
	return game:HttpGet(
		"https://raw.githubusercontent.com/Urbanstormm/Project-Stark/main/Main.lua"
	)
end)

if not ok or type(source) ~= "string" or source == "" then
	return
end

local run = compiler(source)
if type(run) == "function" then
	pcall(run)
end
