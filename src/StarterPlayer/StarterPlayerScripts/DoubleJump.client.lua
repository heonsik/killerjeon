local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DOUBLE_JUMP_POWER = 52

local humanoid = nil
local rootPart = nil
local hasJumpedFromGround = false
local canDoubleJump = false

local gui = Instance.new("ScreenGui")
gui.Name = "DoubleJumpUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local jumpButton = Instance.new("TextButton")
jumpButton.Name = "DoubleJumpButton"
jumpButton.AnchorPoint = Vector2.new(1, 1)
jumpButton.Position = UDim2.new(1, -176, 1, -34)
jumpButton.Size = UDim2.fromOffset(132, 54)
jumpButton.BackgroundColor3 = Color3.fromRGB(42, 30, 62)
jumpButton.BackgroundTransparency = 0.06
jumpButton.BorderSizePixel = 0
jumpButton.Text = "2 Jump"
jumpButton.TextColor3 = Color3.fromRGB(245, 248, 255)
jumpButton.TextScaled = true
jumpButton.Font = Enum.Font.GothamBlack
jumpButton.AutoButtonColor = true
jumpButton.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = jumpButton

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(180, 125, 255)
stroke.Thickness = 2
stroke.Transparency = 0.15
stroke.Parent = jumpButton

local textConstraint = Instance.new("UITextSizeConstraint")
textConstraint.MinTextSize = 12
textConstraint.MaxTextSize = 20
textConstraint.Parent = jumpButton

local function setButtonState(ready)
	if ready then
		jumpButton.BackgroundColor3 = Color3.fromRGB(42, 30, 62)
		stroke.Color = Color3.fromRGB(180, 125, 255)
		jumpButton.Text = "2 Jump"
	else
		jumpButton.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
		stroke.Color = Color3.fromRGB(90, 70, 110)
		jumpButton.Text = "Ready"
	end
end

local function spawnJumpFlash()
	if not rootPart then
		return
	end

	local flash = Instance.new("Part")
	flash.Size = Vector3.new(3, 3, 3)
	flash.Shape = Enum.PartType.Ball
	flash.Color = Color3.fromRGB(178, 125, 255)
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CFrame = rootPart.CFrame
	flash.Parent = workspace

	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 20
	light.Color = Color3.fromRGB(178, 125, 255)
	light.Parent = flash

	local tween = TweenService:Create(flash, TweenInfo.new(0.3), {
		Size = Vector3.new(0.1, 0.1, 0.1),
		Transparency = 1,
	})
	tween:Play()
	task.delay(0.35, function()
		if flash then
			flash:Destroy()
		end
	end)
end

local function doDoubleJump()
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end
	if not canDoubleJump then
		return
	end

	local state = humanoid:GetState()
	if state ~= Enum.HumanoidStateType.Freefall and state ~= Enum.HumanoidStateType.Jumping then
		return
	end

	canDoubleJump = false
	setButtonState(false)

	local velocity = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, DOUBLE_JUMP_POWER, velocity.Z)
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	spawnJumpFlash()
end

local function resetJumpState()
	hasJumpedFromGround = false
	canDoubleJump = false
	setButtonState(false)
end

local function bindCharacter(character)
	humanoid = character:WaitForChild("Humanoid", 5)
	rootPart = character:WaitForChild("HumanoidRootPart", 5)
	resetJumpState()

	if not humanoid or not rootPart then
		return
	end

	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Jumping then
			if not hasJumpedFromGround then
				hasJumpedFromGround = true
				canDoubleJump = true
				setButtonState(true)
			end
		elseif newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics
			or newState == Enum.HumanoidStateType.Seated then
			resetJumpState()
		end
	end)

	humanoid.Died:Connect(resetJumpState)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space then
		doDoubleJump()
	end
end)

jumpButton.Activated:Connect(doDoubleJump)

if player.Character then
	bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)
