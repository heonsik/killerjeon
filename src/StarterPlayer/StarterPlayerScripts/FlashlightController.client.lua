local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pickupFlashlight   = remotes:WaitForChild("PickupFlashlight")
local flashlightConsumed = remotes:WaitForChild("FlashlightConsumed")
local flashlightHit      = remotes:WaitForChild("FlashlightHit")

local hasFlashlight = false
local flashlightOn  = false
local spotLight     = nil
local holdPart      = nil

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function createSpotlight(root)
	if spotLight and spotLight.Parent then spotLight:Destroy() end
	if holdPart and holdPart.Parent then holdPart:Destroy() end

	holdPart = Instance.new("Part")
	holdPart.Name = "FlashlightHold"
	holdPart.Size = Vector3.new(0.4, 0.4, 1.8)
	holdPart.Color = Color3.fromRGB(40, 40, 40)
	holdPart.Material = Enum.Material.Metal
	holdPart.Anchored = false
	holdPart.CanCollide = false
	holdPart.Massless = true
	holdPart.Parent = root.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = holdPart
	weld.Parent = holdPart
	holdPart.CFrame = root.CFrame * CFrame.new(1.2, -0.6, -1.4)

	spotLight = Instance.new("SpotLight")
	spotLight.Brightness = 6
	spotLight.Range = GameConfig.FlashlightRange
	spotLight.Angle = GameConfig.FlashlightFOVAngle + 10
	spotLight.Color = Color3.fromRGB(255, 240, 200)
	spotLight.Face = Enum.NormalId.Front
	spotLight.Enabled = false
	spotLight.Parent = holdPart
end

local function setFlashlightOn(on)
	flashlightOn = on
	if spotLight then
		spotLight.Enabled = on
	end
end

local function removeFlashlight()
	hasFlashlight = false
	flashlightOn  = false
	if spotLight and spotLight.Parent then spotLight:Destroy() end
	if holdPart and holdPart.Parent then holdPart:Destroy() end
	spotLight = nil
	holdPart  = nil
end

pickupFlashlight.OnClientEvent:Connect(function()
	hasFlashlight = true
	local root = getRoot()
	if root then
		createSpotlight(root)
	end
end)

flashlightConsumed.OnClientEvent:Connect(function()
	removeFlashlight()
end)

player.CharacterAdded:Connect(function()
	removeFlashlight()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.F then
		if not hasFlashlight then return end
		setFlashlightOn(not flashlightOn)
	end

	if input.KeyCode == Enum.KeyCode.E then
		if not hasFlashlight or not flashlightOn then return end
		flashlightHit:FireServer()
	end
end)
