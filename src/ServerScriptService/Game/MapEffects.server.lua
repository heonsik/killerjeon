local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local pulseParts = {}
local pulseLights = {}

local function refresh()
	table.clear(pulseParts)
	table.clear(pulseLights)

	local mapFolder = Workspace:FindFirstChild("Map")
	if not mapFolder then
		return
	end

	for _, item in ipairs(mapFolder:GetDescendants()) do
		if item:IsA("BasePart") and (item.Material == Enum.Material.Neon or item:GetAttribute("PulseLight")) then
			table.insert(pulseParts, item)
		end

		if item:IsA("PointLight") then
			table.insert(pulseLights, {
				Light = item,
				BaseBrightness = item.Brightness,
			})
		end
	end
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Map" then
		task.defer(refresh)
	end
end)

task.defer(refresh)
task.delay(1, refresh)
task.delay(3, refresh)

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local pulse = 0.72 + math.sin(t * 4.5) * 0.18

	for index, part in ipairs(pulseParts) do
		if part.Parent then
			part.Transparency = math.clamp(0.08 + math.sin(t * 3 + index) * 0.08, 0, 0.28)
		end
	end

	for index, data in ipairs(pulseLights) do
		local light = data.Light
		if light.Parent then
			light.Brightness = data.BaseBrightness * (pulse + math.sin(t * 2.5 + index) * 0.08)
		end
	end
end)
