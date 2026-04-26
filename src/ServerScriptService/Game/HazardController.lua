local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HazardController = {}

local getStateCallback
local eliminateCallback
local connections = {}
local cooldowns = {}

local function getPlayerFromHit(hit)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function connectHazard(part)
	if connections[part] or not part:IsA("BasePart") then
		return
	end

	if not part:GetAttribute("HazardType") then
		return
	end

	connections[part] = part.Touched:Connect(function(hit)
		if getStateCallback and getStateCallback() ~= "Playing" then
			return
		end

		local player = getPlayerFromHit(hit)
		if not player then
			return
		end

		local now = os.clock()
		local lastHit = cooldowns[player] or 0
		if now - lastHit < 1.25 then
			return
		end

		cooldowns[player] = now
		if eliminateCallback then
			eliminateCallback(player, part:GetAttribute("HazardType"))
		end
	end)
end

function HazardController.Init(options)
	getStateCallback = options.GetState
	eliminateCallback = options.EliminatePlayer

	local mapFolder = Workspace:WaitForChild("Map")
	for _, item in ipairs(mapFolder:GetDescendants()) do
		connectHazard(item)
	end

	mapFolder.DescendantAdded:Connect(connectHazard)
end

function HazardController.Reset()
	table.clear(cooldowns)
end

return HazardController
