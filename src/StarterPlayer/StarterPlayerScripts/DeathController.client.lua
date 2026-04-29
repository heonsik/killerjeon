local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local playerEliminated = remotes:WaitForChild("PlayerEliminated")
local gameStateChanged  = remotes:WaitForChild("GameStateChanged")
local respawnRequest    = remotes:WaitForChild("RespawnRequest")

local isDeadState = false
local bloodParts = {}

local function cleanup()
	isDeadState = false
	for _, p in ipairs(bloodParts) do
		if p and p.Parent then p:Destroy() end
	end
	table.clear(bloodParts)
end

local function restoreHumanoid()
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if humanoid then
		humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = false end
	end
	if root then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function playDeathEffect()
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then return end

	isDeadState = true

	-- 움직임 정지
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = false
	humanoid.Sit = false
	local animate = char:FindFirstChild("Animate")
	if animate then animate.Disabled = true end

	-- 쓰러지는 애니메이션 (옆으로 눕기)
	local deathPos = root.Position
	local deathCF = CFrame.new(deathPos.X, deathPos.Y - 2.2, deathPos.Z)
		* CFrame.Angles(0, root.CFrame:ToEulerAnglesYXZ(), 0)
		* CFrame.Angles(math.rad(90), 0, 0)

	TweenService:Create(root, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = deathCF,
	}):Play()

	task.delay(0.75, function()
		if isDeadState and root and root.Parent then
			root.Anchored = true
		end
	end)

	-- 혈흔 (클라이언트 로컬)
	task.delay(0.5, function()
		if not isDeadState then return end
		local blood = Instance.new("Part")
		blood.Name = "LocalBlood"
		blood.Shape = Enum.PartType.Cylinder
		blood.Size = Vector3.new(0.2, 7, 7)
		blood.CFrame = CFrame.new(deathPos.X, 0.6, deathPos.Z) * CFrame.Angles(0, 0, math.rad(90))
		blood.Color = Color3.fromRGB(80, 8, 8)
		blood.Material = Enum.Material.SmoothPlastic
		blood.Anchored = true
		blood.CanCollide = false
		blood.Parent = workspace
		table.insert(bloodParts, blood)

		-- 번짐 효과 (크기 증가)
		TweenService:Create(blood, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.2, 11, 11),
		}):Play()
	end)
end

playerEliminated.OnClientEvent:Connect(function()
	task.delay(0.2, playDeathEffect)
end)

gameStateChanged.OnClientEvent:Connect(function(nextState)
	if nextState == "Finished" or nextState == "Waiting" then
		restoreHumanoid()
		cleanup()
	end
end)

player.CharacterAdded:Connect(function()
	restoreHumanoid()
	cleanup()
end)
