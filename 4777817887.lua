-- Project Berpa - Blade Ball compatibility loader
-- The protected script is hosted and validated through Junkie.

local compiler = loadstring or load
if type(compiler) ~= "function" then
	return warn("[Project Berpa] loadstring is not supported by this executor.")
end

local ok, source = pcall(function()
	return game:HttpGet(
		"https://raw.githubusercontent.com/Ericberpa/Berpa-code/main/keyCheck.lua"
	)
end)

if not ok or type(source) ~= "string" or source == "" then
	return warn("[Project Berpa] Could not download the key loader.")
end

local chunk, compileError = compiler(source)
if type(chunk) ~= "function" then
	return warn("[Project Berpa] Could not compile the key loader: " .. tostring(compileError))
end

local runOk, runtimeError = pcall(chunk)
if not runOk then
	warn("[Project Berpa] " .. tostring(runtimeError))
end
