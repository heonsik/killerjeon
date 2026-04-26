local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local MapEventController = {}

local active = false
local eventToken = 0
local getStateCallback
local setChaserSpeedCallback

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local eventAnnouncement = remotesFolder:FindFirstChild("EventAnnouncement") or Instance.new("RemoteEvent")
eventAnnouncement.Name = "EventAnnouncement"
eventAnnouncement.Parent = remotesFolder

local defaultLighting = {
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	FogEnd = Lighting.FogEnd,
}

local function captureLighting()
	defaultLighting.Brightness = Lighting.Brightness
	defaultLighting.Ambient = Lighting.Ambient
	defaultLighting.FogEnd = Lighting.FogEnd
end

local function announce(message, duration)
	eventAnnouncement:FireAllClients(message, duration or 3)
end

local function startRush(token)
	if not active or eventToken ~= token then
		return
	end

	announce("위험 모드: 추격자가 빨라집니다", GameConfig.RushEventDuration)
	if setChaserSpeedCallback then
		setChaserSpeedCallback(GameConfig.ChaserRushMultiplier)
	end

	Lighting.Brightness = 1.1
	Lighting.Ambient = Color3.fromRGB(82, 28, 36)
	Lighting.FogEnd = 360

	task.wait(GameConfig.RushEventDuration)

	if setChaserSpeedCallback then
		setChaserSpeedCallback(1)
	end

	Lighting.Brightness = defaultLighting.Brightness
	Lighting.Ambient = defaultLighting.Ambient
	Lighting.FogEnd = defaultLighting.FogEnd
end

function MapEventController.Init(options)
	getStateCallback = options.GetState
	setChaserSpeedCallback = options.SetChaserSpeed
end

function MapEventController.Start()
	captureLighting()
	active = true
	eventToken += 1
	local token = eventToken

	task.spawn(function()
		task.wait(GameConfig.RushEventInterval)
		while active and eventToken == token do
			if getStateCallback and getStateCallback() == "Playing" then
				startRush(token)
			end
			task.wait(GameConfig.RushEventInterval)
		end
	end)
end

function MapEventController.Stop()
	active = false
	eventToken += 1
	if setChaserSpeedCallback then
		setChaserSpeedCallback(1)
	end

	Lighting.Brightness = defaultLighting.Brightness
	Lighting.Ambient = defaultLighting.Ambient
	Lighting.FogEnd = defaultLighting.FogEnd
	eventAnnouncement:FireAllClients("", 0)
end

return MapEventController
