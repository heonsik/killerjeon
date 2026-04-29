local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local player = Players.LocalPlayer

local humanoid = nil
local rootPart = nil
local originalHipHeight = nil
local originalWalkSpeed = nil
local slideActive = false
local slideCooldown = false

local function startSlide()
	if slideActive or slideCooldown then return end
	if not humanoid or not rootPart then return end
	if humanoid.Health <= 0 then return end

	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then return end

	slideActive = true
	slideCooldown = true

	originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = GameConfig.SlideSpeed
	humanoid.HipHeight = originalHipHeight + GameConfig.SlideHipHeightOffset

	rootPart.AssemblyLinearVelocity = Vector3.new(
		moveDir.X * GameConfig.SlideSpeed,
		rootPart.AssemblyLinearVelocity.Y,
		moveDir.Z * GameConfig.SlideSpeed
	)

	task.delay(GameConfig.SlideDuration, function()
		if humanoid and humanoid.Health > 0 then
			humanoid.WalkSpeed = originalWalkSpeed or GameConfig.DefaultWalkSpeed
			humanoid.HipHeight = originalHipHeight or 2
		end
		slideActive = false
	end)

	task.delay(GameConfig.SlideCooldown, function()
		slideCooldown = false
	end)
end

local function onCharacterAdded(character)
	slideActive = false
	slideCooldown = false

	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")
	originalHipHeight = humanoid.HipHeight
	originalWalkSpeed = humanoid.WalkSpeed

	humanoid.Died:Connect(function()
		if slideActive then
			humanoid.WalkSpeed = originalWalkSpeed or GameConfig.DefaultWalkSpeed
			humanoid.HipHeight = originalHipHeight or 2
			slideActive = false
		end
	end)
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
		startSlide()
	end
end)
