-- Project Berpa - Junkie key system
-- Public loader used by ScriptBlox. The real script is hosted by Junkie.

local CONFIG = {
	service = "Project Berpa - Blade Ball",
	identifier = "1186211",
	provider = "Berpa Service",
	junkieScriptUrl = "https://api.jnkie.com/api/v1/luascripts/public/dd5890ef547d7bb901d97617c128cd4b6f16f89d53b7b545cdad94517d3eb743/download",
	keyFolder = "ProjectBerpa",
	keyFile = "ProjectBerpa/junkie.key",
}

local compile = loadstring or load
if type(compile) ~= "function" then
	return warn("[Project Berpa] loadstring is not supported by this executor.")
end

local function download(url)
	local ok, source = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok or type(source) ~= "string" or source == "" then
		return nil
	end
	return source
end

local librarySource = download("https://jnkie.com/sdk/library.lua")
if not librarySource then
	return warn("[Project Berpa] Could not download the Junkie library.")
end

local libraryChunk = compile(librarySource)
if type(libraryChunk) ~= "function" then
	return warn("[Project Berpa] Could not compile the Junkie library.")
end

local libraryOk, Junkie = pcall(libraryChunk)
if not libraryOk or type(Junkie) ~= "table" then
	return warn("[Project Berpa] Junkie failed to initialize.")
end

Junkie.service = CONFIG.service
Junkie.identifier = CONFIG.identifier
Junkie.provider = CONFIG.provider

local environment = type(getgenv) == "function" and getgenv() or _G

local function trim(value)
	if type(value) ~= "string" then
		return nil
	end

	value = value:match("^%s*(.-)%s*$")
	return value ~= "" and value or nil
end

local function saveKey(value)
	value = trim(value)
	if not value then
		return
	end

	environment.PROJECT_BERPA_SAVED_KEY = value

	if type(writefile) ~= "function" then
		return
	end

	if type(makefolder) == "function" then
		local folderExists = false
		if type(isfolder) == "function" then
			local ok, result = pcall(isfolder, CONFIG.keyFolder)
			folderExists = ok and result == true
		end

		if not folderExists then
			pcall(makefolder, CONFIG.keyFolder)
		end
	end

	pcall(writefile, CONFIG.keyFile, value)
end

local function loadSavedKey()
	local memoryKey = trim(environment.PROJECT_BERPA_SAVED_KEY)
	if memoryKey then
		return memoryKey
	end

	if type(readfile) ~= "function" then
		return nil
	end

	if type(isfile) == "function" then
		local ok, exists = pcall(isfile, CONFIG.keyFile)
		if not ok or not exists then
			return nil
		end
	end

	local ok, value = pcall(readfile, CONFIG.keyFile)
	value = ok and trim(value) or nil
	if value then
		environment.PROJECT_BERPA_SAVED_KEY = value
	end
	return value
end

local function clearSavedKey()
	environment.PROJECT_BERPA_SAVED_KEY = nil

	if type(deletefile) == "function" then
		if type(isfile) ~= "function" then
			pcall(deletefile, CONFIG.keyFile)
			return
		end

		local ok, exists = pcall(isfile, CONFIG.keyFile)
		if ok and exists then
			pcall(deletefile, CONFIG.keyFile)
		end
	elseif type(writefile) == "function" then
		pcall(writefile, CONFIG.keyFile, "")
	end
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local function getGuiParent()
	if type(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and result then
			return result
		end
	end

	local player = Players.LocalPlayer
	if player then
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			return playerGui
		end
	end

	return CoreGui
end

local parent = getGuiParent()
local oldGui = parent:FindFirstChild("ProjectBerpaKeySystem")
if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "ProjectBerpaKeySystem"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

if type(protectgui) == "function" then
	pcall(protectgui, gui)
elseif syn and type(syn.protect_gui) == "function" then
	pcall(syn.protect_gui, gui)
end

local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromOffset(440, 300)
window.BackgroundColor3 = Color3.fromRGB(20, 18, 25)
window.BorderSizePixel = 0
window.Parent = gui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 12)
windowCorner.Parent = window

local windowStroke = Instance.new("UIStroke")
windowStroke.Color = Color3.fromRGB(147, 51, 234)
windowStroke.Thickness = 1.5
windowStroke.Transparency = 0.2
windowStroke.Parent = window

local function addLabel(text, position, size, font, textSize, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = window
	return label
end

addLabel(
	"Project Berpa",
	UDim2.fromOffset(24, 18),
	UDim2.new(1, -48, 0, 34),
	Enum.Font.GothamBold,
	25,
	Color3.fromRGB(255, 255, 255)
)

addLabel(
	"Get a 24h or 48h key, complete the Junkie checkpoint, then paste it below.",
	UDim2.fromOffset(24, 56),
	UDim2.new(1, -48, 0, 40),
	Enum.Font.Gotham,
	13,
	Color3.fromRGB(190, 184, 202)
)

local keyBox = Instance.new("TextBox")
keyBox.BackgroundColor3 = Color3.fromRGB(34, 31, 41)
keyBox.BorderSizePixel = 0
keyBox.Position = UDim2.fromOffset(24, 108)
keyBox.Size = UDim2.new(1, -48, 0, 46)
keyBox.ClearTextOnFocus = false
keyBox.Font = Enum.Font.Code
keyBox.PlaceholderText = "Paste your Junkie key"
keyBox.PlaceholderColor3 = Color3.fromRGB(131, 124, 143)
keyBox.Text = ""
keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
keyBox.TextSize = 14
keyBox.Parent = window

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 8)
keyCorner.Parent = keyBox

local keyPadding = Instance.new("UIPadding")
keyPadding.PaddingLeft = UDim.new(0, 14)
keyPadding.PaddingRight = UDim.new(0, 14)
keyPadding.Parent = keyBox

local function addButton(name, text, position, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = UDim2.new(0.5, -30, 0, 44)
	button.Font = Enum.Font.GothamSemibold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Parent = window

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local getKeyButton = addButton(
	"GetKey",
	"Get Key (24h / 48h)",
	UDim2.fromOffset(24, 170),
	Color3.fromRGB(68, 61, 83)
)

local verifyButton = addButton(
	"VerifyKey",
	"Verify Key",
	UDim2.new(0.5, 6, 0, 170),
	Color3.fromRGB(126, 58, 205)
)

local status = addLabel(
	"Saved keys are reused until they expire. One checkpoint helps with the bills.",
	UDim2.fromOffset(24, 226),
	UDim2.new(1, -48, 0, 52),
	Enum.Font.Gotham,
	12,
	Color3.fromRGB(170, 164, 181)
)
status.TextXAlignment = Enum.TextXAlignment.Center

local busy = false

local function setStatus(message, color)
	status.Text = message
	status.TextColor3 = color or Color3.fromRGB(170, 164, 181)
end

local function copyToClipboard(value)
	local copy = setclipboard or toclipboard
	return type(copy) == "function" and pcall(copy, value)
end

getKeyButton.MouseButton1Click:Connect(function()
	if busy then
		return
	end

	busy = true
	setStatus("Generating the Junkie link...", Color3.fromRGB(216, 203, 239))

	task.spawn(function()
		local ok, link, linkError = pcall(Junkie.get_key_link)
		if ok and type(link) == "string" and link ~= "" then
			if copyToClipboard(link) then
				setStatus("Get Key link copied. Paste it into your browser.", Color3.fromRGB(134, 239, 172))
			else
				print("[Project Berpa] Get Key: " .. link)
				setStatus("The Get Key link is in the executor console.", Color3.fromRGB(253, 224, 71))
			end
		else
			setStatus(
				"Junkie error: " .. tostring(linkError or "RATE_LIMITED") .. ". Try again in 5 minutes.",
				Color3.fromRGB(248, 113, 113)
			)
		end
		busy = false
	end)
end)

local function runProtectedScript(userKey)
	environment.SCRIPT_KEY = userKey
	local source = download(CONFIG.junkieScriptUrl)
	local chunk = source and compile(source)
	if type(chunk) ~= "function" then
		setStatus("Could not load the protected script.", Color3.fromRGB(248, 113, 113))
		busy = false
		return
	end

	gui:Destroy()
	local ok, runtimeError = pcall(chunk)
	if not ok then
		warn("[Project Berpa] " .. tostring(runtimeError))
	end
end

local invalidSavedKeyReasons = {
	KEY_INVALID = true,
	KEY_EXPIRED = true,
	HWID_BANNED = true,
	KEY_INVALIDATED = true,
	ALREADY_USED = true,
	HWID_MISMATCH = true,
	SERVICE_NOT_FOUND = true,
	SERVICE_MISMATCH = true,
	PREMIUM_REQUIRED = true,
}

local function verifyKey(usingSavedKey)
	if busy then
		return
	end

	local userKey = keyBox.Text:match("^%s*(.-)%s*$")
	if userKey == "" then
		return setStatus("Paste a key first.", Color3.fromRGB(253, 224, 71))
	end

	busy = true
	setStatus(
		usingSavedKey and "Checking saved key..." or "Checking key...",
		Color3.fromRGB(216, 203, 239)
	)

	task.spawn(function()
		local ok, result = pcall(Junkie.check_key, userKey)
		local valid = ok and type(result) == "table"
			and (result.valid == true or result.success == true)

		if valid then
			saveKey(userKey)
			setStatus("Key accepted. Loading Project Berpa...", Color3.fromRGB(134, 239, 172))
			task.wait(0.25)
			runProtectedScript(userKey)
			return
		end

		local reason = "KEY_INVALID"
		if ok and type(result) == "table" then
			reason = result.error or result.message or reason
		elseif not ok then
			reason = "NETWORK_ERROR"
		end

		if invalidSavedKeyReasons[tostring(reason)] then
			clearSavedKey()
		end

		setStatus("Key rejected: " .. tostring(reason), Color3.fromRGB(248, 113, 113))
		busy = false
	end)
end

verifyButton.MouseButton1Click:Connect(verifyKey)
keyBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		verifyKey()
	end
end)

local savedKey = loadSavedKey()
if savedKey then
	keyBox.Text = savedKey
	task.defer(function()
		verifyKey(true)
	end)
end
