local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local ChaserController = require(script.Parent:WaitForChild("ChaserController"))
local DroneController = require(script.Parent:WaitForChild("DroneController"))
local HazardController = require(script.Parent:WaitForChild("HazardController"))
local ItemManager = require(script.Parent:WaitForChild("ItemManager"))
local MapEventController = require(script.Parent:WaitForChild("MapEventController"))

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

local gameStateChanged = ensureRemoteEvent("GameStateChanged")
local timerChanged = ensureRemoteEvent("TimerChanged")
local aliveCountChanged = ensureRemoteEvent("AliveCountChanged")
local objectiveChanged = ensureRemoteEvent("ObjectiveChanged")
local roundResult = ensureRemoteEvent("RoundResult")
local playerEliminated = ensureRemoteEvent("PlayerEliminated")
local dangerAlert = ensureRemoteEvent("DangerAlert")
local announcement = ensureRemoteEvent("Announcement")

local state = "Waiting"
local alivePlayers = {}
local autoStartQueued = false
local roundToken = 0
local finishInProgress = false
local energyCoreCount = 0
local initialParticipantCount = 0
local currentRushMultiplier = 1
local currentSurvivorMultiplier = 1
local queueAutoStart

local spawnsFolder = Workspace:WaitForChild("Spawns")
local lobbySpawn = spawnsFolder:WaitForChild("LobbySpawn")
local gameSpawn = spawnsFolder:WaitForChild("GameSpawn")
spawnsFolder:WaitForChild("ChaserSpawn")

local function getAliveCount()
	local count = 0
	for _, alive in pairs(alivePlayers) do
		if alive then
			count += 1
		end
	end
	return count
end

local function fireState()
	gameStateChanged:FireAllClients(state)
	aliveCountChanged:FireAllClients(getAliveCount(), #Players:GetPlayers())
	objectiveChanged:FireAllClients(energyCoreCount, GameConfig.RequiredEnergyCores)
end

local function setState(nextState)
	state = nextState
	fireState()
end

local function teleportPlayer(player, targetPart, offsetIndex)
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end

	local index = (offsetIndex or 1) - 1
	local offset = Vector3.new(index % 5 * 6, 5, math.floor(index / 5) * 6)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.new(targetPart.Position + offset)
end

local function teleportAllToLobby()
	for index, player in ipairs(Players:GetPlayers()) do
		ItemManager.ResetPlayer(player)
		teleportPlayer(player, lobbySpawn, index)
	end
end

local function isAlive(player)
	return alivePlayers[player] == true
end

local function stopRoundActors()
	ChaserController.Despawn()
	DroneController.Despawn()
	MapEventController.Stop()
end

local function updateChaserSpeed()
	ChaserController.SetSpeedMultiplier(currentRushMultiplier * currentSurvivorMultiplier)
end

local function finishRound(resultKey, resultText)
	if finishInProgress then
		return
	end

	finishInProgress = true
	roundToken += 1
	setState("Finished")
	stopRoundActors()
	currentRushMultiplier = 1
	currentSurvivorMultiplier = 1
	roundResult:FireAllClients(resultKey, resultText)
	timerChanged:FireAllClients(0, "완료")

	task.wait(GameConfig.ResultDisplayTime)
	table.clear(alivePlayers)
	energyCoreCount = 0
	ItemManager.ResetRound()
	teleportAllToLobby()
	setState("Waiting")
	roundResult:FireAllClients("", "")
	finishInProgress = false

	if queueAutoStart then
		queueAutoStart()
	end
end

local function eliminatePlayer(player, source)
	if state ~= "Playing" or finishInProgress then
		return
	end

	if not alivePlayers[player] then
		return
	end

	if ItemManager.BlockElimination(player) then
		return
	end

	alivePlayers[player] = false
	aliveCountChanged:FireAllClients(getAliveCount(), #Players:GetPlayers())
	playerEliminated:FireClient(player, source or "추격자")
	announcement:FireAllClients(player.DisplayName .. " 탈락!", "붙잡혔습니다", 3)

	local aliveCount = getAliveCount()
	if aliveCount > 0 and initialParticipantCount > 1 then
		local ratio = aliveCount / initialParticipantCount
		currentSurvivorMultiplier = 1 + (1 - ratio) * GameConfig.ChaserMaxSpeedBonus
		updateChaserSpeed()
	end

	local capturedToken = roundToken
	task.delay(GameConfig.EliminationDisplayTime, function()
		if roundToken == capturedToken then
			ItemManager.ResetPlayer(player)
			teleportPlayer(player, lobbySpawn, 1)
		end
	end)

	if getAliveCount() <= 0 then
		finishRound("ChaserWin", "추격자 승리!")
	end
end

local function chooseParticipants()
	table.clear(alivePlayers)

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
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
	end
end

local function runCountdown(seconds, token, label)
	for timeLeft = seconds, 1, -1 do
		if roundToken ~= token or finishInProgress then
			return false
		end

		timerChanged:FireAllClients(timeLeft, label)
		task.wait(1)
	end

	if roundToken == token and not finishInProgress then
		timerChanged:FireAllClients(0, label)
	end

	return roundToken == token and not finishInProgress
end

local function startRound()
	if state ~= "Waiting" or finishInProgress then
		return
	end

	if #Players:GetPlayers() < GameConfig.MinPlayers then
		return
	end

	autoStartQueued = false
	roundToken += 1
	local token = roundToken
	energyCoreCount = 0
	currentRushMultiplier = 1
	currentSurvivorMultiplier = 1
	ItemManager.ResetRound()
	HazardController.Reset()

	local participants = chooseParticipants()
	if #participants == 0 then
		setState("Waiting")
		return
	end

	for index, player in ipairs(participants) do
		resetPlayerMovement(player)
		teleportPlayer(player, gameSpawn, index)
	end

	ChaserController.Spawn()
	DroneController.Spawn()
	setState("Preparing")

	local prepared = runCountdown(GameConfig.PreparationTime, token, "준비")
	if not prepared or roundToken ~= token then
		return
	end

	setState("Playing")
	ChaserController.Start()
	DroneController.Start()
	MapEventController.Start()

	for timeLeft = GameConfig.RoundTime, 0, -1 do
		if roundToken ~= token or finishInProgress then
			return
		end

		if getAliveCount() <= 0 then
			finishRound("ChaserWin", "추격자 승리!")
			return
		end

		timerChanged:FireAllClients(timeLeft, "생존")
		if timeLeft > 0 then
			task.wait(1)
		end
	end

	if getAliveCount() > 0 then
		finishRound("SurvivorsWin", "생존자 승리!")
	else
		finishRound("ChaserWin", "추격자 승리!")
	end
end

queueAutoStart = function()
	if autoStartQueued or state ~= "Waiting" or finishInProgress then
		return
	end

	autoStartQueued = true
	task.delay(GameConfig.AutoStartDelay, function()
		if state == "Waiting" and #Players:GetPlayers() >= GameConfig.MinPlayers then
			startRound()
		else
			autoStartQueued = false
		end
	end)
end

local function connectStartButton()
	local lobbyFolder = Workspace:WaitForChild("Lobby")
	local button = lobbyFolder:WaitForChild("StartButton")
	local prompt = button:WaitForChild("StartPrompt")

	prompt.Triggered:Connect(function()
		if state == "Waiting" then
			startRound()
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if state == "Waiting" or state == "Finished" or not isAlive(player) then
			teleportPlayer(player, lobbySpawn, 1)
		end
	end)

	gameStateChanged:FireClient(player, state)
	timerChanged:FireClient(player, 0, "대기")
	aliveCountChanged:FireClient(player, getAliveCount(), #Players:GetPlayers())
	objectiveChanged:FireClient(player, energyCoreCount, GameConfig.RequiredEnergyCores)

	queueAutoStart()
end)

Players.PlayerRemoving:Connect(function(player)
	alivePlayers[player] = nil
	ItemManager.ResetPlayer(player)
	aliveCountChanged:FireAllClients(getAliveCount(), #Players:GetPlayers())
	if state == "Playing" and getAliveCount() <= 0 then
		finishRound("ChaserWin", "추격자 승리!")
	end
end)

ChaserController.Init({
	IsAlive = isAlive,
	EliminatePlayer = eliminatePlayer,
	AlertDanger = function(player, distance)
		dangerAlert:FireClient(player, distance)
	end,
})

DroneController.Init({
	IsAlive = isAlive,
	EliminatePlayer = eliminatePlayer,
})

HazardController.Init({
	GetState = function()
		return state
	end,
	EliminatePlayer = eliminatePlayer,
})

ItemManager.Init({
	GetState = function()
		return state
	end,
	OnObjectiveCollected = function(player)
		if state ~= "Playing" or finishInProgress then
			return
		end

		energyCoreCount += 1
		objectiveChanged:FireAllClients(energyCoreCount, GameConfig.RequiredEnergyCores)
		announcement:FireAllClients(
			player.DisplayName .. " 코어 수집!",
			"코어 " .. energyCoreCount .. "/" .. GameConfig.RequiredEnergyCores,
			3
		)

		if energyCoreCount >= GameConfig.RequiredEnergyCores then
			finishRound("SurvivorsWin", "에너지 복구! 생존자 승리!")
		end
	end,
	StunChasers = function(duration)
		ChaserController.Stun(duration)
		DroneController.Stun(duration)
	end,
})

MapEventController.Init({
	GetState = function()
		return state
	end,
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
	queueAutoStart()
end)
