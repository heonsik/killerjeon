local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local ChaserController = {}

local chasers = {}
local heartbeatConnection
local active = false

local isAliveCallback
local eliminateCallback
local alertDangerCallback
local onDetectionLevelCallback
local onDetectedCallback

local speedMultiplier = 1
local stunnedUntil = 0

local sharedParams = RaycastParams.new()
sharedParams.FilterType = Enum.RaycastFilterType.Exclude
local paramsAge = 0

local function refreshParams()
	local exclude = {}
	for _, c in ipairs(chasers) do
		if c.model then table.insert(exclude, c.model) end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(exclude, player.Character) end
	end
	local items = Workspace:FindFirstChild("Items")
	if items then table.insert(exclude, items) end
	local effects = Workspace:FindFirstChild("Effects")
	if effects then table.insert(exclude, effects) end
	sharedParams.FilterDescendantsInstances = exclude
end

local function rotateXZ(direction, angleDegrees)
	local r = math.rad(angleDegrees)
	return Vector3.new(
		direction.X * math.cos(r) - direction.Z * math.sin(r),
		0,
		direction.X * math.sin(r) + direction.Z * math.cos(r)
	)
end

local CHASER_AGENT = {
	AgentRadius  = 2.5,
	AgentHeight  = 7,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 4,
}

local function refreshChaserPath(chaser, targetPos)
	if chaser.pathBusy then return end
	chaser.pathBusy = true
	chaser.pathAge  = os.clock()
	task.spawn(function()
		local path = PathfindingService:CreatePath(CHASER_AGENT)
		local ok = pcall(function()
			path:ComputeAsync(chaser.root.Position, targetPos)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local wps = {}
			for _, wp in ipairs(path:GetWaypoints()) do
				table.insert(wps, wp.Position)
			end
			chaser.pathWaypoints = wps
			chaser.pathWpIdx     = math.min(2, #wps)
		else
			chaser.pathWaypoints = nil
		end
		chaser.pathBusy = false
	end)
end

local function findSteerDirection(chaser, targetPosition)
	if not chaser.root then return nil end
	local from = chaser.root.Position + Vector3.new(0, 2, 0)
	local offset = Vector3.new(targetPosition.X - from.X, 0, targetPosition.Z - from.Z)
	if offset.Magnitude < 0.1 then return Vector3.zero end
	local baseDir = offset.Unit
	local dist = GameConfig.ChaserSteerCheckDist
	for _, angle in ipairs({ 0, 22, -22, 45, -45, 70, -70, 100, -100, 130, -130, 160, -160 }) do
		local dir = rotateXZ(baseDir, angle)
		if not Workspace:Raycast(from, dir * dist, sharedParams) then
			return dir
		end
	end
	return baseDir
end

local function getCharacterRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getNearestTarget(chaser)
	if not chaser.root then return nil, nil, nil end
	local nearestPlayer, nearestRoot, nearestDecoy = nil, nil, nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if isAliveCallback and isAliveCallback(player) then
			local root = getCharacterRoot(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local distance = (root.Position - chaser.root.Position).Magnitude
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
				local distance = (decoy.Position - chaser.root.Position).Magnitude
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

local function updateDetection(chaser, deltaTime)
	for _, player in ipairs(Players:GetPlayers()) do
		if not (isAliveCallback and isAliveCallback(player)) then
			chaser.detection[player] = 0
			continue
		end
		local root = getCharacterRoot(player)
		if not root then
			chaser.detection[player] = 0
			continue
		end

		local toPlayer = root.Position - chaser.root.Position
		local dist = toPlayer.Magnitude
		local prevLevel = chaser.detection[player] or 0
		local inSight = false

		if dist <= GameConfig.DetectionRange then
			local lookVec = chaser.root.CFrame.LookVector
			local flatLook = Vector3.new(lookVec.X, 0, lookVec.Z)
			local flatToPlayer = Vector3.new(toPlayer.X, 0, toPlayer.Z)
			if flatLook.Magnitude > 0.01 and flatToPlayer.Magnitude > 0.01 then
				local dot = flatLook.Unit:Dot(flatToPlayer.Unit)
				local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
				if angle <= GameConfig.DetectionFOVAngle then
					local hitResult = Workspace:Raycast(
						chaser.root.Position + Vector3.new(0, 3, 0),
						toPlayer.Unit * dist,
						sharedParams
					)
					inSight = (hitResult == nil)
				end
			end
		end

		if inSight then
			local closeFactor = 1 - math.clamp(dist / GameConfig.DetectionRange, 0, 1)
			local rate = GameConfig.DetectionBuildRate * (0.4 + closeFactor * 0.6)
			chaser.detection[player] = math.min(1, prevLevel + rate * deltaTime)
		else
			chaser.detection[player] = math.max(0, prevLevel - GameConfig.DetectionDecayRate * deltaTime)
		end

		local level = chaser.detection[player]
		if level >= 1.0 then
			local now = os.clock()
			if not chaser.alertUntil[player] or now >= chaser.alertUntil[player] then
				chaser.alertUntil[player] = now + GameConfig.DetectionAlertDuration
				chaser.detection[player] = 0.55
				chaser.speedBoostUntil = math.max(chaser.speedBoostUntil, now + GameConfig.DetectionAlertDuration)
				if onDetectedCallback then
					onDetectedCallback(player)
				end
			end
		end
	end
end

local function getChaserSpeed(chaser)
	local boost = (os.clock() < chaser.speedBoostUntil) and GameConfig.DetectionAlertSpeedBonus or 0
	return GameConfig.ChaserWalkSpeed * speedMultiplier * (1 + boost)
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

	attachPart("Head",       Vector3.new(3.2, 3.2, 3.2), CFrame.new(0, 4.9, 0),       Color3.fromRGB(255, 187, 136), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	attachPart("Hair",       Vector3.new(3.4, 1.1, 3.4), CFrame.new(0, 6.25, -0.15),  Color3.fromRGB(38, 26, 28),   Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	attachPart("LeftArm",    Vector3.new(1.35, 5.4, 1.35), CFrame.new(-3.0, 0.0, 0),  Color3.fromRGB(168, 43, 52))
	attachPart("RightArm",   Vector3.new(1.35, 5.4, 1.35), CFrame.new( 3.0, 0.0, 0),  Color3.fromRGB(168, 43, 52))
	attachPart("LeftLeg",    Vector3.new(1.45, 4.8, 1.45), CFrame.new(-1.05, -5.15, 0), Color3.fromRGB(47, 55, 74))
	attachPart("RightLeg",   Vector3.new(1.45, 4.8, 1.45), CFrame.new( 1.05, -5.15, 0), Color3.fromRGB(47, 55, 74))
	attachPart("LeftEye",    Vector3.new(0.45, 0.45, 0.22), CFrame.new(-0.55, 5.25, -1.5), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	attachPart("RightEye",   Vector3.new(0.45, 0.45, 0.22), CFrame.new( 0.55, 5.25, -1.5), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	attachPart("Mouth",      Vector3.new(1.2, 0.22, 0.16),  CFrame.new(0, 4.45, -1.62), Color3.fromRGB(25, 18, 22))
	attachPart("ChestGlow",  Vector3.new(2.6, 0.35, 0.18),  CFrame.new(0, 1.2, -1.45),  Color3.fromRGB(255, 210, 74), Enum.Material.Neon)

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
	local rw = Instance.new("WeldConstraint")
	rw.Part0 = root; rw.Part1 = ring; rw.Parent = ring

	local face = Instance.new("BillboardGui")
	face.Name = "Face"
	face.Size = UDim2.fromOffset(150, 58)
	face.StudsOffset = Vector3.new(0, 8, 0)
	face.AlwaysOnTop = true
	face.Parent = root
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "추격자"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.Parent = face

	local light = Instance.new("PointLight")
	light.Brightness = 2.8
	light.Range = 28
	light.Color = Color3.fromRGB(255, 85, 85)
	light.Parent = root

	model.PrimaryPart = root
	model.Parent = Workspace:WaitForChild("Map")
	return model, root
end

-- ── public ────────────────────────────────────────────────────────────────

function ChaserController.Init(options)
	isAliveCallback          = options.IsAlive
	eliminateCallback        = options.EliminatePlayer
	alertDangerCallback      = options.AlertDanger
	onDetectionLevelCallback = options.OnDetectionLevel
	onDetectedCallback       = options.OnDetected
end

function ChaserController.Spawn(count)
	ChaserController.Despawn()
	count = count or 1
	local spawnPart = Workspace:WaitForChild("Spawns"):WaitForChild("ChaserSpawn")
	for i = 1, count do
		local offset = Vector3.new((i - 1) * 9, 4, 0)
		local model, root = createChaserModel(spawnPart.Position + offset)
		table.insert(chasers, {
			model             = model,
			root              = root,
			detection         = {},
			alertUntil        = {},
			lastTouchByPlayer = {},
			speedBoostUntil   = 0,
			dangerTimer       = 0,
			pathWaypoints     = nil,
			pathWpIdx         = 1,
			pathAge           = 0,
			pathBusy          = false,
		})
	end
	stunnedUntil = 0
	speedMultiplier = 1
	refreshParams()
end

local detectionFireTimer = 0

function ChaserController.Start()
	if heartbeatConnection then heartbeatConnection:Disconnect() end
	active = true
	paramsAge = 0
	detectionFireTimer = 0

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not active then return end
		if os.clock() < stunnedUntil then return end

		paramsAge += deltaTime
		if paramsAge >= 1 then
			paramsAge = 0
			refreshParams()
		end

		for _, chaser in ipairs(chasers) do
			if not chaser.root then continue end

			updateDetection(chaser, deltaTime)

			local targetPlayer, targetRoot, targetDecoy = getNearestTarget(chaser)
			if not targetRoot then continue end

			local offset     = targetRoot.Position - chaser.root.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			local distance   = flatOffset.Magnitude
			local speed      = getChaserSpeed(chaser)
			local now2       = os.clock()

			-- 경로가 없거나 1.2초 경과 시 재계산
			if not chaser.pathWaypoints or now2 - chaser.pathAge > 1.2 then
				refreshChaserPath(chaser, targetRoot.Position)
			end

			local wp = chaser.pathWaypoints and chaser.pathWaypoints[chaser.pathWpIdx]
			if wp then
				local wpFlat = Vector3.new(wp.X - chaser.root.Position.X, 0, wp.Z - chaser.root.Position.Z)
				local wpDist = wpFlat.Magnitude
				if wpDist < 2 then
					chaser.pathWpIdx += 1
					wp = chaser.pathWaypoints[chaser.pathWpIdx]
					if wp then
						wpFlat = Vector3.new(wp.X - chaser.root.Position.X, 0, wp.Z - chaser.root.Position.Z)
						wpDist = wpFlat.Magnitude
					end
				end
				if wp and wpDist > 0.1 then
					local step    = math.min(speed * deltaTime, wpDist)
					local nextPos = chaser.root.Position + wpFlat.Unit * step
					nextPos = Vector3.new(nextPos.X, chaser.root.Position.Y, nextPos.Z)
					chaser.root.CFrame = CFrame.lookAt(
						nextPos,
						Vector3.new(targetRoot.Position.X, nextPos.Y, targetRoot.Position.Z)
					)
				end
			else
				-- 경로 계산 중이거나 실패 시: 기존 스티어링 폴백
				local moveDir = findSteerDirection(chaser, targetRoot.Position)
				if moveDir and moveDir.Magnitude > 0.1 then
					local step    = math.min(speed * deltaTime, distance)
					local nextPos = chaser.root.Position + moveDir * step
					nextPos = Vector3.new(nextPos.X, chaser.root.Position.Y, nextPos.Z)
					chaser.root.CFrame = CFrame.lookAt(
						nextPos,
						Vector3.new(targetRoot.Position.X, nextPos.Y, targetRoot.Position.Z)
					)
				end
			end

			if targetDecoy and distance <= 6 then
				targetDecoy:Destroy()
				stunnedUntil = os.clock() + 1.4
				continue
			end

			if targetPlayer and distance <= 5.5 then
				local now = os.clock()
				local lastTouch = chaser.lastTouchByPlayer[targetPlayer] or 0
				if now - lastTouch >= GameConfig.ChaserTouchCooldown then
					chaser.lastTouchByPlayer[targetPlayer] = now
					if eliminateCallback then
						eliminateCallback(targetPlayer, "추격자")
					end
				end
			end

			chaser.dangerTimer += deltaTime
			if chaser.dangerTimer >= 0.4 then
				chaser.dangerTimer = 0
				if targetPlayer and distance < GameConfig.ChaserDangerRadius and alertDangerCallback then
					alertDangerCallback(targetPlayer, distance)
				end
			end
		end

		-- 발각 수치 전송 (0.25초마다)
		detectionFireTimer += deltaTime
		if detectionFireTimer >= 0.25 and onDetectionLevelCallback then
			detectionFireTimer = 0
			local maxLevels = {}
			for _, chaser in ipairs(chasers) do
				for player, level in pairs(chaser.detection) do
					maxLevels[player] = math.max(maxLevels[player] or 0, level)
				end
			end
			for player, level in pairs(maxLevels) do
				onDetectionLevelCallback(player, level)
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
	for _, chaser in ipairs(chasers) do
		table.clear(chaser.detection)
		table.clear(chaser.alertUntil)
		chaser.speedBoostUntil = 0
	end
end

function ChaserController.SetSpeedMultiplier(multiplier)
	speedMultiplier = multiplier or 1
end

-- 손전등 히트 여부 서버 검증
function ChaserController.CheckFlashlightHit(fromPosition, lookVector)
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
	if flatLook.Magnitude < 0.01 then return false end
	flatLook = flatLook.Unit
	for _, chaser in ipairs(chasers) do
		if chaser.root then
			local toChaser = chaser.root.Position - fromPosition
			local dist = toChaser.Magnitude
			if dist <= GameConfig.FlashlightRange then
				local flatTo = Vector3.new(toChaser.X, 0, toChaser.Z)
				if flatTo.Magnitude > 0.01 then
					local dot = flatLook:Dot(flatTo.Unit)
					local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
					if angle <= GameConfig.FlashlightFOVAngle then
						return true
					end
				end
			end
		end
	end
	return false
end

function ChaserController.Despawn()
	ChaserController.Stop()
	speedMultiplier = 1
	stunnedUntil = 0
	for _, chaser in ipairs(chasers) do
		if chaser.model then chaser.model:Destroy() end
	end
	table.clear(chasers)
end

return ChaserController
