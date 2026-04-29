local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gameStateChanged  = remotes:WaitForChild("GameStateChanged")
local timerChanged      = remotes:WaitForChild("TimerChanged")
local aliveCountChanged = remotes:WaitForChild("AliveCountChanged")
local objectiveChanged  = remotes:WaitForChild("ObjectiveChanged")
local eventAnnouncement = remotes:WaitForChild("EventAnnouncement")
local powerupChanged    = remotes:WaitForChild("PowerupChanged")
local roundResult       = remotes:WaitForChild("RoundResult")
local playerEliminated  = remotes:WaitForChild("PlayerEliminated")
local dangerAlert       = remotes:WaitForChild("DangerAlert")
local announcementEvent = remotes:WaitForChild("Announcement")
local detectionLevelEv  = remotes:WaitForChild("DetectionLevel")
local detectionAlertEv  = remotes:WaitForChild("DetectionAlert")
local difficultyChangedEv = remotes:WaitForChild("DifficultyChanged")
local setDifficultyEv   = remotes:WaitForChild("SetDifficulty")
local respawnRequestEv  = remotes:WaitForChild("RespawnRequest")

local stateTextByKey = {
	Waiting = "대기 중",
	Preparing = "준비 중",
	Playing = "도망쳐",
	Finished = "결과",
}

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "StatusPanel"
root.AnchorPoint = Vector2.new(0.5, 0)
root.Position = UDim2.fromScale(0.5, 0.025)
root.Size = UDim2.fromOffset(820, 82)
root.BackgroundColor3 = Color3.fromRGB(22, 26, 34)
root.BackgroundTransparency = 0.08
root.BorderSizePixel = 0
root.ZIndex = 2
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 8)
rootCorner.Parent = root

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = root

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.Parent = root

local function createLabel(name, width, textColor)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromOffset(width, 58)
	label.BackgroundColor3 = Color3.fromRGB(38, 46, 61)
	label.BorderSizePixel = 0
	label.TextColor3 = textColor or Color3.fromRGB(245, 247, 250)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = "-"
	label.ZIndex = 3
	label.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 11
	constraint.MaxTextSize = 22
	constraint.Parent = label

	return label
end

local stateLabel = createLabel("StateLabel", 110, Color3.fromRGB(255, 231, 150))
local timerLabel = createLabel("TimerLabel", 155, Color3.fromRGB(138, 219, 255))
local aliveLabel = createLabel("AliveCountLabel", 155, Color3.fromRGB(160, 245, 174))
local objectiveLabel = createLabel("ObjectiveLabel", 165, Color3.fromRGB(255, 120, 150))
local powerupLabel = createLabel("PowerupLabel", 185, Color3.fromRGB(178, 125, 255))

local resultLabel = Instance.new("TextLabel")
resultLabel.Name = "ResultLabel"
resultLabel.AnchorPoint = Vector2.new(0.5, 0.5)
resultLabel.Position = UDim2.fromScale(0.5, 0.42)
resultLabel.Size = UDim2.fromOffset(620, 120)
resultLabel.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
resultLabel.BackgroundTransparency = 0.04
resultLabel.BorderSizePixel = 0
resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
resultLabel.TextScaled = true
resultLabel.Font = Enum.Font.GothamBlack
resultLabel.Text = ""
resultLabel.Visible = false
resultLabel.ZIndex = 10
resultLabel.Parent = gui

local resultCorner = Instance.new("UICorner")
resultCorner.CornerRadius = UDim.new(0, 8)
resultCorner.Parent = resultLabel

local eventLabel = Instance.new("TextLabel")
eventLabel.Name = "EventLabel"
eventLabel.AnchorPoint = Vector2.new(0.5, 0)
eventLabel.Position = UDim2.fromScale(0.5, 0.14)
eventLabel.Size = UDim2.fromOffset(540, 54)
eventLabel.BackgroundColor3 = Color3.fromRGB(125, 26, 38)
eventLabel.BackgroundTransparency = 0.05
eventLabel.BorderSizePixel = 0
eventLabel.TextColor3 = Color3.fromRGB(255, 240, 210)
eventLabel.TextScaled = true
eventLabel.Font = Enum.Font.GothamBlack
eventLabel.Text = ""
eventLabel.Visible = false
eventLabel.ZIndex = 8
eventLabel.Parent = gui

local eventCorner = Instance.new("UICorner")
eventCorner.CornerRadius = UDim.new(0, 8)
eventCorner.Parent = eventLabel

local announcementLabel = Instance.new("TextLabel")
announcementLabel.Name = "AnnouncementLabel"
announcementLabel.AnchorPoint = Vector2.new(0.5, 0)
announcementLabel.Position = UDim2.fromScale(0.5, 0.22)
announcementLabel.Size = UDim2.fromOffset(480, 46)
announcementLabel.BackgroundColor3 = Color3.fromRGB(28, 38, 52)
announcementLabel.BackgroundTransparency = 0.1
announcementLabel.BorderSizePixel = 0
announcementLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
announcementLabel.TextScaled = true
announcementLabel.Font = Enum.Font.GothamBold
announcementLabel.Text = ""
announcementLabel.Visible = false
announcementLabel.ZIndex = 9
announcementLabel.Parent = gui

local announcementCorner = Instance.new("UICorner")
announcementCorner.CornerRadius = UDim.new(0, 8)
announcementCorner.Parent = announcementLabel

local eliminatedOverlay = Instance.new("Frame")
eliminatedOverlay.Name = "EliminatedOverlay"
eliminatedOverlay.Size = UDim2.fromScale(1, 1)
eliminatedOverlay.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
eliminatedOverlay.BackgroundTransparency = 1
eliminatedOverlay.BorderSizePixel = 0
eliminatedOverlay.ZIndex = 20
eliminatedOverlay.Visible = false
eliminatedOverlay.Parent = gui

local eliminatedText = Instance.new("TextLabel")
eliminatedText.Size = UDim2.fromScale(1, 1)
eliminatedText.BackgroundTransparency = 1
eliminatedText.TextColor3 = Color3.fromRGB(255, 255, 255)
eliminatedText.TextScaled = true
eliminatedText.Font = Enum.Font.GothamBlack
eliminatedText.Text = "탈락!"
eliminatedText.ZIndex = 21
eliminatedText.Parent = eliminatedOverlay

local dangerFrame = Instance.new("Frame")
dangerFrame.Name = "DangerFrame"
dangerFrame.Size = UDim2.fromScale(1, 1)
dangerFrame.BackgroundTransparency = 1
dangerFrame.BorderSizePixel = 0
dangerFrame.ZIndex = 15
dangerFrame.Parent = gui

local dangerStroke = Instance.new("UIStroke")
dangerStroke.Color = Color3.fromRGB(220, 50, 50)
dangerStroke.Thickness = 28
dangerStroke.Transparency = 1
dangerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
dangerStroke.Parent = dangerFrame

local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local remainSeconds = seconds % 60
	return string.format("%02d:%02d", minutes, remainSeconds)
end

local function timerColor(seconds)
	if seconds <= 30 then
		return Color3.fromRGB(255, 80, 80)
	elseif seconds <= 60 then
		return Color3.fromRGB(255, 215, 74)
	else
		return Color3.fromRGB(138, 219, 255)
	end
end

local announcementQueue = {}
local announcementBusy = false

local function showNextAnnouncement()
	if announcementBusy or #announcementQueue == 0 then
		return
	end

	announcementBusy = true
	local item = table.remove(announcementQueue, 1)
	announcementLabel.Text = item.Text
	announcementLabel.Visible = true
	announcementLabel.BackgroundTransparency = 0.1
	announcementLabel.TextTransparency = 0

	task.delay(item.Duration or 2.5, function()
		TweenService:Create(announcementLabel, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()

		task.delay(0.45, function()
			announcementLabel.Visible = false
			announcementBusy = false
			showNextAnnouncement()
		end)
	end)
end

local function pushAnnouncement(text, duration)
	table.insert(announcementQueue, {
		Text = text,
		Duration = duration,
	})
	showNextAnnouncement()
end

local powerupToken = 0

gameStateChanged.OnClientEvent:Connect(function(nextState)
	stateLabel.Text = stateTextByKey[nextState] or nextState
	if nextState == "Waiting" then
		timerLabel.Text = "자동 시작"
		timerLabel.TextColor3 = Color3.fromRGB(138, 219, 255)
	end
end)

timerChanged.OnClientEvent:Connect(function(seconds, label)
	if seconds <= 0 and label == "대기" then
		timerLabel.Text = "자동 시작"
		timerLabel.TextColor3 = Color3.fromRGB(138, 219, 255)
	else
		timerLabel.Text = string.format("%s %s", label or "시간", formatTime(seconds))
		if label == "생존" then
			timerLabel.TextColor3 = timerColor(seconds)
		end
	end
end)

aliveCountChanged.OnClientEvent:Connect(function(aliveCount, totalCount)
	aliveLabel.Text = string.format("미로 안 %d/%d", aliveCount or 0, totalCount or 0)
end)

objectiveChanged.OnClientEvent:Connect(function(current, required)
	objectiveLabel.Text = string.format("탈출 %d/%d", current or 0, required or 1)
end)

powerupChanged.OnClientEvent:Connect(function(message, duration)
	powerupToken += 1
	local token = powerupToken
	powerupLabel.Text = message or "아이템 없음"

	task.delay(duration or 2.5, function()
		if powerupToken == token then
			powerupLabel.Text = "아이템 없음"
		end
	end)
end)

eventAnnouncement.OnClientEvent:Connect(function(message, duration)
	if message and message ~= "" then
		eventLabel.Text = message
		eventLabel.Visible = true
		task.delay(duration or 3, function()
			if eventLabel.Text == message then
				eventLabel.Visible = false
			end
		end)
	else
		eventLabel.Visible = false
	end
end)

roundResult.OnClientEvent:Connect(function(_, message)
	if message and message ~= "" then
		resultLabel.Text = message
		resultLabel.Visible = true
	else
		resultLabel.Visible = false
		resultLabel.Text = ""
	end
end)

local dangerFadeToken = 0
dangerAlert.OnClientEvent:Connect(function(distance)
	local ratio = math.clamp(1 - (distance / GameConfig.ChaserDangerRadius), 0, 1)
	local targetTransparency = 1 - ratio * 0.88

	dangerFadeToken += 1
	local token = dangerFadeToken
	TweenService:Create(dangerStroke, TweenInfo.new(0.15), {
		Transparency = targetTransparency,
	}):Play()

	task.delay(0.55, function()
		if dangerFadeToken == token then
			TweenService:Create(dangerStroke, TweenInfo.new(0.4), {
				Transparency = 1,
			}):Play()
		end
	end)
end)

announcementEvent.OnClientEvent:Connect(function(title, _, duration)
	if title and title ~= "" then
		pushAnnouncement(title, duration or 2.5)
	end
end)

stateLabel.Text = "대기 중"
timerLabel.Text = "자동 시작"
aliveLabel.Text = "미로 안 0/0"
objectiveLabel.Text = "탈출 0/1"
powerupLabel.Text = "아이템 없음"

-- ── 발각 미터 ─────────────────────────────────────────────────────────────────

local detectionBg = Instance.new("Frame")
detectionBg.Name = "DetectionBg"
detectionBg.AnchorPoint = Vector2.new(0.5, 1)
detectionBg.Position = UDim2.fromScale(0.5, 0.97)
detectionBg.Size = UDim2.fromOffset(320, 22)
detectionBg.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
detectionBg.BackgroundTransparency = 0.2
detectionBg.BorderSizePixel = 0
detectionBg.ZIndex = 5
detectionBg.Parent = gui

Instance.new("UICorner", detectionBg).CornerRadius = UDim.new(0, 5)

local detectionBar = Instance.new("Frame")
detectionBar.Name = "DetectionBar"
detectionBar.Size = UDim2.fromScale(0, 1)
detectionBar.BackgroundColor3 = Color3.fromRGB(90, 255, 90)
detectionBar.BorderSizePixel = 0
detectionBar.ZIndex = 6
detectionBar.Parent = detectionBg

Instance.new("UICorner", detectionBar).CornerRadius = UDim.new(0, 4)

local detectionLabel = Instance.new("TextLabel")
detectionLabel.Size = UDim2.fromScale(1, 1)
detectionLabel.BackgroundTransparency = 1
detectionLabel.Text = "감시"
detectionLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
detectionLabel.TextScaled = true
detectionLabel.Font = Enum.Font.GothamBold
detectionLabel.ZIndex = 7
detectionLabel.Parent = detectionBg

-- ── 발각됨 경고 ───────────────────────────────────────────────────────────────

local detectedBanner = Instance.new("TextLabel")
detectedBanner.Name = "DetectedBanner"
detectedBanner.AnchorPoint = Vector2.new(0.5, 0)
detectedBanner.Position = UDim2.fromScale(0.5, 0.08)
detectedBanner.Size = UDim2.fromOffset(400, 60)
detectedBanner.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
detectedBanner.BackgroundTransparency = 0.1
detectedBanner.BorderSizePixel = 0
detectedBanner.TextColor3 = Color3.fromRGB(255, 255, 255)
detectedBanner.TextScaled = true
detectedBanner.Font = Enum.Font.GothamBlack
detectedBanner.Text = "⚠ 발각됨!"
detectedBanner.Visible = false
detectedBanner.ZIndex = 12
detectedBanner.Parent = gui
Instance.new("UICorner", detectedBanner).CornerRadius = UDim.new(0, 8)

-- ── 난이도 선택 ───────────────────────────────────────────────────────────────

local difficultyPanel = Instance.new("Frame")
difficultyPanel.Name = "DifficultyPanel"
difficultyPanel.AnchorPoint = Vector2.new(0.5, 1)
difficultyPanel.Position = UDim2.fromScale(0.5, 0.92)
difficultyPanel.Size = UDim2.fromOffset(400, 52)
difficultyPanel.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
difficultyPanel.BackgroundTransparency = 0.1
difficultyPanel.BorderSizePixel = 0
difficultyPanel.ZIndex = 4
difficultyPanel.Visible = true
difficultyPanel.Parent = gui
Instance.new("UICorner", difficultyPanel).CornerRadius = UDim.new(0, 8)

local diffLayout = Instance.new("UIListLayout")
diffLayout.FillDirection = Enum.FillDirection.Horizontal
diffLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
diffLayout.VerticalAlignment = Enum.VerticalAlignment.Center
diffLayout.Padding = UDim.new(0, 6)
diffLayout.Parent = difficultyPanel
Instance.new("UIPadding", difficultyPanel).PaddingLeft = UDim.new(0, 8)

local difficultyColors = {
	Easy   = { bg = Color3.fromRGB(46, 160, 78),  text = "쉬움" },
	Normal = { bg = Color3.fromRGB(210, 140, 30),  text = "보통" },
	Hard   = { bg = Color3.fromRGB(180, 40, 40),   text = "어려움" },
}
local difficultyOrder = {"Easy", "Normal", "Hard"}
local diffButtons = {}

for _, key in ipairs(difficultyOrder) do
	local info = difficultyColors[key]
	local btn = Instance.new("TextButton")
	btn.Name = key
	btn.Size = UDim2.fromOffset(116, 36)
	btn.BackgroundColor3 = info.bg
	btn.BackgroundTransparency = 0.3
	btn.BorderSizePixel = 0
	btn.Text = info.text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.ZIndex = 5
	btn.Parent = difficultyPanel
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	diffButtons[key] = btn

	btn.MouseButton1Click:Connect(function()
		setDifficultyEv:FireServer(key)
	end)
end

-- ── 리스폰 화면 ───────────────────────────────────────────────────────────────

local respawnScreen = Instance.new("Frame")
respawnScreen.Name = "RespawnScreen"
respawnScreen.Size = UDim2.fromScale(1, 1)
respawnScreen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
respawnScreen.BackgroundTransparency = 0.5
respawnScreen.BorderSizePixel = 0
respawnScreen.ZIndex = 25
respawnScreen.Visible = false
respawnScreen.Parent = gui

local deadText = Instance.new("TextLabel")
deadText.AnchorPoint = Vector2.new(0.5, 0.4)
deadText.Position = UDim2.fromScale(0.5, 0.4)
deadText.Size = UDim2.fromOffset(500, 80)
deadText.BackgroundTransparency = 1
deadText.Text = "탈락"
deadText.TextColor3 = Color3.fromRGB(220, 40, 40)
deadText.TextScaled = true
deadText.Font = Enum.Font.GothamBlack
deadText.ZIndex = 26
deadText.Parent = respawnScreen

local respawnBtn = Instance.new("TextButton")
respawnBtn.AnchorPoint = Vector2.new(0.5, 0.5)
respawnBtn.Position = UDim2.fromScale(0.5, 0.58)
respawnBtn.Size = UDim2.fromOffset(260, 58)
respawnBtn.BackgroundColor3 = Color3.fromRGB(46, 160, 78)
respawnBtn.BackgroundTransparency = 0.05
respawnBtn.BorderSizePixel = 0
respawnBtn.Text = "리스폰"
respawnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
respawnBtn.TextScaled = true
respawnBtn.Font = Enum.Font.GothamBlack
respawnBtn.ZIndex = 26
respawnBtn.Parent = respawnScreen
Instance.new("UICorner", respawnBtn).CornerRadius = UDim.new(0, 10)

local respawnToken = 0

local function requestRespawn()
	respawnScreen.Visible = false
	respawnRequestEv:FireServer()
end

respawnBtn.MouseButton1Click:Connect(requestRespawn)

-- ── 이벤트 핸들러 ─────────────────────────────────────────────────────────────

local currentDetection = 0

detectionLevelEv.OnClientEvent:Connect(function(level)
	currentDetection = level
	local barColor
	if level < 0.5 then
		barColor = Color3.fromRGB(90, 255, 90)
	elseif level < 0.85 then
		barColor = Color3.fromRGB(255, 200, 40)
	else
		barColor = Color3.fromRGB(255, 50, 50)
	end
	TweenService:Create(detectionBar, TweenInfo.new(0.15), {
		Size = UDim2.fromScale(level, 1),
		BackgroundColor3 = barColor,
	}):Play()
end)

detectionAlertEv.OnClientEvent:Connect(function()
	detectedBanner.Visible = true
	TweenService:Create(detectedBanner, TweenInfo.new(0.1), { BackgroundTransparency = 0 }):Play()
	task.delay(2.5, function()
		TweenService:Create(detectedBanner, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.delay(0.55, function()
			detectedBanner.Visible = false
		end)
	end)
end)

difficultyChangedEv.OnClientEvent:Connect(function(difficulty)
	for key, btn in pairs(diffButtons) do
		local info = difficultyColors[key]
		if key == difficulty then
			btn.BackgroundTransparency = 0
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.BackgroundTransparency = 0.55
			btn.TextColor3 = Color3.fromRGB(180, 180, 180)
		end
	end
end)

playerEliminated.OnClientEvent:Connect(function()
	respawnToken += 1
	local token = respawnToken
	-- 기존 빨간 오버레이
	eliminatedOverlay.Visible = true
	eliminatedOverlay.BackgroundTransparency = 0.35
	task.delay(0.8, function()
		TweenService:Create(eliminatedOverlay, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		task.delay(1.3, function()
			eliminatedOverlay.Visible = false
		end)
	end)
	-- 리스폰 화면 표시
	task.delay(GameConfig.EliminationDisplayTime, function()
		if respawnToken ~= token then
			return
		end
		respawnScreen.Visible = true
		task.delay(0.4, function()
			if respawnToken == token and respawnScreen.Visible then
				requestRespawn()
			end
		end)
	end)
end)

detectionBg.Visible = false

gameStateChanged.OnClientEvent:Connect(function(nextState)
	difficultyPanel.Visible = (nextState == "Waiting")
	detectionBg.Visible     = (nextState == "Playing")
	if nextState == "Finished" or nextState == "Waiting" then
		respawnToken += 1
		respawnScreen.Visible = false
		detectionBar.Size = UDim2.fromScale(0, 1)
	end
end)
