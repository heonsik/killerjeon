local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

local DroneController = {}

local drones = {}
local heartbeatConnection
local active = false
local isAliveCallback
local eliminateCallback
local stunnedUntil = 0
local lastTouchByPlayer = {}

local patrolRoutes = {
	{
		Vector3.new(-760, 6, 760),
		Vector3.new(-760, 6, 260),
		Vector3.new(-540, 6, -240),
		Vector3.new(-760, 6, -760),
	},
	{
		Vector3.new(760, 6, -760),
		Vector3.new(760, 6, -260),
		Vector3.new(540, 6, 240),
		Vector3.new(760, 6, 760),
	},
	{
		Vector3.new(-620, 6, -620),
		Vector3.new(0, 6, -760),
		Vector3.new(620, 6, -620),
		Vector3.new(0, 6, -320),
	},
	{
		Vector3.new(620, 6, 620),
		Vector3.new(0, 6, 760),
		Vector3.new(-620, 6, 620),
		Vector3.new(0, 6, 320),
	},
	{
		Vector3.new(-520, 6, 0),
		Vector3.new(0, 6, 520),
		Vector3.new(520, 6, 0),
		Vector3.new(0, 6, -520),
	},
}

local function createDrone(index, position)
	local model = Instance.new("Model")
	model.Name = "ChaserGuard" .. index

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3.6, 5.2, 2.3)
	body.CFrame = CFrame.new(position)
	body.Color = Color3.fromRGB(255, 215, 74)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model

	local function attachPart(name, size, offset, color, material, shape)
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

	attachPart("Head", Vector3.new(2.7, 2.7, 2.7), CFrame.new(0, 4.0, 0), Color3.fromRGB(255, 205, 150), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	attachPart("Helmet", Vector3.new(3.0, 1.1, 3.0), CFrame.new(0, 5.0, -0.1), Color3.fromRGB(45, 53, 68), Enum.Material.Metal, Enum.PartType.Ball)
	attachPart("LeftArm", Vector3.new(1.05, 4.3, 1.05), CFrame.new(-2.45, -0.15, 0), Color3.fromRGB(235, 162, 58))
	attachPart("RightArm", Vector3.new(1.05, 4.3, 1.05), CFrame.new(2.45, -0.15, 0), Color3.fromRGB(235, 162, 58))
	attachPart("LeftLeg", Vector3.new(1.1, 3.8, 1.1), CFrame.new(-0.85, -4.45, 0), Color3.fromRGB(54, 65, 88))
	attachPart("RightLeg", Vector3.new(1.1, 3.8, 1.1), CFrame.new(0.85, -4.45, 0), Color3.fromRGB(54, 65, 88))
	attachPart("ChestBadge", Vector3.new(1.6, 0.28, 0.16), CFrame.new(0, 0.9, -1.25), Color3.fromRGB(255, 70, 70), Enum.Material.Neon)

	local eye = Instance.new("Part")
	eye.Name = "FaceScanner"
	eye.Size = Vector3.new(1.7, 0.55, 0.28)
	eye.CFrame = body.CFrame * CFrame.new(0, 4.15, -1.35)
	eye.Color = Color3.fromRGB(255, 65, 65)
	eye.Material = Enum.Material.Neon
	eye.Anchored = true
	eye.CanCollide = false
	eye.Parent = model

	local light = Instance.new("SpotLight")
	light.Brightness = 4
	light.Range = 48
	light.Angle = 52
	light.Color = Color3.fromRGB(255, 70, 70)
	light.Face = Enum.NormalId.Front
	light.Parent = eye

	local labelGui = Instance.new("BillboardGui")
	labelGui.Name = "DroneLabel"
	labelGui.Size = UDim2.fromOffset(120, 32)
	labelGui.StudsOffset = Vector3.new(0, 7, 0)
	labelGui.AlwaysOnTop = true
	labelGui.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "감시자"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = labelGui

	model.PrimaryPart = body
	model.Parent = Workspace:WaitForChild("Map")

	return {
		Model = model,
		Body = body,
		Eye = eye,
		Route = patrolRoutes[index],
		RouteIndex = 1,
		ChaseTarget = nil,
	}
end

local function getPlayerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function findNearestAlivePlayer(fromPosition)
	local nearestPlayer = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if isAliveCallback and isAliveCallback(player) then
			local root = getPlayerRoot(player)
			if root then
				local distance = (root.Position - fromPosition).Magnitude
				if distance < nearestDistance then
					nearestPlayer = player
					nearestDistance = distance
				end
			end
		end
	end

	return nearestPlayer, nearestDistance
end

local function setDroneCFrame(drone, cframe)
	drone.Body.CFrame = cframe
	drone.Eye.CFrame = cframe * CFrame.new(0, 4.15, -1.35)
end

local function moveDronePatrol(drone, deltaTime)
	local route = drone.Route
	local target = route[drone.RouteIndex]
	local offset = target - drone.Body.Position
	local distance = offset.Magnitude

	if distance < 2 then
		drone.RouteIndex = drone.RouteIndex % #route + 1
		return
	end

	local step = math.min(GameConfig.DroneSpeed * deltaTime, distance)
	local nextPosition = drone.Body.Position + offset.Unit * step
	local lookTarget = Vector3.new(target.X, nextPosition.Y, target.Z)
	setDroneCFrame(drone, CFrame.lookAt(nextPosition, lookTarget))
end

local function moveDroneChase(drone, targetPosition, deltaTime)
	local adjustedTarget = Vector3.new(targetPosition.X, drone.Body.Position.Y, targetPosition.Z)
	local offset = adjustedTarget - drone.Body.Position
	local distance = offset.Magnitude
	if distance < 0.5 then
		return
	end

	local speed = GameConfig.DroneSpeed * GameConfig.DroneChaseSpeedBonus
	local step = math.min(speed * deltaTime, distance)
	local nextPosition = drone.Body.Position + offset.Unit * step
	setDroneCFrame(drone, CFrame.lookAt(nextPosition, adjustedTarget))
end

local function checkPlayerHits(drone)
	for _, player in ipairs(Players:GetPlayers()) do
		if isAliveCallback and isAliveCallback(player) then
			local root = getPlayerRoot(player)
			if root then
				local distance = (root.Position - drone.Body.Position).Magnitude
				if distance <= GameConfig.DroneTouchRadius then
					local now = os.clock()
					local lastTouch = lastTouchByPlayer[player] or 0
					if now - lastTouch >= GameConfig.DroneTouchCooldown then
						lastTouchByPlayer[player] = now
						if eliminateCallback then
							eliminateCallback(player, "감시자")
						end
					end
				end
			end
		end
	end
end

function DroneController.Init(options)
	isAliveCallback = options.IsAlive
	eliminateCallback = options.EliminatePlayer
end

function DroneController.Spawn()
	DroneController.Despawn()

	for index = 1, GameConfig.DroneCount do
		local route = patrolRoutes[index]
		if route then
			table.insert(drones, createDrone(index, route[1]))
		end
	end

	lastTouchByPlayer = {}
end

function DroneController.Start()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
	end

	active = true
	heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not active or os.clock() < stunnedUntil then
			return
		end

		for _, drone in ipairs(drones) do
			if drone.ChaseTarget then
				local alive = isAliveCallback and isAliveCallback(drone.ChaseTarget)
				local root = alive and getPlayerRoot(drone.ChaseTarget)
				if not root then
					drone.ChaseTarget = nil
				else
					local distance = (root.Position - drone.Body.Position).Magnitude
					if distance > GameConfig.DroneReturnRange then
						drone.ChaseTarget = nil
					else
						moveDroneChase(drone, root.Position, deltaTime)
					end
				end
			end

			if not drone.ChaseTarget then
				local nearPlayer, nearDistance = findNearestAlivePlayer(drone.Body.Position)
				if nearPlayer and nearDistance < GameConfig.DroneChaseRange then
					drone.ChaseTarget = nearPlayer
				else
					moveDronePatrol(drone, deltaTime)
				end
			end

			checkPlayerHits(drone)
		end
	end)
end

function DroneController.Stun(duration)
	stunnedUntil = math.max(stunnedUntil, os.clock() + duration)
end

function DroneController.Stop()
	active = false
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
end

function DroneController.Despawn()
	DroneController.Stop()
	stunnedUntil = 0
	for _, drone in ipairs(drones) do
		if drone.Model then
			drone.Model:Destroy()
		end
	end
	table.clear(drones)
end

return DroneController
