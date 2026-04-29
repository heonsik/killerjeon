local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ChaserController = require(script.Parent:WaitForChild("ChaserController"))
local DroneController = require(script.Parent:WaitForChild("DroneController"))
local KillerController = require(script.Parent:WaitForChild("KillerController"))
local HazardController = require(script.Parent:WaitForChild("HazardController"))
local ItemManager = require(script.Parent:WaitForChild("ItemManager"))
local MapEventController = require(script.Parent:WaitForChild("MapEventController"))

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local r = remotesFolder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotesFolder
	end
	return r
end

local gameStateChanged  = ensureRemote("GameStateChanged")
local timerChanged      = ensureRemote("TimerChanged")
local aliveCountChanged = ensureRemote("AliveCountChanged")
local objectiveChanged  = ensureRemote("ObjectiveChanged")
local roundResult       = ensureRemote("RoundResult")
local playerEliminated  = ensureRemote("PlayerEliminated")
local dangerAlert       = ensureRemote("DangerAlert")
local announcement      = ensureRemote("Announcement")
local detectionLevel    = ensureRemote("DetectionLevel")
local detectionAlert    = ensureRemote("DetectionAlert")
local difficultyChanged = ensureRemote("DifficultyChanged")
local setDifficulty     = ensureRemote("SetDifficulty")
local flashlightHit     = ensureRemote("FlashlightHit")
local respawnRequest    = ensureRemote("RespawnRequest")
local eventAnnouncement = ensureRemote("EventAnnouncement")

-- ── 상태 ─────────────────────────────────────────────────────────────────────

local state = "Waiting"
local alivePlayers = {}
local escapedPlayers = {}
local pendingRespawn = {}
local autoStartQueued = false
local roundToken = 0
local finishInProgress = false
local objectiveCount = 0
local initialParticipantCount = 0
local currentRushMultiplier = 1
local currentSurvivorMultiplier = 1
local selectedDifficulty = GameConfig.DefaultDifficulty
local queueAutoStart

local function getSpawnPart(name)
	local spawnsFolder = Workspace:WaitForChild("Spawns")
	return spawnsFolder:WaitForChild(name)
end

getSpawnPart("LobbySpawn")
getSpawnPart("GameSpawn")
getSpawnPart("ChaserSpawn")

local function getAliveCount()
	local count = 0
	for _, alive in pairs(alivePlayers) do
		if alive then count += 1 end
	end
	return count
end

local function getEscapedCount()
	local count = 0
	for _, escaped in pairs(escapedPlayers) do
		if escaped then count += 1 end
	end
	return count
end

local function getObjectiveTotal()
	if initialParticipantCount > 0 then
		return initialParticipantCount
	end
	return math.max(#Players:GetPlayers(), 1)
end

local function fireState()
	gameStateChanged:FireAllClients(state)
	aliveCountChanged:FireAllClients(getAliveCount(), #Players:GetPlayers())
	objectiveChanged:FireAllClients(getEscapedCount(), getObjectiveTotal())
end

local function setState(nextState)
	state = nextState
	fireState()
end

local function restoreCharacterControl(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if root then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function getSafeSpawnPosition(character, targetPart, offsetIndex)
	local index = (offsetIndex or 1) - 1
	local offset = Vector3.new(index % 5 * 8, 0, math.floor(index / 5) * 8)
	local basePosition = targetPart.Position + offset

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = character and { character } or {}

	local rayStart = basePosition + Vector3.new(0, 90, 0)
	local result = Workspace:Raycast(rayStart, Vector3.new(0, -260, 0), rayParams)
	if result then
		return result.Position + Vector3.new(0, 7, 0)
	end

	local topY = targetPart.Position.Y + targetPart.Size.Y * 0.5 + 7
	return Vector3.new(basePosition.X, math.max(topY, 8), basePosition.Z)
end

local function teleportPlayer(player, targetPartOrName, offsetIndex)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then return end

	local targetPart = targetPartOrName
	if typeof(targetPartOrName) == "string" then
		targetPart = getSpawnPart(targetPartOrName)
	elseif not targetPartOrName.Parent then
		targetPart = getSpawnPart(targetPartOrName.Name)
	end

	restoreCharacterControl(character)
	local spawnPosition = getSafeSpawnPosition(character, targetPart, offsetIndex)
	character:PivotTo(CFrame.new(spawnPosition))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function teleportAllToLobby()
	for index, player in ipairs(Players:GetPlayers()) do
		ItemManager.ResetPlayer(player)
		teleportPlayer(player, "LobbySpawn", index)
	end
end

local function isAlive(player)
	return alivePlayers[player] == true
end

local function stopRoundActors()
	ChaserController.Despawn()
	DroneController.Despawn()
	KillerController.Despawn()
	MapEventController.Stop()
end

local function updateChaserSpeed()
	ChaserController.SetSpeedMultiplier(currentRushMultiplier * currentSurvivorMultiplier)
end

local function getEffectsFolder()
	local f = Workspace:FindFirstChild("Effects")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Effects"
		f.Parent = Workspace
	end
	return f
end

local function spawnBloodPool(position)
	local effects = getEffectsFolder()
	local pools = effects:FindFirstChild("BloodPools")
	if not pools then
		pools = Instance.new("Folder")
		pools.Name = "BloodPools"
		pools.Parent = effects
	end
	local blood = Instance.new("Part")
	blood.Name = "BloodPool"
	blood.Shape = Enum.PartType.Cylinder
	blood.Size = Vector3.new(0.28, 9, 9)
	blood.CFrame = CFrame.new(position.X, 1, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	blood.Color = Color3.fromRGB(90, 10, 10)
	blood.Material = Enum.Material.SmoothPlastic
	blood.Anchored = true
	blood.CanCollide = false
	blood.Parent = pools
end

local function clearBloodPools()
	local effects = Workspace:FindFirstChild("Effects")
	local pools = effects and effects:FindFirstChild("BloodPools")
	if pools then
		for _, v in ipairs(pools:GetChildren()) do v:Destroy() end
	end
end

local function finishRound(resultKey, resultText)
	if finishInProgress then return end
	finishInProgress = true
	roundToken += 1
	setState("Finished")
	stopRoundActors()
	currentRushMultiplier = 1
	currentSurvivorMultiplier = 1
	roundResult:FireAllClients(resultKey, resultText)
	timerChanged:FireAllClients(0, "완료")

	-- 미처 리스폰 못 한 플레이어 강제 리스폰
	local toRespawn = {}
	for player, _ in pairs(pendingRespawn) do
		table.insert(toRespawn, player)
	end
	table.clear(pendingRespawn)
	for _, player in ipairs(toRespawn) do
		task.spawn(function() player:LoadCharacter() end)
	end

	task.wait(GameConfig.ResultDisplayTime)
	table.clear(alivePlayers)
	table.clear(escapedPlayers)
	objectiveCount = 0
	ItemManager.ResetRound()
	clearBloodPools()
	teleportAllToLobby()
	setState("Waiting")
	roundResult:FireAllClients("", "")
	finishInProgress = false

	if queueAutoStart then queueAutoStart() end
end

local function finishIfNoOneLeftInMaze()
	if getAliveCount() > 0 then
		return
	end

	if getEscapedCount() > 0 then
		finishRound("SurvivorsWin", "탈출 성공! 친구들이 킬러의 미로를 빠져나갔습니다!")
	else
		finishRound("ChaserWin", "킬러 승리! 아무도 탈출하지 못했습니다.")
	end
end

local function eliminatePlayer(player, source)
	if state ~= "Playing" or finishInProgress then return end
	if not alivePlayers[player] then return end
	if ItemManager.BlockElimination(player) then return end

	alivePlayers[player] = false
	aliveCountChanged:FireAllClients(getAliveCount(), #Players:GetPlayers())
	playerEliminated:FireClient(player, source or "추격자")
	announcement:FireAllClients(player.DisplayName .. " 탈락!", "붙잡혔습니다", 3)

	-- 혈흔 생성
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then spawnBloodPool(root.Position) end

	local aliveCount = getAliveCount()
	if aliveCount > 0 and initialParticipantCount > 1 then
		local ratio = aliveCount / initialParticipantCount
		currentSurvivorMultiplier = 1 + (1 - ratio) * GameConfig.ChaserMaxSpeedBonus
		updateChaserSpeed()
	end

	-- 자동 이동 없음: 리스폰 버튼 대기
	pendingRespawn[player] = true

	finishIfNoOneLeftInMaze()
end

local function escapePlayer(player)
	if state ~= "Playing" or finishInProgress then return end
	if not alivePlayers[player] or escapedPlayers[player] then return end

	escapedPlayers[player] = true
	alivePlayers[player] = false
	objectiveCount = getEscapedCount()

	ItemManager.ResetPlayer(player)
	teleportPlayer(player, "LobbySpawn", 10 + objectiveCount)
	aliveCountChanged:FireAllClients(getAliveCount(), #Players:GetPlayers())
	objectiveChanged:FireAllClients(objectiveCount, getObjectiveTotal())
	announcement:FireAllClients(player.DisplayName .. " 탈출!", "출구에 도착했습니다", 3)

	finishIfNoOneLeftInMaze()
end

local function chooseParticipants()
	table.clear(alivePlayers)
	table.clear(escapedPlayers)
	local participants = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if #participants < GameConfig.MaxPlayers then
			table.insert(participants, player)
			alivePlayers[player] = true
		end
	end
	initialParticipantCount = #participants
	return participants
end

local function resetPlayerMovement(player)
	local character = player.Character
	if character then
		restoreCharacterControl(character)
	end
end

local function runCountdown(seconds, token, label)
	for timeLeft = seconds, 1, -1 do
		if roundToken ~= token or finishInProgress then return false end
		timerChanged:FireAllClients(timeLeft, label)
		task.wait(1)
	end
	if roundToken == token and not finishInProgress then
		timerChanged:FireAllClients(0, label)
	end
	return roundToken == token and not finishInProgress
end

local function startRound()
	if state ~= "Waiting" or finishInProgress then return end
	if #Players:GetPlayers() < GameConfig.MinPlayers then return end

	autoStartQueued = false
	roundToken += 1
	local token = roundToken
	objectiveCount = 0
	table.clear(escapedPlayers)
	currentRushMultiplier = 1
	currentSurvivorMultiplier = 1
	table.clear(pendingRespawn)
	ItemManager.ResetRound()
	HazardController.Reset()
	clearBloodPools()

	local participants = chooseParticipants()
	if #participants == 0 then setState("Waiting"); return end

	for index, player in ipairs(participants) do
		resetPlayerMovement(player)
		teleportPlayer(player, "GameSpawn", index)
	end

	-- 난이도 적용
	local preset = GameConfig.DifficultyPresets[selectedDifficulty]
		or GameConfig.DifficultyPresets[GameConfig.DefaultDifficulty]

	ChaserController.Spawn(preset.ChaserCount)
	ChaserController.SetSpeedMultiplier(preset.ChaserSpeedMult)
	DroneController.Spawn(preset.DroneCount)
	KillerController.Spawn()
	setState("Preparing")

	local prepared = runCountdown(GameConfig.PreparationTime, token, "준비")
	if not prepared or roundToken ~= token then return end

	setState("Playing")
	ChaserController.Start()
	DroneController.Start()
	KillerController.Start()
	MapEventController.Start()

	for timeLeft = GameConfig.RoundTime, 0, -1 do
		if roundToken ~= token or finishInProgress then return end
		if getAliveCount() <= 0 then
			finishIfNoOneLeftInMaze()
			return
		end
		timerChanged:FireAllClients(timeLeft, "탈출")
		if timeLeft > 0 then task.wait(1) end
	end

	if getEscapedCount() > 0 then
		finishRound("SurvivorsWin", "일부가 탈출했습니다! 생존자 승리!")
	else
		finishRound("ChaserWin", "시간 초과! 킬러들이 출구를 봉쇄했습니다.")
	end
end

queueAutoStart = function()
	if autoStartQueued or state ~= "Waiting" or finishInProgress then return end
	autoStartQueued = true
	task.delay(GameConfig.AutoStartDelay, function()
		if state == "Waiting" and #Players:GetPlayers() >= GameConfig.MinPlayers then
			startRound()
		else
			autoStartQueued = false
		end
	end)
end

-- ── 난이도 선택 ───────────────────────────────────────────────────────────────

setDifficulty.OnServerEvent:Connect(function(player, difficulty)
	if state ~= "Waiting" then return end
	if not GameConfig.DifficultyPresets[difficulty] then return end
	selectedDifficulty = difficulty
	difficultyChanged:FireAllClients(selectedDifficulty)
	announcement:FireAllClients(
		player.DisplayName .. " → 난이도: " .. difficulty,
		"", 2.5
	)
end)

-- ── 손전등 사용 ───────────────────────────────────────────────────────────────

flashlightHit.OnServerEvent:Connect(function(player)
	if state ~= "Playing" or not isAlive(player) then return end
	if not ItemManager.HasFlashlight(player) then return end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local lookVec = root.CFrame.LookVector
	if ChaserController.CheckFlashlightHit(root.Position, lookVec) then
		ItemManager.UseFlashlight(player)
		ChaserController.Stun(GameConfig.FlashlightBlindDuration)
		announcement:FireAllClients("손전등!", "추격자가 눈이 멀었습니다", 3)
	end
end)

-- ── 리스폰 요청 ───────────────────────────────────────────────────────────────

respawnRequest.OnServerEvent:Connect(function(player)
	if not pendingRespawn[player] then return end
	pendingRespawn[player] = nil
	player:LoadCharacter()
end)

-- ── 로비 버튼 ─────────────────────────────────────────────────────────────────

local function connectStartButton()
	local lobbyFolder = Workspace:WaitForChild("Lobby")
	local button = lobbyFolder:WaitForChild("StartButton")
	local prompt = button:WaitForChild("StartPrompt")
	prompt.Triggered:Connect(function()
		if state == "Waiting" then startRound() end
	end)
end

-- ── 플레이어 이벤트 ───────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if state == "Waiting" or state == "Finished" or not isAlive(player) then
			teleportPlayer(player, "LobbySpawn", 1)
		end
	end)
	gameStateChanged:FireClient(player, state)
	timerChanged:FireClient(player, 0, "대기")
	aliveCountChanged:FireClient(player, getAliveCount(), #Players:GetPlayers())
	objectiveChanged:FireClient(player, getEscapedCount(), getObjectiveTotal())
	difficultyChanged:FireClient(player, selectedDifficulty)
	queueAutoStart()
end)

Players.PlayerRemoving:Connect(function(player)
	alivePlayers[player] = nil
	pendingRespawn[player] = nil
	ItemManager.ResetPlayer(player)
	aliveCountChanged:FireAllClients(getAliveCount(), #Players:GetPlayers())
	if state == "Playing" and getAliveCount() <= 0 then
		finishIfNoOneLeftInMaze()
	end
end)

-- ── 초기화 ────────────────────────────────────────────────────────────────────

ChaserController.Init({
	IsAlive         = isAlive,
	EliminatePlayer = eliminatePlayer,
	AlertDanger     = function(player, distance)
		dangerAlert:FireClient(player, distance)
	end,
	OnDetectionLevel = function(player, level)
		detectionLevel:FireClient(player, level)
	end,
	OnDetected = function(player)
		detectionAlert:FireClient(player)
		announcement:FireAllClients("⚠ 발각!", player.DisplayName .. " 발각됨", 3)
	end,
})

DroneController.Init({
	IsAlive         = isAlive,
	EliminatePlayer = eliminatePlayer,
})

KillerController.Init({
	IsAlive         = isAlive,
	EliminatePlayer = eliminatePlayer,

	OnRandomKillerSpawn = function(count)
		local token = roundToken
		announcement:FireAllClients(
			"⚠ 특수 임무 킬러 " .. count .. "명 출현!",
			"경계하세요! 어딘가에서 킬러가 활동 중입니다",
			5
		)
		-- 카운트다운 공지
		task.spawn(function()
			local remaining = GameConfig.RandomKillerActiveDuration
			while remaining > 0 and roundToken == token and state == "Playing" do
				local step = math.min(10, remaining)
				task.wait(step)
				remaining -= step
				if remaining > 0 and roundToken == token and state == "Playing" then
					announcement:FireAllClients(
						"특수 킬러 활동 중 — " .. remaining .. "초 남음",
						"",
						3
					)
				end
			end
		end)
	end,

	OnRandomKillerDespawn = function()
		if state ~= "Playing" then return end
		announcement:FireAllClients(
			"특수 임무 해제",
			"킬러들이 철수했습니다. 잠시 안전합니다",
			4
		)
	end,
})

HazardController.Init({
	GetState        = function() return state end,
	EliminatePlayer = eliminatePlayer,
})

ItemManager.Init({
	GetState = function() return state end,
	OnObjectiveCollected = function(player)
		if state ~= "Playing" or finishInProgress then return end
		announcement:FireAllClients(player.DisplayName .. " 단서 확보", "출구까지 계속 이동하세요", 2.5)
	end,
	OnEscapeReached = function(player)
		escapePlayer(player)
	end,
	StunChasers = function(duration)
		ChaserController.Stun(duration)
		DroneController.Stun(duration)
		KillerController.Stun(duration)
	end,
})

MapEventController.Init({
	GetState = function() return state end,
	SetChaserSpeed = function(multiplier)
		currentRushMultiplier = multiplier
		updateChaserSpeed()
	end,
})

task.spawn(connectStartButton)
task.delay(1, function()
	ItemManager.ResetRound()
	teleportAllToLobby()
	fireState()
	difficultyChanged:FireAllClients(selectedDifficulty)
	queueAutoStart()
end)
