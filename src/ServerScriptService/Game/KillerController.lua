local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local KillerController = {}

local killers       = {}
local randomKillers = {}
local heartbeatConnection
local active = false
local isAliveCallback
local eliminateCallback
local onRandomKillerSpawn
local onRandomKillerDespawn
local stunnedUntil  = 0
local lastHitByPlayer = {}
local eventToken    = 0

-- ── Config ───────────────────────────────────────────────────────────────────

local KILLER_CFG = {
	Axe      = { walkSpeed = 20, attackRange = 10, throwRange    = 34, attackCooldown = 1.8,
	             bodyColor = Color3.fromRGB(80, 50, 30),  weaponColor = Color3.fromRGB(160, 140, 120) },
	Chainsaw = { walkSpeed = 16, aoeRadius   = 10,                     attackCooldown = 0.9,
	             bodyColor = Color3.fromRGB(60, 60, 60),  weaponColor = Color3.fromRGB(200, 200, 200) },
	Knife    = { walkSpeed = 28, attackRange =  6,                     attackCooldown = 0.7,
	             bodyColor = Color3.fromRGB(30, 30, 50),  weaponColor = Color3.fromRGB(180, 200, 220) },
	Scythe   = { walkSpeed = 18, attackRange = 13, arcAngle      = 150, attackCooldown = 1.4,
	             bodyColor = Color3.fromRGB(40, 25, 60),  weaponColor = Color3.fromRGB(90, 80, 120)  },
	Hammer   = { walkSpeed = 15, stunRadius  = 15, stunDuration  = 2.0, attackCooldown = 2.2,
	             bodyColor = Color3.fromRGB(55, 45, 35),  weaponColor = Color3.fromRGB(120, 100, 80) },
}

local FIXED_SPAWN_DATA = {
	{ position = Vector3.new(-600, 5, -600), killerType = "Axe",      territory = 330, alertRadius = 38 },
	{ position = Vector3.new( 600, 5, -600), killerType = "Chainsaw", territory = 330, alertRadius = 38 },
	{ position = Vector3.new(-600, 5,  600), killerType = "Knife",    territory = 290, alertRadius = 35 },
	{ position = Vector3.new( 600, 5,  600), killerType = "Scythe",   territory = 330, alertRadius = 38 },
	{ position = Vector3.new(   0, 5,    0), killerType = "Hammer",   territory = 270, alertRadius = 36 },
}

local RANDOM_SPAWN_ZONES = {
	Vector3.new(-350, 5, -350), Vector3.new( 350, 5, -350),
	Vector3.new(-350, 5,  350), Vector3.new( 350, 5,  350),
	Vector3.new(   0, 5, -500), Vector3.new(   0, 5,  500),
	Vector3.new(-500, 5,    0), Vector3.new( 500, 5,    0),
	Vector3.new(-200, 5, -700), Vector3.new( 200, 5,  700),
	Vector3.new(-700, 5, -200), Vector3.new( 700, 5,  200),
}

local KILLER_TYPES = { "Axe", "Chainsaw", "Knife", "Scythe", "Hammer" }

-- ── Pathfinding ──────────────────────────────────────────────────────────────

local KILLER_AGENT = {
	AgentRadius   = 2.5,
	AgentHeight   = 7,
	AgentCanJump  = false,
	AgentCanClimb = false,
	WaypointSpacing = 4,
}

local function refreshPath(killer, targetPos)
	if killer.pathBusy then return end
	killer.pathBusy = true
	killer.pathAge  = os.clock()
	task.spawn(function()
		local path = PathfindingService:CreatePath(KILLER_AGENT)
		local ok = pcall(function()
			path:ComputeAsync(killer.Body.Position, targetPos)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			local wps = {}
			for _, wp in ipairs(path:GetWaypoints()) do
				table.insert(wps, wp.Position)
			end
			killer.pathWaypoints = wps
			killer.pathWpIdx     = math.min(2, #wps)
		else
			killer.pathWaypoints = nil
		end
		killer.pathBusy = false
	end)
end

-- ── Model builder ────────────────────────────────────────────────────────────

local function getPlayerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function attachPart(model, body, name, size, offset, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = body.CFrame * offset
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addWeaponLight(part, color)
	local light = Instance.new("PointLight")
	light.Brightness = 0.9
	light.Range = 13
	light.Color = color
	light.Parent = part
end

local function buildModel(label, spawnData)
	local cfg = KILLER_CFG[spawnData.killerType]
	local position = spawnData.position

	local model = Instance.new("Model")
	model.Name = "Killer_" .. label

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3.2, 4.8, 2.0)
	body.CFrame = CFrame.new(position)
	body.Color = cfg.bodyColor
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	attachPart(model, body, "Head",     Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 3.6, 0),     Color3.fromRGB(200, 175, 150), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	attachPart(model, body, "LeftArm",  Vector3.new(1.0, 4.0, 1.0), CFrame.new(-2.1, -0.1, 0), cfg.bodyColor)
	attachPart(model, body, "RightArm", Vector3.new(1.0, 4.0, 1.0), CFrame.new( 2.1, -0.1, 0), cfg.bodyColor)
	attachPart(model, body, "LeftLeg",  Vector3.new(1.0, 3.5, 1.0), CFrame.new(-0.7, -4.15, 0), Color3.fromRGB(30, 30, 30))
	attachPart(model, body, "RightLeg", Vector3.new(1.0, 3.5, 1.0), CFrame.new( 0.7, -4.15, 0), Color3.fromRGB(30, 30, 30))

	local killerType = spawnData.killerType
	if killerType == "Axe" then
		attachPart(model, body, "AxeHandle", Vector3.new(0.4, 4.5, 0.4),
			CFrame.new(3.0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(15)), Color3.fromRGB(100, 70, 40))
		local axeHead = attachPart(model, body, "AxeHead", Vector3.new(0.4, 2.2, 1.8),
			CFrame.new(3.5, 2.9, 0), cfg.weaponColor)
		addWeaponLight(axeHead, cfg.weaponColor)

	elseif killerType == "Chainsaw" then
		attachPart(model, body, "ChainsawBody", Vector3.new(0.7, 0.7, 4.5),
			CFrame.new(3.0, 0.3, 0), Color3.fromRGB(50, 50, 50))
		local blade = attachPart(model, body, "ChainsawBlade", Vector3.new(0.3, 0.3, 5.0),
			CFrame.new(3.0, 0.3, -2.5), cfg.weaponColor)
		addWeaponLight(blade, Color3.fromRGB(255, 150, 50))

	elseif killerType == "Knife" then
		local knife = attachPart(model, body, "KnifeBlade", Vector3.new(0.2, 3.2, 0.2),
			CFrame.new(3.0, 1.0, 0) * CFrame.Angles(0, 0, math.rad(30)), cfg.weaponColor)
		addWeaponLight(knife, Color3.fromRGB(200, 220, 255))

	elseif killerType == "Scythe" then
		attachPart(model, body, "ScythePole", Vector3.new(0.3, 6.5, 0.3),
			CFrame.new(2.8, 0.5, 0) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(80, 60, 40))
		local scytheBlade = attachPart(model, body, "ScytheBlade", Vector3.new(0.25, 3.5, 0.8),
			CFrame.new(2.5, 4.2, 0) * CFrame.Angles(0, 0, math.rad(-60)), cfg.weaponColor)
		addWeaponLight(scytheBlade, Color3.fromRGB(130, 100, 200))

	elseif killerType == "Hammer" then
		attachPart(model, body, "HammerHandle", Vector3.new(0.4, 4.2, 0.4),
			CFrame.new(3.0, 0.4, 0), Color3.fromRGB(100, 80, 50))
		local hammerHead = attachPart(model, body, "HammerHead", Vector3.new(1.4, 1.4, 3.0),
			CFrame.new(3.2, 2.6, 0), cfg.weaponColor)
		addWeaponLight(hammerHead, Color3.fromRGB(200, 180, 120))
	end

	model.PrimaryPart = body
	model.Parent = Workspace:WaitForChild("Map")

	local home = spawnData.position
	local r = 60
	local patrolPoints = {
		home + Vector3.new( r, 0,  0),
		home + Vector3.new( 0, 0,  r),
		home + Vector3.new(-r, 0,  0),
		home + Vector3.new( 0, 0, -r),
	}

	return {
		Model               = model,
		Body                = body,
		KillerType          = killerType,
		Cfg                 = cfg,
		Home                = home,
		Territory           = spawnData.territory,
		AlertRadius         = spawnData.alertRadius,
		PatrolPoints        = patrolPoints,
		PatrolIndex         = 1,
		State               = "Patrol",
		ChaseTarget         = nil,
		AttackCooldownUntil = 0,
		-- 경로탐색
		pathWaypoints       = nil,
		pathWpIdx           = 1,
		pathAge             = 0,
		pathBusy            = false,
	}
end

-- ── AI helpers ───────────────────────────────────────────────────────────────

local function moveTowardDirect(killer, targetPos, speed, deltaTime)
	local pos = killer.Body.Position
	local dx = targetPos.X - pos.X
	local dz = targetPos.Z - pos.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 0.5 then return dist end
	local step = math.min(speed * deltaTime, dist)
	local nx = pos.X + (dx / dist) * step
	local nz = pos.Z + (dz / dist) * step
	local nextPos = Vector3.new(nx, pos.Y, nz)
	killer.Body.CFrame = CFrame.lookAt(nextPos, Vector3.new(targetPos.X, nextPos.Y, targetPos.Z))
	return dist
end

-- pathfinding 경로를 따라 이동. 경로 없으면 직선 폴백. 남은 거리 반환
local function moveAlongPath(killer, targetPos, speed, deltaTime)
	local now = os.clock()
	if not killer.pathWaypoints or now - killer.pathAge > 1.2 then
		refreshPath(killer, targetPos)
	end

	local wp = killer.pathWaypoints and killer.pathWaypoints[killer.pathWpIdx]
	if wp then
		local dx = wp.X - killer.Body.Position.X
		local dz = wp.Z - killer.Body.Position.Z
		local wpDist = math.sqrt(dx * dx + dz * dz)
		if wpDist < 2 then
			killer.pathWpIdx += 1
			wp = killer.pathWaypoints[killer.pathWpIdx]
		end
		if wp then
			return moveTowardDirect(killer, wp, speed, deltaTime)
		end
	end
	-- 경로 없거나 완주 → 직선 이동 (폴백)
	return moveTowardDirect(killer, targetPos, speed, deltaTime)
end

-- 벽 너머 시야 차단: 킬러→플레이어 레이캐스트로 LOS 확인
local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
local losParamsAge = 0
local losExcludeList = {}

local function refreshLosParams()
	losExcludeList = {}
	for _, k in ipairs(killers) do
		if k.Model then table.insert(losExcludeList, k.Model) end
	end
	for _, k in ipairs(randomKillers) do
		if k.Model then table.insert(losExcludeList, k.Model) end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(losExcludeList, player.Character) end
	end
	local items = Workspace:FindFirstChild("Items")
	if items then table.insert(losExcludeList, items) end
	local effects = Workspace:FindFirstChild("Effects")
	if effects then table.insert(losExcludeList, effects) end
	losParams.FilterDescendantsInstances = losExcludeList
end

local function hasLOS(fromPos, toPos)
	local origin = fromPos + Vector3.new(0, 2, 0)
	local target = toPos   + Vector3.new(0, 2, 0)
	local result = Workspace:Raycast(origin, target - origin, losParams)
	return result == nil
end

local function findTargetInTerritory(killer)
	local bestPlayer, bestDist = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if isAliveCallback and isAliveCallback(player) then
			local root = getPlayerRoot(player)
			if root then
				local rp = root.Position
				local distHome   = (rp - killer.Home).Magnitude
				local distKiller = (rp - killer.Body.Position).Magnitude
				if distHome <= killer.Territory and distKiller < killer.AlertRadius then
					-- 벽 너머 감지 차단
					if hasLOS(killer.Body.Position, rp) then
						if distKiller < bestDist then
							bestPlayer = player
							bestDist   = distKiller
						end
					end
				end
			end
		end
	end
	return bestPlayer, bestDist
end

local function attemptAttack(killer)
	local now = os.clock()
	if now < killer.AttackCooldownUntil then return end

	local cfg        = killer.Cfg
	local killerType = killer.KillerType
	local pos        = killer.Body.Position

	if killerType == "Axe" then
		for _, player in ipairs(Players:GetPlayers()) do
			if isAliveCallback and isAliveCallback(player) then
				local root = getPlayerRoot(player)
				if root then
					local d = (root.Position - pos).Magnitude
					if d <= cfg.throwRange then
						local rp = RaycastParams.new()
						rp.FilterType = Enum.RaycastFilterType.Exclude
						rp.FilterDescendantsInstances = { killer.Model }
						local origin = pos + Vector3.new(0, 2, 0)
						local result = Workspace:Raycast(origin, root.Position - origin, rp)
						if result then
							local char = result.Instance:FindFirstAncestorOfClass("Model")
							if char and Players:GetPlayerFromCharacter(char) == player then
								local last = lastHitByPlayer[player] or 0
								if now - last >= 1.0 then
									lastHitByPlayer[player] = now
									if eliminateCallback then eliminateCallback(player, "도끼 킬러") end
								end
							end
						end
						killer.AttackCooldownUntil = now + cfg.attackCooldown
						return
					end
				end
			end
		end

	elseif killerType == "Chainsaw" then
		for _, player in ipairs(Players:GetPlayers()) do
			if isAliveCallback and isAliveCallback(player) then
				local root = getPlayerRoot(player)
				if root then
					if (root.Position - pos).Magnitude <= cfg.aoeRadius then
						local last = lastHitByPlayer[player] or 0
						if now - last >= 0.8 then
							lastHitByPlayer[player] = now
							if eliminateCallback then eliminateCallback(player, "전기톱 킬러") end
						end
					end
				end
			end
		end
		killer.AttackCooldownUntil = now + cfg.attackCooldown

	elseif killerType == "Knife" then
		for _, player in ipairs(Players:GetPlayers()) do
			if isAliveCallback and isAliveCallback(player) then
				local root = getPlayerRoot(player)
				if root then
					if (root.Position - pos).Magnitude <= cfg.attackRange then
						local last = lastHitByPlayer[player] or 0
						if now - last >= 0.6 then
							lastHitByPlayer[player] = now
							if eliminateCallback then eliminateCallback(player, "칼 킬러") end
						end
						killer.AttackCooldownUntil = now + cfg.attackCooldown
						return
					end
				end
			end
		end

	elseif killerType == "Scythe" then
		local lookDir = killer.Body.CFrame.LookVector
		local halfAngleCos = math.cos(math.rad(cfg.arcAngle * 0.5))
		for _, player in ipairs(Players:GetPlayers()) do
			if isAliveCallback and isAliveCallback(player) then
				local root = getPlayerRoot(player)
				if root then
					local d = (root.Position - pos).Magnitude
					if d <= cfg.attackRange then
						if lookDir:Dot((root.Position - pos).Unit) >= halfAngleCos then
							local last = lastHitByPlayer[player] or 0
							if now - last >= 1.0 then
								lastHitByPlayer[player] = now
								if eliminateCallback then eliminateCallback(player, "낫 킬러") end
							end
						end
					end
				end
			end
		end
		killer.AttackCooldownUntil = now + cfg.attackCooldown

	elseif killerType == "Hammer" then
		for _, player in ipairs(Players:GetPlayers()) do
			if isAliveCallback and isAliveCallback(player) then
				local root = getPlayerRoot(player)
				if root then
					if (root.Position - pos).Magnitude <= cfg.stunRadius then
						local last = lastHitByPlayer[player] or 0
						if now - last >= cfg.attackCooldown then
							lastHitByPlayer[player] = now
							if eliminateCallback then eliminateCallback(player, "망치 킬러") end
						end
					end
				end
			end
		end
		killer.AttackCooldownUntil = now + cfg.attackCooldown
	end
end

local function updateKiller(killer, deltaTime)
	if killer.State == "Patrol" then
		local target = findTargetInTerritory(killer)
		if target then
			killer.State = "Chase"
			killer.ChaseTarget = target
			killer.pathWaypoints = nil  -- 새 목표이므로 경로 초기화
			return
		end
		-- 순찰 지점으로 pathfinding
		local pt = killer.PatrolPoints[killer.PatrolIndex]
		local dist = moveAlongPath(killer, pt, killer.Cfg.walkSpeed * 0.55, deltaTime)
		if dist < 3 then
			killer.PatrolIndex = killer.PatrolIndex % #killer.PatrolPoints + 1
			killer.pathWaypoints = nil  -- 다음 순찰 지점으로 경로 초기화
		end

	elseif killer.State == "Chase" then
		local player = killer.ChaseTarget
		local alive  = isAliveCallback and isAliveCallback(player)
		local root   = alive and getPlayerRoot(player)
		if not root then
			killer.State = "Return"
			killer.ChaseTarget = nil
			killer.pathWaypoints = nil
			return
		end
		if (root.Position - killer.Home).Magnitude > killer.Territory
			or (killer.Body.Position - killer.Home).Magnitude > killer.Territory + 40 then
			killer.State = "Return"
			killer.ChaseTarget = nil
			killer.pathWaypoints = nil
			return
		end
		moveAlongPath(killer, root.Position, killer.Cfg.walkSpeed, deltaTime)
		attemptAttack(killer)

	elseif killer.State == "Return" then
		local dist = moveAlongPath(killer, killer.Home, killer.Cfg.walkSpeed * 0.65, deltaTime)
		if dist < 3 then
			killer.State = "Patrol"
			killer.pathWaypoints = nil
		end
	end
end

-- ── 랜덤 출현 이벤트 ──────────────────────────────────────────────────────────

local function clearRandomKillers()
	for _, k in ipairs(randomKillers) do
		if k.Model then k.Model:Destroy() end
	end
	table.clear(randomKillers)
end

local function scheduleRandomEvent(token)
	task.delay(GameConfig.RandomKillerEventInterval, function()
		if not active or eventToken ~= token then return end

		local zones = {}
		for _, z in ipairs(RANDOM_SPAWN_ZONES) do table.insert(zones, z) end
		for i = #zones, 2, -1 do
			local j = math.random(1, i)
			zones[i], zones[j] = zones[j], zones[i]
		end

		local count = math.min(GameConfig.RandomKillerCount, #zones)
		for i = 1, count do
			local ktype = KILLER_TYPES[math.random(1, #KILLER_TYPES)]
			local spawnData = {
				position    = zones[i],
				killerType  = ktype,
				territory   = 900,
				alertRadius = 55,
			}
			table.insert(randomKillers, buildModel("Event_" .. ktype .. "_" .. i, spawnData))
		end

		if onRandomKillerSpawn then
			onRandomKillerSpawn(#randomKillers)
		end

		task.delay(GameConfig.RandomKillerActiveDuration, function()
			if eventToken ~= token then return end
			clearRandomKillers()
			if onRandomKillerDespawn then
				onRandomKillerDespawn(count)
			end
			scheduleRandomEvent(token)
		end)
	end)
end

-- ── Public API ───────────────────────────────────────────────────────────────

function KillerController.Init(options)
	isAliveCallback       = options.IsAlive
	eliminateCallback     = options.EliminatePlayer
	onRandomKillerSpawn   = options.OnRandomKillerSpawn
	onRandomKillerDespawn = options.OnRandomKillerDespawn
end

function KillerController.Spawn()
	KillerController.Despawn()
	for i, spawnData in ipairs(FIXED_SPAWN_DATA) do
		table.insert(killers, buildModel(spawnData.killerType .. "_" .. i, spawnData))
	end
	lastHitByPlayer = {}
	refreshLosParams()
end

function KillerController.Start()
	if heartbeatConnection then heartbeatConnection:Disconnect() end
	active = true
	eventToken += 1
	local myToken = eventToken
	losParamsAge = 0

	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not active or os.clock() < stunnedUntil then return end

		-- LOS 파라미터 주기적 갱신 (1초마다)
		losParamsAge += deltaTime
		if losParamsAge >= 1 then
			losParamsAge = 0
			refreshLosParams()
		end

		for _, killer in ipairs(killers) do
			updateKiller(killer, deltaTime)
		end
		for _, killer in ipairs(randomKillers) do
			updateKiller(killer, deltaTime)
		end
	end)

	scheduleRandomEvent(myToken)
end

function KillerController.Stun(duration)
	stunnedUntil = math.max(stunnedUntil, os.clock() + duration)
end

function KillerController.Stop()
	active = false
	eventToken += 1
	clearRandomKillers()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

function KillerController.Despawn()
	KillerController.Stop()
	stunnedUntil = 0
	for _, killer in ipairs(killers) do
		if killer.Model then killer.Model:Destroy() end
	end
	table.clear(killers)
end

return KillerController
