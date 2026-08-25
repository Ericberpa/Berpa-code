-- Project Berpa - Game Router
-- Legacy Main.lua entry point kept for compatibility.

local Players = game:GetService("Players")

local function kickPlayer()
	pcall(function()
		local player = Players.LocalPlayer
		if player then
			player:Kick()
		end
	end)
end

local function runSource(source)
	if type(source) ~= "string" or source == "" then
		return false
	end

	local compiler = loadstring or load
	if type(compiler) ~= "function" then
		return false
	end

	local run = compiler(source)
	if type(run) ~= "function" then
		return false
	end

	local ok = pcall(run)
	return ok
end

local function loadScript()
	local gameId = tostring(game.GameId)

	local candidates = {
		gameId .. ".lua",
		"Bladeball.lua",
		"New script hub/Bladeball.lua",
		"New script hub/" .. gameId .. ".lua",
	}

	if readfile then
		for _, path in ipairs(candidates) do
			local ok, source = pcall(readfile, path)
			if ok and runSource(source) then
				return
			end
		end
	end

	local url =
		"https://raw.githubusercontent.com/Ericberpa/Berpa-code/main/"
		.. gameId
		.. ".lua"

	local ok, source = pcall(function()
		return game:HttpGet(url)
	end)

	if ok and runSource(source) then
		return
	end

	task.delay(2, kickPlayer)
end

loadScript()
