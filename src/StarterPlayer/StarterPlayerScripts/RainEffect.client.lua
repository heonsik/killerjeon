local RunService  = game:GetService("RunService")
local Lighting    = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

-- ── 빗소리 / 천둥 사운드 ──────────────────────────────────────────────────────
-- 재생 안 될 경우 Studio Toolbox → Audio → "rain loop" / "thunder" 검색 후 ID 교체

local rainSound = Instance.new("Sound")
rainSound.Name    = "RainAmbient"
rainSound.SoundId = "rbxassetid://9116153653"   -- heavy rain loop
rainSound.Volume  = 0.38
rainSound.Looped  = true
rainSound.Parent  = SoundService
rainSound:Play()

local thunderSound = Instance.new("Sound")
thunderSound.Name    = "Thunder"
thunderSound.SoundId = "rbxassetid://131300621"  -- Thunder 1 (Creator Store)
thunderSound.Volume  = 0.75
thunderSound.Looped  = false
thunderSound.Parent  = SoundService

-- ── 비 파티클 (카메라 위를 따라다님) ──────────────────────────────────────────

local rainPart = Instance.new("Part")
rainPart.Name         = "RainEmitter"
rainPart.Size         = Vector3.new(340, 1, 340)
rainPart.Anchored     = true
rainPart.CanCollide   = false
rainPart.CastShadow   = false
rainPart.Transparency = 1
rainPart.Parent       = workspace

local emitter = Instance.new("ParticleEmitter")
emitter.Texture            = "rbxasset://textures/particles/smoke_main.png"
emitter.EmissionDirection  = Enum.NormalId.Bottom
emitter.Rate               = 500
emitter.Lifetime           = NumberRange.new(1.1, 1.7)
emitter.Speed              = NumberRange.new(95, 120)
emitter.SpreadAngle        = Vector2.new(5, 5)
emitter.RotSpeed           = NumberRange.new(0, 0)
emitter.Rotation           = NumberRange.new(0, 0)
emitter.VelocityInheritance = 0
emitter.LightInfluence     = 0.55
emitter.LightEmission      = 0.04
emitter.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   0.10),
	NumberSequenceKeypoint.new(0.5, 0.08),
	NumberSequenceKeypoint.new(1,   0.03),
})
emitter.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(195, 220, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(175, 210, 255)),
})
emitter.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   0.60),
	NumberSequenceKeypoint.new(0.5, 0.45),
	NumberSequenceKeypoint.new(1,   0.90),
})
emitter.Parent = rainPart

-- ── 지면 안개 파티클 ──────────────────────────────────────────────────────────

local mistPart = Instance.new("Part")
mistPart.Name         = "MistEmitter"
mistPart.Size         = Vector3.new(160, 1, 160)
mistPart.Anchored     = true
mistPart.CanCollide   = false
mistPart.CastShadow   = false
mistPart.Transparency = 1
mistPart.Parent       = workspace

local mist = Instance.new("ParticleEmitter")
mist.Texture           = "rbxasset://textures/particles/smoke_main.png"
mist.EmissionDirection = Enum.NormalId.Top
mist.Rate              = 12
mist.Lifetime          = NumberRange.new(4, 7)
mist.Speed             = NumberRange.new(1, 3)
mist.SpreadAngle       = Vector2.new(60, 60)
mist.RotSpeed          = NumberRange.new(-8, 8)
mist.Rotation          = NumberRange.new(0, 360)
mist.VelocityInheritance = 0
mist.LightInfluence    = 0.9
mist.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   3),
	NumberSequenceKeypoint.new(0.4, 7),
	NumberSequenceKeypoint.new(1,   10),
})
mist.Color = ColorSequence.new(Color3.fromRGB(180, 195, 220))
mist.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,   0.85),
	NumberSequenceKeypoint.new(0.5, 0.75),
	NumberSequenceKeypoint.new(1,   1),
})
mist.Parent = mistPart

-- ── 카메라 추적 ────────────────────────────────────────────────────────────────

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local p = cam.CFrame.Position
	rainPart.CFrame = CFrame.new(p.X, p.Y + 58, p.Z)
	mistPart.CFrame = CFrame.new(p.X, p.Y - 6,  p.Z)
end)

-- ── 번개 플래시 + 천둥 사운드 동기화 ──────────────────────────────────────────

local baseBrightness = Lighting.Brightness
local nextFlash      = os.clock() + math.random(12, 28)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextFlash then return end
	nextFlash = now + math.random(12, 35)

	task.spawn(function()
		local flashes = math.random(1, 2)
		for i = 1, flashes do
			Lighting.Brightness = baseBrightness + 5
			task.wait(0.04)
			Lighting.Brightness = baseBrightness
			if i < flashes then task.wait(0.07) end
		end
		-- 번개 후 0~0.3초 딜레이로 천둥 (거리감 표현)
		task.wait(math.random() * 0.3)
		thunderSound:Play()
	end)
end)
