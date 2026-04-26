local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local ChaserController = {}

local chaserModel
local chaserRoot
local heartbeatConnection
local active = false
local isAliveCallback
local eliminateCallback
local alertDangerCallback
local lastTouchByPlayer = {}
local speedMultiplier = 1
local stunnedUntil = 0
local dangerCheckTimer = 0
local steerParamsAge = 0

local steerParams = RaycastParams.new()
steerParams.FilterType = Enum.RaycastFilterType.Exclude

local function refreshSteerParams()
	local exclude = {}
	if chaserModel then
		table.insert(exclude, chaserModel)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end

	local itemsFolder = Workspace:FindFirstChild("Items")
	if itemsFolder then
		table.insert(exclude, itemsFolder)
	end

	local effectsFolder = Workspace:FindFirstChild("Effects")
	if effectsFolder then
		table.insert(exclude, effectsFolder)
	end

	steerParams.FilterDescendantsInstances = exclude
end

local function rotateXZ(direction, angleDegrees)
	local radians = math.rad(angleDegrees)
	local cos = math.cos(radians)
	local sin = math.sin(radians)
	return Vector3.new(direction.X * cos - direction.Z * sin, 0, direction.X * sin + direction.Z * cos)
end

local function findSteerDirection(targetPosition)
	if not chaserRoot then
		return nil
	end

	local from = chaserRoot.Position + Vector3.new(0, 2, 0)
	local offset = Vector3.new(targetPosition.X - from.X, 0, targetPosition.Z - from.Z)
	if offset.Magnitude < 0.1 then
		return Vector3.zero
	end

	local baseDirection = offset.Unit
	local checkDistance = GameConfig.ChaserSteerCheckDist
	local testAngles = { 0, 22, -22, 45, -45, 70, -70, 100, -100, 130, -130, 160, -160 }

	for _, angle in ipairs(testAngles) do
		local direction = rotateXZ(baseDirection, angle)
		local hit = Workspace:Raycast(from, direction * checkDistance, steerParams)
		if not hit then
			return direction
		end
	end

	return baseDirection
end

local function getCharacterRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getNearestTarget()
	if not chaserRoot then
		return nil, nil, nil
	end

	local nearestPlayer = nil
	local nearestRoot = nil
	local nearestDecoy = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if isAliveCallback and isAliveCallback(player) then
			local root = getCharacterRoot(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local distance = (root.Position - chaserRoot.Position).Magnitude
				if distance < nearestDistance then
					nearestPlayer = player
					nearestRoot = root
					nearestDecoy = nil
					nearestDistance = distance
				end
			end
		end
	end

	local effectsFolder = Workspace:FindFirstChild("Effects")
	local decoysFolder = effectsFolder and effectsFolder:FindFirstChild("Decoys")
	if decoysFolder then
		for _, decoy in ipairs(decoysFolder:GetChildren()) do
			if decoy:IsA("BasePart") then
				local distance = (decoy.Position - chaserRoot.Position).Magnitude
				if distance < nearestDistance then
					nearestPlayer = nil
					nearestRoot = decoy
					nearestDecoy = decoy
					nearestDistance = distance
				end
			end
		end
	end

	return nearestPlayer, nearestRoot, nearestDecoy
end

local function createChaserModel(position)
	local model = Instance.new("Model")
	model.Name = "Chaser"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(4.2, 6.2, 2.7)
	root.CFrame = CFrame.new(position)
	root.Color = Color3.fromRGB(226, 72, 62)
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model

	local function attachPart(name, size, offset, color, material, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = root.CFrame * offset
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Shape = shape or Enum.PartType.Block
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part

		return part
	end

	attachPart("Head", Vector3.new(3.2, 3.2, 3.2), CFrame.new(0, 4.9, 0), Color3.fromRGB(255, 187, 136), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	attachPart("Hair", Vector3.new(3.4, 1.1, 3.4), CFrame.new(0, 6.25, -0.15), Color3.fromRGB(38, 26, 28), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	attachPart("LeftArm", Vector3.new(1.35, 5.4, 1.35), CFrame.new(-3.0, 0.0, 0), Color3.fromRGB(168, 43, 52))
	attachPart("RightArm", Vector3.new(1.35, 5.4, 1.35), CFrame.new(3.0, 0.0, 0), Color3.fromRGB(168, 43, 52))
	attachPart("LeftLeg", Vector3.new(1.45, 4.8, 1.45), CFrame.new(-1.05, -5.15, 0), Color3.fromRGB(47, 55, 74))
	attachPart("RightLeg", Vector3.new(1.45, 4.8, 1.45), CFrame.new(1.05, -5.15, 0), Color3.fromRGB(47, 55, 74))
	attachPart("LeftEye", Vector3.new(0.45, 0.45, 0.22), CFrame.new(-0.55, 5.25, -1.5), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	attachPart("RightEye", Vector3.new(0.45, 0.45, 0.22), CFrame.new(0.55, 5.25, -1.5), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	attachPart("Mouth", Vector3.new(1.2, 0.22, 0.16), CFrame.new(0, 4.45, -1.62), Color3.fromRGB(25, 18, 22), Enum.Material.SmoothPlastic)
	attachPart("ChestGlow", Vector3.new(2.6, 0.35, 0.18), CFrame.new(0, 1.2, -1.45), Color3.fromRGB(255, 210, 74), Enum.Material.Neon)

	local ring = Instance.new("Part")
	ring.Name = "WarningRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.35, 13, 13)
	ring.CFrame = root.CFrame * CFrame.new(0, -6.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(255, 210, 74)
	ring.Material = Enum.Material.Neon
	ring.Anchored = false
	ring.CanCollide = false
	ring.Massless = true
	ring.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = ring
	weld.Parent = ring

	local face = Instance.new("BillboardGui")
	face.Name = "Face"
	face.Size = UDim2.fromOffset(150, 58)
	face.StudsOffset = Vector3.new(0, 8, 0)
	face.AlwaysOnTop = true
	face.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "FaceLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "추격자"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = face

	local light = Instance.new("PointLight")
	light.Brightness = 2.8
	light.Range = 28
	light.Color = Color3.fromRGB(255, 85, 85)
	light.Parent = root

	model.PrimaryPart = root
	model.Parent = Workspace:WaitForChild("Map")

	return model, root
end

function ChaserController.Init(options)
	isAliveCallback = options.IsAlive
	eliminateCallback = options.EliminatePlayer
	alertDangerCallback = options.AlertDanger
end

function ChaserController.Spawn()
	ChaserController.Despawn()

	local spawnPart = Workspace:WaitForChild("Spawns"):WaitForChild("ChaserSpawn")
	chaserModel, chaserRoot = createChaserModel(spawnPart.Position + Vector3.new(0, 4, 0))
	lastTouchByPlayer = {}
	speedMultiplier = 1
	stunnedUntil = 0
	refreshSteerParams()
end

function ChaserController.Start()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
	end

	active = true
	steerParamsAge = 0
	dangerCheckTimer = 0

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not active or not chaserRoot then
			return
		end

		if os.clock() < stunnedUntil then
			return
		end

		steerParamsAge += deltaTime
		if steerParamsAge >= 1 then
			steerParamsAge = 0
			refreshSteerParams()
		end

		local targetPlayer, targetRoot, targetDecoy = getNearestTarget()
		if not targetRoot then
			return
		end

		local offset = targetRoot.Position - chaserRoot.Position
		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		local distance = flatOffset.Magnitude
		local moveDirection = findSteerDirection(targetRoot.Position)

		if moveDirection and moveDirection.Magnitude > 0.1 then
			local step = math.min(GameConfig.ChaserWalkSpeed * speedMultiplier * deltaTime, distance)
			local nextPosition = chaserRoot.Position + moveDirection * step
			nextPosition = Vector3.new(nextPosition.X, chaserRoot.Position.Y, nextPosition.Z)
			chaserRoot.CFrame = CFrame.lookAt(nextPosition, Vector3.new(targetRoot.Position.X, nextPosition.Y, targetRoot.Position.Z))
		end

		if targetDecoy and distance <= 6 then
			targetDecoy:Destroy()
			stunnedUntil = os.clock() + 1.4
			return
		end

		if targetPlayer and distance <= 5.5 then
			local now = os.clock()
			local lastTouch = lastTouchByPlayer[targetPlayer] or 0
			if now - lastTouch >= GameConfig.ChaserTouchCooldown then
				lastTouchByPlayer[targetPlayer] = now
				if eliminateCallback then
					eliminateCallback(targetPlayer, "추격자")
				end
			end
		end

		dangerCheckTimer += deltaTime
		if dangerCheckTimer >= 0.4 then
			dangerCheckTimer = 0
			if targetPlayer and distance < GameConfig.ChaserDangerRadius and alertDangerCallback then
				alertDangerCallback(targetPlayer, distance)
			end
		end
	end)
end

function ChaserController.Stop()
	active = false
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

function ChaserController.Stun(duration)
	stunnedUntil = math.max(stunnedUntil, os.clock() + duration)
end

function ChaserController.SetSpeedMultiplier(multiplier)
	speedMultiplier = multiplier or 1
end

function ChaserController.Despawn()
	ChaserController.Stop()
	speedMultiplier = 1
	stunnedUntil = 0
	if chaserModel then
		chaserModel:Destroy()
		chaserModel = nil
		chaserRoot = nil
	end
end

return ChaserController
