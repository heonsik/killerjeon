local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local ItemManager = {}

local getStateCallback
local objectiveCollectedCallback
local escapeReachedCallback
local stunChasersCallback
local itemConnections = {}
local activeSpeedEffects = {}
local activeShields = {}
local activeFlashlights = {}
local jumpPadCooldowns = {}
local collectedCores = {}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local function ensureRemote(name)
	local r = remotesFolder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = remotesFolder
	end
	return r
end

local powerupChanged      = ensureRemote("PowerupChanged")
local pickupFlashlight    = ensureRemote("PickupFlashlight")
local flashlightConsumed  = ensureRemote("FlashlightConsumed")
local jumpPadLaunch       = ensureRemote("JumpPadLaunch")

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function setItemVisible(item, visible)
	item.Transparency = visible and (item:GetAttribute("BaseTransparency") or 0) or 1
	item.CanTouch = visible

	for _, child in ipairs(item:GetDescendants()) do
		if child:IsA("PointLight") then
			child.Enabled = visible
		elseif child:IsA("BillboardGui") then
			child.Enabled = visible
		end
	end
end

local function getHumanoid(player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function sendPowerup(player, message, duration)
	powerupChanged:FireClient(player, message, duration or 2.5)
end

local function applySpeedPotion(player)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end

	local token = {}
	activeSpeedEffects[player] = token
	humanoid.WalkSpeed = GameConfig.SpeedPotionWalkSpeed
	sendPowerup(player, "속도 증가", GameConfig.SpeedPotionDuration)

	task.delay(GameConfig.SpeedPotionDuration, function()
		if activeSpeedEffects[player] ~= token then
			return
		end

		activeSpeedEffects[player] = nil
		if humanoid.Parent then
			humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
		end
	end)
end

local function applyShield(player)
	local token = {}
	activeShields[player] = token
	sendPowerup(player, "보호막 준비", GameConfig.ShieldDuration)

	local root = getRoot(player)
	local shieldPart
	if root then
		shieldPart = Instance.new("Part")
		shieldPart.Name = "ShieldBubble"
		shieldPart.Shape = Enum.PartType.Ball
		shieldPart.Size = Vector3.new(9, 9, 9)
		shieldPart.Color = Color3.fromRGB(92, 255, 186)
		shieldPart.Material = Enum.Material.ForceField
		shieldPart.Transparency = 0.42
		shieldPart.Anchored = false
		shieldPart.CanCollide = false
		shieldPart.Massless = true
		shieldPart.CFrame = root.CFrame
		shieldPart.Parent = root.Parent

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = shieldPart
		weld.Parent = shieldPart
	end

	task.delay(GameConfig.ShieldDuration, function()
		if activeShields[player] == token then
			activeShields[player] = nil
		end
		if shieldPart and shieldPart.Parent then
			shieldPart:Destroy()
		end
	end)
end

local function spawnDecoy(player)
	local root = getRoot(player)
	if not root then
		return
	end

	local effectsFolder = ensureFolder(Workspace, "Effects")
	local decoysFolder = ensureFolder(effectsFolder, "Decoys")

	local decoy = Instance.new("Part")
	decoy.Name = player.Name .. "_Decoy"
	decoy.Shape = Enum.PartType.Ball
	decoy.Size = Vector3.new(6, 6, 6)
	decoy.CFrame = root.CFrame * CFrame.new(0, 2, -10)
	decoy.Color = Color3.fromRGB(178, 125, 255)
	decoy.Material = Enum.Material.Neon
	decoy.Anchored = true
	decoy.CanCollide = false
	decoy.Parent = decoysFolder

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 22
	light.Color = decoy.Color
	light.Parent = decoy

	sendPowerup(player, "미끼 설치", 2.5)
	task.delay(GameConfig.DecoyDuration, function()
		if decoy.Parent then
			decoy:Destroy()
		end
	end)
end

local function fireShock(player)
	if stunChasersCallback then
		stunChasersCallback(GameConfig.ShockStunDuration)
	end
	sendPowerup(player, "충격파 발동", GameConfig.ShockStunDuration)
end

local function grantFlashlight(player)
	activeFlashlights[player] = true
	pickupFlashlight:FireClient(player)
	sendPowerup(player, "손전등 획득", 2.5)
end

local function collectCore(player, core)
	if collectedCores[core] then
		return
	end

	collectedCores[core] = true
	setItemVisible(core, false)
	sendPowerup(player, "에너지 코어", 2.5)

	if objectiveCollectedCallback then
		objectiveCollectedCallback(player, core)
	end
end

local function respawnLater(item, delaySeconds)
	task.delay(delaySeconds, function()
		if item.Parent then
			setItemVisible(item, true)
		end
	end)
end

local function handlePickup(item, player)
	local itemType = item:GetAttribute("ItemType")
	if itemType == "SpeedPotion" then
		setItemVisible(item, false)
		applySpeedPotion(player)
		respawnLater(item, GameConfig.SpeedPotionRespawnTime)
	elseif itemType == "ShieldOrb" then
		setItemVisible(item, false)
		applyShield(player)
		respawnLater(item, GameConfig.ItemRespawnTime)
	elseif itemType == "DecoyBeacon" then
		setItemVisible(item, false)
		spawnDecoy(player)
		respawnLater(item, GameConfig.ItemRespawnTime)
	elseif itemType == "ShockOrb" then
		setItemVisible(item, false)
		fireShock(player)
		respawnLater(item, GameConfig.ItemRespawnTime)
	elseif itemType == "Flashlight" then
		setItemVisible(item, false)
		grantFlashlight(player)
		respawnLater(item, GameConfig.FlashlightRespawnTime)
	elseif itemType == "EnergyCore" then
		collectCore(player, item)
	elseif itemType == "EscapeZone" then
		if escapeReachedCallback then
			escapeReachedCallback(player)
		end
	end
end

local function connectPickup(item)
	if itemConnections[item] then
		return
	end

	item:SetAttribute("BaseTransparency", item.Transparency)

	local busy = false
	itemConnections[item] = item.Touched:Connect(function(hit)
		local itemType = item:GetAttribute("ItemType")
		if itemType ~= "EscapeZone" and busy then
			return
		end

		if not item.CanTouch then
			return
		end

		if getStateCallback and getStateCallback() ~= "Playing" then
			return
		end

		local player = getPlayerFromHit(hit)
		if not player then
			return
		end

		if itemType ~= "EscapeZone" then
			busy = true
		end
		handlePickup(item, player)
		task.delay(0.4, function()
			busy = false
		end)
	end)
end

local function connectJumpPad(pad)
	if itemConnections[pad] then
		return
	end

	itemConnections[pad] = pad.Touched:Connect(function(hit)
		local player = getPlayerFromHit(hit)
		if not player then
			return
		end

		local now = os.clock()
		local lastJump = jumpPadCooldowns[player] or 0
		if now - lastJump < GameConfig.JumpPadCooldown then
			return
		end

		local root = getRoot(player)
		if not root then
			return
		end

		jumpPadCooldowns[player] = now
		-- 서버에서 직접 설정하면 클라이언트 물리가 덮어씀 → RemoteEvent로 클라이언트에서 적용
		local horizontalBoost = root.CFrame.LookVector * 28
		local launchVec = Vector3.new(horizontalBoost.X, GameConfig.JumpPadPower, horizontalBoost.Z)
		jumpPadLaunch:FireClient(player, launchVec)
	end)
end

local function connectItem(item)
	if not item:IsA("BasePart") then
		return
	end

	local itemType = item:GetAttribute("ItemType")
	if itemType == "JumpPad" then
		connectJumpPad(item)
	elseif itemType then
		connectPickup(item)
	end
end

function ItemManager.Init(options)
	getStateCallback = options.GetState
	objectiveCollectedCallback = options.OnObjectiveCollected
	escapeReachedCallback = options.OnEscapeReached
	stunChasersCallback = options.StunChasers

	local itemsFolder = Workspace:WaitForChild("Items")
	for _, item in ipairs(itemsFolder:GetChildren()) do
		connectItem(item)
	end

	itemsFolder.ChildAdded:Connect(connectItem)

	local mapFolder = Workspace:WaitForChild("Map")
	for _, item in ipairs(mapFolder:GetDescendants()) do
		connectItem(item)
	end
	mapFolder.DescendantAdded:Connect(connectItem)
end

function ItemManager.ResetRound()
	table.clear(collectedCores)
	local itemsFolder = Workspace:FindFirstChild("Items")
	if not itemsFolder then
		return
	end

	for _, item in ipairs(itemsFolder:GetChildren()) do
		if item:IsA("BasePart") then
			setItemVisible(item, true)
		end
	end

	local effectsFolder = Workspace:FindFirstChild("Effects")
	local decoysFolder = effectsFolder and effectsFolder:FindFirstChild("Decoys")
	if decoysFolder then
		for _, decoy in ipairs(decoysFolder:GetChildren()) do
			decoy:Destroy()
		end
	end
end

function ItemManager.BlockElimination(player)
	if not activeShields[player] then
		return false
	end

	activeShields[player] = nil
	local character = player.Character
	local bubble = character and character:FindFirstChild("ShieldBubble")
	if bubble then
		bubble:Destroy()
	end
	sendPowerup(player, "보호막 방어", 2.5)
	return true
end

function ItemManager.HasFlashlight(player)
	return activeFlashlights[player] == true
end

function ItemManager.UseFlashlight(player)
	activeFlashlights[player] = nil
	flashlightConsumed:FireClient(player)
end

function ItemManager.ResetPlayer(player)
	activeSpeedEffects[player] = nil
	activeShields[player] = nil
	activeFlashlights[player] = nil
	jumpPadCooldowns[player] = nil

	local character = player.Character
	local bubble = character and character:FindFirstChild("ShieldBubble")
	if bubble then
		bubble:Destroy()
	end

	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
	end
end

return ItemManager
