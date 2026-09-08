-- BRP HUB - Storage Hunters: Open World
-- UniverseId: 10261267004 | PlaceId: 98800969324557

if game.GameId ~= 10261267004 then
	return warn("[BRP HUB] This module only supports Storage Hunters: Open World.")
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Events = ReplicatedStorage:WaitForChild("Events")
local AuctionEvents = Events:WaitForChild("Auction")
local PawnEvents = Events:WaitForChild("Pawn")
local PlotEvents = Events:WaitForChild("Plot")
local dynamicRequire = require :: any

local environment = type(getgenv) == "function" and getgenv() or _G
local previousRuntime = environment.BRP_STORAGE_HUNTERS_RUNTIME
if type(previousRuntime) == "table" and type(previousRuntime.Unload) == "function" then
	pcall(function()
		previousRuntime:Unload()
	end)
end

local Runtime = {
	Alive = true,
	Connections = {},
	Highlights = {},
	OriginalPromptDurations = {},
	Window = nil,
	AuctionActive = false,
	CurrentBid = 0,
	NextBid = 0,
	CurrentWinner = nil,
	CurrentGarage = nil,
	LastBidKey = nil,
	LastBidAt = 0,
	LastJoinAt = 0,
	LastSellAt = 0,
	BusyLooting = false,
}

local Settings = {
	AutoFarm = false,
	AutoJoin = false,
	AutoBid = false,
	AutoLoot = false,
	AutoOpenBoxes = false,
	AutoSell = false,
	AutoSellWhenFull = false,
	InstantInteract = false,
	ItemESP = false,
	MaxBid = 500,
	MaxEntryCost = 100,
}
Runtime.Settings = Settings

local function notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "BRP HUB",
			Text = tostring(text or ""),
			Duration = duration or 4,
		})
	end)
end

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(Runtime.Connections, connection)
	return connection
end

local function getCharacter()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, root
end

local function promptPart(prompt)
	if not prompt then
		return nil
	end
	if prompt.Parent and prompt.Parent:IsA("BasePart") then
		return prompt.Parent
	end
	if prompt.Parent and prompt.Parent:IsA("Attachment") and prompt.Parent.Parent:IsA("BasePart") then
		return prompt.Parent.Parent
	end
	return prompt:FindFirstAncestorWhichIsA("BasePart")
end

local function teleportToPart(part, height)
	local character, root = getCharacter()
	if not character or not root or not part then
		return false
	end

	local offset = height or 3
	character:PivotTo(part.CFrame * CFrame.new(0, offset, 0))
	return true
end

local function triggerPrompt(prompt, shouldTeleport)
	if not prompt or not prompt.Parent or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
		return false
	end
	if type(fireproximityprompt) ~= "function" then
		return false
	end

	if shouldTeleport then
		local part = promptPart(prompt)
		if not teleportToPart(part, 3) then
			return false
		end
		task.wait(0.25)
	end

	local ok = pcall(fireproximityprompt, prompt)
	return ok
end

local function findOwnVehicle()
	local equippedGuid = LocalPlayer:GetAttribute("EquippedVehicle")
	for _, instance in ipairs(workspace:GetDescendants()) do
		if instance:IsA("Model")
			and instance:GetAttribute("OwnerUserId") == LocalPlayer.UserId
			and instance:FindFirstChildWhichIsA("VehicleSeat", true)
		then
			local vehicleGuid = instance:GetAttribute("VehicleGUID")
			if not equippedGuid or equippedGuid == "" or vehicleGuid == equippedGuid then
				return instance
			end
		end
	end
	return nil
end

local function getEquippedVehicleGuid()
	local equippedGuid = LocalPlayer:GetAttribute("EquippedVehicle")
	if type(equippedGuid) == "string" and equippedGuid ~= "" then
		return equippedGuid
	end

	local vehicles = Events:FindFirstChild("Vehicles")
	local getOwned = vehicles and vehicles:FindFirstChild("GetOwnedVehicles")
	if not getOwned or not getOwned:IsA("RemoteFunction") then
		return nil
	end

	local ok, result = pcall(function()
		return getOwned:InvokeServer()
	end)
	if ok and type(result) == "table" and type(result.equippedGuid) == "string" then
		return result.equippedGuid
	end
	return nil
end

local function getOrSpawnOwnVehicle()
	local vehicle = findOwnVehicle()
	if vehicle then
		return vehicle
	end

	local vehicleGuid = getEquippedVehicleGuid()
	local vehicles = Events:FindFirstChild("Vehicles")
	local requestSpawn = vehicles and vehicles:FindFirstChild("RequestSpawn")
	if not vehicleGuid or not requestSpawn or not requestSpawn:IsA("RemoteEvent") then
		return nil
	end

	pcall(function()
		requestSpawn:FireServer(vehicleGuid)
	end)

	local deadline = os.clock() + 6
	repeat
		task.wait(0.2)
		vehicle = findOwnVehicle()
	until vehicle or os.clock() >= deadline or not Runtime.Alive
	return vehicle
end

local function seatInOwnVehicle(vehicle)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local driveSeat = vehicle and (vehicle:FindFirstChild("DriveSeat", true) or vehicle:FindFirstChildWhichIsA("VehicleSeat", true))
	if not character or not humanoid or not driveSeat or not driveSeat:IsA("VehicleSeat") then
		return false, nil
	end
	if driveSeat.Occupant == humanoid then
		return true, driveSeat
	end

	character:PivotTo(driveSeat.CFrame * CFrame.new(0, 3, 0))
	task.wait(0.25)
	local vehiclePrompt = driveSeat:FindFirstChild("VehiclePrompt", true)
	if vehiclePrompt and vehiclePrompt:IsA("ProximityPrompt") then
		triggerPrompt(vehiclePrompt, false)
	end

	local deadline = os.clock() + 2
	repeat
		task.wait(0.1)
	until driveSeat.Occupant == humanoid or os.clock() >= deadline

	if driveSeat.Occupant ~= humanoid then
		pcall(function()
			driveSeat:Sit(humanoid)
		end)
		task.wait(0.25)
	end
	return driveSeat.Occupant == humanoid, driveSeat
end

local function moveOwnVehicleToPart(vehicle, part)
	if not vehicle or not part then
		return false
	end

	local seated = seatInOwnVehicle(vehicle)
	if not seated then
		return false
	end

	pcall(function()
		for _, descendant in ipairs(vehicle:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.AssemblyLinearVelocity = Vector3.zero
				descendant.AssemblyAngularVelocity = Vector3.zero
			end
		end
		-- The server validates the vehicle itself, not only prompt distance. EntrySquare
		-- sits above the road, while a correctly parked vehicle pivot is ~1.4 studs below it.
		vehicle:PivotTo(part.CFrame * CFrame.new(0, -1.4, 0))
	end)
	task.wait(0.75)
	return true
end

local function getAuctionUiOpen()
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local container = playerGui and playerGui:FindFirstChild("AuctionBiddingContainer", true)
	return container ~= nil and container.Visible == true
end

local function isEnabled(name)
	return Settings.AutoFarm or Settings[name] == true
end

local function modelOwnerAllowsPickup(model)
	if not model then
		return false
	end
	local owner = model:GetAttribute("Owner")
	return owner == nil or owner == 0 or owner == LocalPlayer.UserId
end

local function inventoryFull()
	local count = tonumber(LocalPlayer:GetAttribute("InventoryCount")) or 0
	local cap = tonumber(LocalPlayer:GetAttribute("InventoryCap")) or math.huge
	return count >= cap
end

local function getLootPrompts(name)
	local prompts = {}
	local roots = {}
	local carryables = workspace:FindFirstChild("_Carryables")
	local debris = workspace:FindFirstChild("_Debris")
	if carryables then
		table.insert(roots, carryables)
	end
	if debris then
		table.insert(roots, debris)
	end
	if #roots == 0 then
		table.insert(roots, workspace)
	end

	local seen = {}
	for _, rootFolder in ipairs(roots) do
		for _, descendant in ipairs(rootFolder:GetDescendants()) do
			if not seen[descendant]
				and descendant:IsA("ProximityPrompt")
				and descendant.Name == name
				and descendant.Enabled
			then
				local model = descendant:FindFirstAncestorOfClass("Model")
				if modelOwnerAllowsPickup(model) then
					seen[descendant] = true
					table.insert(prompts, descendant)
				end
			end
		end
	end

	local _, root = getCharacter()
	if root then
		table.sort(prompts, function(a, b)
			local partA = promptPart(a)
			local partB = promptPart(b)
			local distanceA = partA and (partA.Position - root.Position).Magnitude or math.huge
			local distanceB = partB and (partB.Position - root.Position).Magnitude or math.huge
			return distanceA < distanceB
		end)
	end
	return prompts
end

local function hasAvailableLoot()
	return #getLootPrompts("PickupPrompt") > 0 or #getLootPrompts("OpenBoxPrompt") > 0
end

local function collectOne(promptName)
	if Runtime.AuctionActive or getAuctionUiOpen() or inventoryFull() then
		return false
	end
	local prompt = getLootPrompts(promptName)[1]
	if not prompt then
		return false
	end
	return triggerPrompt(prompt, true)
end

local function collectAllAvailable()
	if Runtime.BusyLooting then
		return
	end
	Runtime.BusyLooting = true

	task.spawn(function()
		local attempts = 0
		while Runtime.Alive and attempts < 80 and not Runtime.AuctionActive and not inventoryFull() do
			local prompt = getLootPrompts("PickupPrompt")[1]
			if not prompt then
				if Settings.AutoOpenBoxes then
					prompt = getLootPrompts("OpenBoxPrompt")[1]
				end
				if not prompt then
					break
				end
			end

			attempts = attempts + 1
			triggerPrompt(prompt, true)
			task.wait(0.7)
		end
		Runtime.BusyLooting = false
	end)
end

local function getBestAuction()
	local _, root = getCharacter()
	local bestModel, bestTarget, bestPrompt, bestCost, bestDistance
	bestCost = math.huge
	bestDistance = math.huge

	local debris = workspace:FindFirstChild("_Debris")
	local garages = debris and debris:FindFirstChild("Garages")
	local searchRoot = garages or debris or workspace
	for _, instance in ipairs(searchRoot:GetDescendants()) do
		if instance:IsA("Model") and instance:GetAttribute("GUID") ~= nil and instance:GetAttribute("InAuction") ~= true then
			local cost = tonumber(instance:GetAttribute("EntryCost")) or math.huge
			local prompt = instance:FindFirstChild("EnterAuction", true)
			local target = prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled and promptPart(prompt)

			local distance = root and target and (target.Position - root.Position).Magnitude or math.huge
			if target and cost <= Settings.MaxEntryCost then
				if cost < bestCost or (cost == bestCost and distance < bestDistance) then
					bestModel = instance
					bestTarget = target
					bestPrompt = prompt
					bestCost = cost
					bestDistance = distance
				end
			end
		end
	end
	return bestModel, bestTarget, bestCost, bestPrompt
end

local function joinBestAuction(showResult)
	if Runtime.AuctionActive or getAuctionUiOpen() then
		if showResult then
			notify("BRP HUB", "You are already in an auction.")
		end
		return false
	end

	local model, auctionTarget, cost, entryPrompt = getBestAuction()
	if not model or not auctionTarget then
		if showResult then
			notify("BRP HUB", "No active auction is inside your entry-cost limit.")
		end
		return false
	end

	Runtime.LastJoinAt = os.clock()
	local vehicle = getOrSpawnOwnVehicle()
	if not vehicle then
		if showResult then
			notify("BRP HUB", "Spawn your equipped vehicle first; BRP could not find it.")
		end
		return false
	end

	if not moveOwnVehicleToPart(vehicle, auctionTarget) then
		if showResult then
			notify("BRP HUB", "Could not seat you in your own vehicle.")
		end
		return false
	end

	local ok = true
	if entryPrompt and entryPrompt.Parent and entryPrompt.Enabled then
		ok = triggerPrompt(entryPrompt, false)
	end
	if showResult then
		if ok then
			notify("BRP HUB", string.format("Joining %s ($%s entry).", model.Name, tostring(cost)))
		else
			notify("BRP HUB", "Could not trigger this auction prompt.")
		end
	end
	return ok
end

local function tryAutoBid()
	if not Runtime.Alive or not isEnabled("AutoBid") or not Runtime.AuctionActive then
		return false
	end
	if Runtime.CurrentWinner == LocalPlayer.Name then
		return false
	end

	local nextBid = tonumber(Runtime.NextBid) or 0
	local maxBid = tonumber(Settings.MaxBid) or 0
	local cash = tonumber(LocalPlayer:GetAttribute("Cash")) or 0
	if nextBid <= 0 or maxBid <= 0 or nextBid > maxBid or nextBid > cash then
		return false
	end

	local bidKey = table.concat({
		tostring(Runtime.CurrentGarage),
		tostring(nextBid),
		tostring(Runtime.CurrentWinner),
	}, ":")
	if Runtime.LastBidKey == bidKey or os.clock() - Runtime.LastBidAt < 0.45 then
		return false
	end

	Runtime.LastBidKey = bidKey
	Runtime.LastBidAt = os.clock()
	local bidRemote = AuctionEvents:FindFirstChild("Bid")
	if not bidRemote or not bidRemote:IsA("RemoteEvent") then
		return false
	end

	local ok = pcall(function()
		bidRemote:FireServer()
	end)
	return ok
end

local function getSellableGuids()
	local ok, entries = pcall(function()
		return PawnEvents:WaitForChild("GetSellableItems"):InvokeServer()
	end)
	if not ok or type(entries) ~= "table" then
		return {}, "Could not read your inventory."
	end

	local saleRules
	pcall(function()
		saleRules = dynamicRequire(ReplicatedStorage.Modules.StockSaleRules)
	end)

	local guids = {}
	for guid, entry in pairs(entries) do
		local blocked = false
		if type(entry) ~= "table" or entry.Favorited == true then
			blocked = true
		elseif saleRules and type(saleRules.GetSellBlockReason) == "function" then
			local rulesOk, reason = pcall(saleRules.GetSellBlockReason, entry)
			blocked = rulesOk and reason ~= nil
		end

		if not blocked then
			table.insert(guids, tostring(guid))
		end
	end
	return guids
end

local function sellAllNonFavorites(showResult)
	if os.clock() - Runtime.LastSellAt < 2 then
		return false
	end
	Runtime.LastSellAt = os.clock()

	local guids, listError = getSellableGuids()
	if #guids == 0 then
		if showResult then
			notify("BRP HUB", listError or "There are no non-favorite sellable items.")
		end
		return false
	end

	local ok, result = pcall(function()
		return PawnEvents:WaitForChild("SellItems"):InvokeServer(guids)
	end)
	if not ok or type(result) ~= "table" or result.success ~= true then
		if showResult then
			notify("BRP HUB", type(result) == "table" and (result.error or "Sale rejected.") or "Sale failed.")
		end
		return false
	end

	if showResult then
		notify(
			"BRP HUB",
			string.format("Sold %d item(s) for $%s.", tonumber(result.sold) or #guids, tostring(result.totalEarned or 0))
		)
	end
	return true
end

local function setInstantInteract(enabled)
	if enabled then
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				if Runtime.OriginalPromptDurations[descendant] == nil then
					Runtime.OriginalPromptDurations[descendant] = descendant.HoldDuration
				end
				descendant.HoldDuration = 0
			end
		end
	else
		for prompt, duration in pairs(Runtime.OriginalPromptDurations) do
			if prompt and prompt.Parent then
				pcall(function()
					prompt.HoldDuration = duration
				end)
			end
		end
		table.clear(Runtime.OriginalPromptDurations)
	end
end

local function refreshItemESP()
	local wanted = {}
	if Settings.ItemESP then
		for _, prompt in ipairs(getLootPrompts("PickupPrompt")) do
			local model = prompt:FindFirstAncestorOfClass("Model")
			if model then
				wanted[model] = true
				if not Runtime.Highlights[model] then
					local highlight = Instance.new("Highlight")
					highlight.Name = "BRP_ItemESP"
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.FillColor = Color3.fromRGB(138, 80, 255)
					highlight.FillTransparency = 0.55
					highlight.OutlineColor = Color3.fromRGB(90, 230, 255)
					highlight.OutlineTransparency = 0
					highlight.Adornee = model
					highlight.Parent = model
					Runtime.Highlights[model] = highlight
				end
			end
		end
	end

	for model, highlight in pairs(Runtime.Highlights) do
		if not wanted[model] or not model.Parent then
			pcall(function()
				highlight:Destroy()
			end)
			Runtime.Highlights[model] = nil
		end
	end
end

Runtime.Actions = {
	CollectAllAvailable = collectAllAvailable,
	FindOwnVehicle = findOwnVehicle,
	GetOrSpawnOwnVehicle = getOrSpawnOwnVehicle,
	JoinBestAuction = joinBestAuction,
	SellAllNonFavorites = sellAllNonFavorites,
	TryAutoBid = tryAutoBid,
}

function Runtime:Unload()
	if not self.Alive then
		return
	end
	self.Alive = false
	Settings.AutoFarm = false

	for _, connection in ipairs(self.Connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.Connections)

	for _, highlight in pairs(self.Highlights) do
		pcall(function()
			highlight:Destroy()
		end)
	end
	table.clear(self.Highlights)
	setInstantInteract(false)

	if self.Window and type(self.Window.Destroy) == "function" then
		pcall(function()
			self.Window:Destroy()
		end)
	end

	if environment.BRP_STORAGE_HUNTERS_RUNTIME == self then
		environment.BRP_STORAGE_HUNTERS_RUNTIME = nil
	end
end

environment.BRP_STORAGE_HUNTERS_RUNTIME = Runtime

connect(AuctionEvents:WaitForChild("ToggleBiddingUI").OnClientEvent, function(active)
	Runtime.AuctionActive = active == true
	if Runtime.AuctionActive and isEnabled("AutoBid") then
		-- The first price update can arrive before the bidding UI is marked active.
		-- Retry as soon as the server opens it so a low maximum bid is not missed.
		task.defer(tryAutoBid)
	end
	if not Runtime.AuctionActive then
		Runtime.CurrentBid = 0
		Runtime.NextBid = 0
		Runtime.CurrentWinner = nil
		Runtime.CurrentGarage = nil
		Runtime.LastBidKey = nil
	end
end)

connect(AuctionEvents:WaitForChild("UpdateCurrentWinningBid").OnClientEvent, function(currentBid, winner, _, nextBid, garage)
	Runtime.CurrentBid = tonumber(currentBid) or 0
	Runtime.NextBid = tonumber(nextBid) or Runtime.CurrentBid
	Runtime.CurrentWinner = winner
	Runtime.CurrentGarage = garage
	if isEnabled("AutoBid") then
		task.defer(tryAutoBid)
	end
end)

pcall(function()
	local UIController = dynamicRequire(ReplicatedStorage.Modules.UIController)
	Runtime.AuctionActive = UIController:IsOpen("AuctionBidding") == true
end)

task.spawn(function()
	while Runtime.Alive do
		if isEnabled("AutoJoin") and not Runtime.AuctionActive and not getAuctionUiOpen() then
			if not (isEnabled("AutoLoot") and hasAvailableLoot()) and os.clock() - Runtime.LastJoinAt >= 5 then
				joinBestAuction(false)
			end
		end
		task.wait(1)
	end
end)

task.spawn(function()
	while Runtime.Alive do
		if isEnabled("AutoLoot") and not Runtime.AuctionActive and not getAuctionUiOpen() and not inventoryFull() then
			if collectOne("PickupPrompt") then
				task.wait(0.7)
			elseif isEnabled("AutoOpenBoxes") and collectOne("OpenBoxPrompt") then
				task.wait(0.7)
			end
		end
		task.wait(0.35)
	end
end)

task.spawn(function()
	while Runtime.Alive do
		local shouldSell = isEnabled("AutoSell")
		if Settings.AutoSellWhenFull and inventoryFull() then
			shouldSell = true
		end
		if shouldSell and not Runtime.AuctionActive and os.clock() - Runtime.LastSellAt >= 8 then
			sellAllNonFavorites(false)
		end
		task.wait(2)
	end
end)

task.spawn(function()
	while Runtime.Alive do
		if Settings.InstantInteract then
			setInstantInteract(true)
		end
		refreshItemESP()
		task.wait(1.5)
	end
end)

local uiSource
local uiOk = pcall(function()
	uiSource = game:HttpGet("https://raw.githubusercontent.com/Ericberpa/Berpa-code/main/UiLib.lua")
end)
local compiler = loadstring
local uiChunk = uiOk and type(uiSource) == "string" and type(compiler) == "function" and compiler(uiSource)
if type(uiChunk) ~= "function" then
	Runtime:Unload()
	return warn("[BRP HUB] Could not load UiLib.lua.")
end

local libraryOk, Library = pcall(uiChunk)
if not libraryOk or type(Library) ~= "table" or type(Library.Window) ~= "function" then
	Runtime:Unload()
	return warn("[BRP HUB] UiLib.lua failed to initialize.")
end

local Window = Library:Window("BRP HUB | Storage Hunters", Color3.fromRGB(138, 80, 255))
Runtime.Window = Window
Window:BindToggleKey(Enum.KeyCode.RightShift)

local AuctionTab = Window:Tab("Auction")
AuctionTab:Label("Safe limits apply to both Auto Farm and Auto Bid.")
AuctionTab:Toggle("Auto Farm (join + bid + loot + sell)", function(value)
	Settings.AutoFarm = value
	if value then
		notify("BRP HUB", "Auto Farm enabled. Max-bid and entry limits are active.")
	end
end)
AuctionTab:Toggle("Auto Start Available Auctions", function(value)
	Settings.AutoJoin = value
end)
AuctionTab:Slider("Maximum Entry Cost", 0, 5000, Settings.MaxEntryCost, function(value)
	Settings.MaxEntryCost = value
end)
AuctionTab:Toggle("Auto Bid", function(value)
	Settings.AutoBid = value
	if value then
		task.defer(tryAutoBid)
	end
end)
AuctionTab:Slider("Maximum Bid", 0, 100000, Settings.MaxBid, function(value)
	Settings.MaxBid = value
end)
AuctionTab:Button("Start Cheapest Available Auction", function()
	task.spawn(joinBestAuction, true)
end)

local FarmTab = Window:Tab("Farm & Loot")
FarmTab:Toggle("Auto Loot", function(value)
	Settings.AutoLoot = value
end)
FarmTab:Toggle("Auto Open Storage Boxes", function(value)
	Settings.AutoOpenBoxes = value
end)
FarmTab:Toggle("Instant Interact", function(value)
	Settings.InstantInteract = value
	setInstantInteract(value)
end)
FarmTab:Toggle("Item ESP", function(value)
	Settings.ItemESP = value
	refreshItemESP()
end)
FarmTab:Button("Collect Available Loot", collectAllAvailable)

local SellTab = Window:Tab("Sell")
SellTab:Label("Favorites and server-blocked items are always kept.")
SellTab:Toggle("Auto Sell Non-Favorites", function(value)
	Settings.AutoSell = value
end)
SellTab:Toggle("Auto Sell When Inventory Is Full", function(value)
	Settings.AutoSellWhenFull = value
end)
SellTab:Button("Sell All Non-Favorites Now", function()
	task.spawn(sellAllNonFavorites, true)
end)

local TeleportTab = Window:Tab("Teleports")
TeleportTab:Button("Teleport to My Plot", function()
	local remote = PlotEvents:FindFirstChild("TeleportToPlot")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer()
	end
end)
TeleportTab:Button("Teleport to Pawn Shop", function()
	for _, prompt in ipairs(workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and prompt.Name == "ShopPrompt" then
			local attributes = prompt:GetAttributes()
			if attributes.ScreenName == "PawnShop" then
				teleportToPart(promptPart(prompt), 4)
				return
			end
		end
	end
	notify("BRP HUB", "Pawn Shop is not currently streamed in.")
end)
TeleportTab:Button("Bring Vehicle to Available Auction", function()
	task.spawn(joinBestAuction, true)
end)

local VehicleTab = Window:Tab("Vehicle")
VehicleTab:Label("Auction travel uses your equipped vehicle, not only your character.")
VehicleTab:Button("Find / Spawn Equipped Vehicle", function()
	task.spawn(function()
		local vehicle = getOrSpawnOwnVehicle()
		notify("BRP HUB", vehicle and ("Vehicle ready: " .. vehicle.Name) or "Could not spawn the equipped vehicle.")
	end)
end)
VehicleTab:Button("Bring Vehicle to Me", function()
	task.spawn(function()
		local vehicle = getOrSpawnOwnVehicle()
		local _, root = getCharacter()
		if not vehicle or not root then
			return notify("BRP HUB", "Vehicle or character is unavailable.")
		end
		local pivot = root.CFrame * CFrame.new(0, 2, -10)
		vehicle:PivotTo(pivot)
		return notify("BRP HUB", "Your equipped vehicle was brought nearby.")
	end)
end)

local SettingsTab = Window:Tab("Settings")
SettingsTab:Label("Right Shift hides or shows the hub.")
SettingsTab:Label("Auto Bid never exceeds Maximum Bid or your available cash.")
SettingsTab:Button("Unload BRP HUB", function()
	Runtime:Unload()
end)

notify("BRP HUB", "Storage Hunters loaded. Press Right Shift to hide/show.", 5)
