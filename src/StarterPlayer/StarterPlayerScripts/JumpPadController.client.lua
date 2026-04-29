local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local jumpPadLaunch = remotes:WaitForChild("JumpPadLaunch")

jumpPadLaunch.OnClientEvent:Connect(function(velocity)
	local character = player.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	-- Jumping 상태로 전환해야 Humanoid가 속도를 허용함
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity = velocity
end)
