local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local GameConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("GameConfig"))

-- ─────────────────────────────── util ────────────────────────────────────────

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function clearFolder(folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function createPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createNeonStrip(parent, name, size, cframe, color)
	local strip = createPart(parent, name, size, cframe, color, Enum.Material.Neon)
	strip.CanCollide = false
	return strip
end

local function createLabel(parent, text, size, studsOffset)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FloatingLabel"
	billboard.Size = size or UDim2.fromOffset(200, 48)
	billboard.StudsOffset = studsOffset or Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.35
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = billboard
end

local function createSpawn(parent, name, position, color)
	local part = createPart(parent, name, Vector3.new(14, 1, 14),
		CFrame.new(position), color or Color3.fromRGB(80, 190, 120), Enum.Material.Neon)
	part.Transparency = 0.35
	part.CanCollide = false
	return part
end

local function createWall(parent, name, size, position, color)
	return createPart(parent, name, size, CFrame.new(position),
		color or Color3.fromRGB(58, 68, 86), Enum.Material.Concrete)
end

-- ────────────────────────────── item helpers ─────────────────────────────────

local function createSpeedPotion(parent, name, position)
	local p = createPart(parent, name, Vector3.new(4, 4, 4),
		CFrame.new(position), Color3.fromRGB(38, 218, 255), Enum.Material.Neon)
	p.Shape = Enum.PartType.Ball
	p.CanCollide = false
	p:SetAttribute("ItemType", "SpeedPotion")
	local light = Instance.new("PointLight")
	light.Brightness = 2.2; light.Range = 20; light.Color = p.Color; light.Parent = p
	createLabel(p, "속도", UDim2.fromOffset(100, 30), Vector3.new(0, 5, 0))
end

local function createPickupOrb(parent, name, itemType, labelText, position, color, size)
	local s = size or 4
	local p = createPart(parent, name, Vector3.new(s, s, s),
		CFrame.new(position), color, Enum.Material.Neon)
	p.Shape = Enum.PartType.Ball
	p.CanCollide = false
	p:SetAttribute("ItemType", itemType)
	local light = Instance.new("PointLight")
	light.Brightness = 2.4; light.Range = 22; light.Color = color; light.Parent = p
	createLabel(p, labelText, UDim2.fromOffset(120, 30), Vector3.new(0, 5, 0))
end

local function createJumpPad(parent, name, position, color)
	local pad = createPart(parent, name, Vector3.new(18, 1, 18),
		CFrame.new(position), color or Color3.fromRGB(77, 255, 121), Enum.Material.Neon)
	pad:SetAttribute("ItemType", "JumpPad")
	local light = Instance.new("PointLight")
	light.Brightness = 1.5; light.Range = 22; light.Color = pad.Color; light.Parent = pad
	createLabel(pad, "점프", UDim2.fromOffset(100, 28), Vector3.new(0, 4, 0))
end

local function createHazardTile(parent, name, position, size)
	local tile = createPart(parent, name, size,
		CFrame.new(position), Color3.fromRGB(255, 58, 70), Enum.Material.Neon)
	tile:SetAttribute("HazardType", "ShockTile")
	tile.Transparency = 0.15
	tile.CanCollide = false
	local light = Instance.new("PointLight")
	light.Brightness = 1.2; light.Range = 25; light.Color = tile.Color; light.Parent = tile
end

-- ───────────────────────────── floor & walls ─────────────────────────────────

local function addFloorPatterns(mapFolder, hx, hz)
	createNeonStrip(mapFolder, "RunwayX", Vector3.new(hx*2-60, 0.25, 5),
		CFrame.new(0, 1.18, 0), Color3.fromRGB(255, 215, 74))
	createNeonStrip(mapFolder, "RunwayZ", Vector3.new(5, 0.25, hz*2-60),
		CFrame.new(0, 1.2, 0), Color3.fromRGB(255, 215, 74))

	local xLines = {-650, -430, -215, 215, 430, 650}
	local zLines = {-650, -430, -215, 215, 430, 650}
	local colors = {
		Color3.fromRGB(112, 210, 255), Color3.fromRGB(255, 95, 95),
		Color3.fromRGB(119, 255, 157), Color3.fromRGB(178, 125, 255),
	}
	for i, x in ipairs(xLines) do
		createNeonStrip(mapFolder, "FloorX"..i, Vector3.new(3, 0.3, hz*2-50),
			CFrame.new(x, 1.22, 0), colors[(i-1) % #colors + 1])
	end
	for i, z in ipairs(zLines) do
		createNeonStrip(mapFolder, "FloorZ"..i, Vector3.new(hx*2-50, 0.3, 3),
			CFrame.new(0, 1.24, z), colors[i % #colors + 1])
	end

	local edgeC = Color3.fromRGB(255, 80, 80)
	createNeonStrip(mapFolder, "EdgeN", Vector3.new(hx*2-20,0.4,2), CFrame.new(0,1.26,-hz+10), edgeC)
	createNeonStrip(mapFolder, "EdgeS", Vector3.new(hx*2-20,0.4,2), CFrame.new(0,1.26, hz-10), edgeC)
	createNeonStrip(mapFolder, "EdgeW", Vector3.new(2,0.4,hz*2-20), CFrame.new(-hx+10,1.26,0), edgeC)
	createNeonStrip(mapFolder, "EdgeE", Vector3.new(2,0.4,hz*2-20), CFrame.new( hx-10,1.26,0), edgeC)
end

local function addWallPanels(mapFolder, hx, hz, wallH)
	local colors = {
		Color3.fromRGB(255,94,110), Color3.fromRGB(69,201,255),
		Color3.fromRGB(255,215,74), Color3.fromRGB(95,237,139), Color3.fromRGB(178,125,255),
	}
	local pw = 160
	for i = 1, math.floor(hx*2/pw) do
		local x = -hx + (i-0.5)*pw
		createPart(mapFolder, "PanelN"..i, Vector3.new(pw-4,18,1), CFrame.new(x,wallH/2,-hz+2.2), colors[(i-1)%#colors+1])
		createPart(mapFolder, "PanelS"..i, Vector3.new(pw-4,18,1), CFrame.new(x,wallH/2, hz-2.2), colors[    i %#colors+1])
	end
	for i = 1, math.floor(hz*2/pw) do
		local z = -hz + (i-0.5)*pw
		createPart(mapFolder, "PanelW"..i, Vector3.new(1,18,pw-4), CFrame.new(-hx+2.2,wallH/2,z), colors[(i+1)%#colors+1])
		createPart(mapFolder, "PanelE"..i, Vector3.new(1,18,pw-4), CFrame.new( hx-2.2,wallH/2,z), colors[(i+2)%#colors+1])
	end
end

-- ────────────────────────── NW 구역: 책장 미로 ────────────────────────────────

local function buildNWMaze(mapFolder)
	local c1 = Color3.fromRGB(102, 73, 52)
	local c2 = Color3.fromRGB(142, 104, 72)
	-- z = -760~-380, x = -830~-350 구역 지그재그 책장
	local rows = {-760, -660, -560, -460, -380}
	for i, z in ipairs(rows) do
		if i % 2 == 1 then
			createPart(mapFolder, "Maze1_"..i.."L", Vector3.new(240,30,20), CFrame.new(-700,16,z), c1, Enum.Material.Wood)
			createPart(mapFolder, "Maze1_"..i.."R", Vector3.new(140,30,20), CFrame.new(-420,16,z), c2, Enum.Material.Wood)
		else
			createPart(mapFolder, "Maze2_"..i.."L", Vector3.new(140,30,20), CFrame.new(-790,16,z), c2, Enum.Material.Wood)
			createPart(mapFolder, "Maze2_"..i.."R", Vector3.new(240,30,20), CFrame.new(-510,16,z), c1, Enum.Material.Wood)
		end
	end
	-- 낮은 엄폐 상자
	for i, pos in ipairs({
		Vector3.new(-630,10,-710), Vector3.new(-480,10,-610),
		Vector3.new(-740,10,-520), Vector3.new(-590,10,-430),
	}) do
		createPart(mapFolder, "MazeCrate"..i, Vector3.new(50,20,50),
			CFrame.new(pos), Color3.fromRGB(130,100,70), Enum.Material.WoodPlanks)
	end
end

-- ───────────────────────── NE 구역: 산업 창고 ────────────────────────────────

local function buildNECargo(mapFolder)
	local c1 = Color3.fromRGB(120, 90, 62)
	local c2 = Color3.fromRGB(78, 62, 44)
	local clusters = {
		{Vector3.new(450,20,-760), Vector3.new(200,40,90)},
		{Vector3.new(640,24,-660), Vector3.new(120,50,70)},
		{Vector3.new(780,17,-500), Vector3.new(90,36,160)},
		{Vector3.new(550,14,-480), Vector3.new(160,30,80)},
		{Vector3.new(720,20,-360), Vector3.new(140,42,100)},
		{Vector3.new(440,12,-380), Vector3.new(80,26,80)},
	}
	for i, d in ipairs(clusters) do
		createPart(mapFolder, "Cargo"..i, d[2], CFrame.new(d[1]), i%2==0 and c1 or c2, Enum.Material.SmoothPlastic)
	end
	createPart(mapFolder, "CargoWallA", Vector3.new(8,38,300),  CFrame.new(350,20,-600), Color3.fromRGB(55,65,80), Enum.Material.Concrete)
	createPart(mapFolder, "CargoWallB", Vector3.new(300,38,8),  CFrame.new(600,20,-350), Color3.fromRGB(55,65,80), Enum.Material.Concrete)
	createPart(mapFolder, "CargoPlatform", Vector3.new(180,8,100), CFrame.new(580,31,-650), Color3.fromRGB(62,72,88), Enum.Material.Metal)
	createPart(mapFolder, "CargoRamp", Vector3.new(80,4,50),
		CFrame.new(480,23,-650)*CFrame.Angles(0,0,math.rad(-14)), Color3.fromRGB(110,88,64), Enum.Material.WoodPlanks)
end

-- ────────────────────────── SW 구역: 거대 침실 ────────────────────────────────

local function buildSWBedroom(mapFolder)
	createPart(mapFolder, "BedBase",    Vector3.new(300,10,180), CFrame.new(-600,6,600),  Color3.fromRGB(72,110,197), Enum.Material.Fabric)
	createPart(mapFolder, "BedPillow",  Vector3.new(110,12,160), CFrame.new(-770,14,600), Color3.fromRGB(244,244,238),Enum.Material.Fabric)
	createPart(mapFolder, "BedBlanket", Vector3.new(130,6,170),  CFrame.new(-540,14,600), Color3.fromRGB(255,90,90),  Enum.Material.Fabric)
	createPart(mapFolder, "BedFrame",   Vector3.new(320,16,200), CFrame.new(-600,1,600),  Color3.fromRGB(90,64,44),   Enum.Material.Wood)
	createPart(mapFolder, "WardrobeL",  Vector3.new(90,55,110),  CFrame.new(-440,28,760), Color3.fromRGB(104,72,52),  Enum.Material.Wood)
	createPart(mapFolder, "WardrobeR",  Vector3.new(90,55,110),  CFrame.new(-540,28,760), Color3.fromRGB(117,82,58),  Enum.Material.Wood)
	createNeonStrip(mapFolder, "WardrobeGlow", Vector3.new(4,44,3), CFrame.new(-490,28,706), Color3.fromRGB(255,215,74))
	createPart(mapFolder, "DeskTopSW",  Vector3.new(220,10,100), CFrame.new(-730,22,390), Color3.fromRGB(142,104,72), Enum.Material.WoodPlanks)
	createPart(mapFolder, "DeskLegSW1", Vector3.new(14,22,14),   CFrame.new(-820,12,410), Color3.fromRGB(105,76,52),  Enum.Material.Wood)
	createPart(mapFolder, "DeskLegSW2", Vector3.new(14,22,14),   CFrame.new(-640,12,410), Color3.fromRGB(105,76,52),  Enum.Material.Wood)
	createPart(mapFolder, "SofaBase",  Vector3.new(220,16,90),   CFrame.new(-580,9,440),  Color3.fromRGB(80,160,125), Enum.Material.Fabric)
	createPart(mapFolder, "SofaBack",  Vector3.new(228,32,20),   CFrame.new(-580,18,396), Color3.fromRGB(64,130,105), Enum.Material.Fabric)
	createPart(mapFolder, "SofaArmL",  Vector3.new(22,26,94),    CFrame.new(-700,15,440), Color3.fromRGB(64,130,105), Enum.Material.Fabric)
	createPart(mapFolder, "SofaArmR",  Vector3.new(22,26,94),    CFrame.new(-460,15,440), Color3.fromRGB(64,130,105), Enum.Material.Fabric)
end

-- ───────────────────────── SE 구역: 장난감 공장 ──────────────────────────────

local function buildSEPlayroom(mapFolder)
	local blocks = {
		{Vector3.new(440,20,660),  Vector3.new(120,42,120), Color3.fromRGB(255,99,99)},
		{Vector3.new(600,16,740),  Vector3.new(160,34,100), Color3.fromRGB(90,190,255)},
		{Vector3.new(760,24,600),  Vector3.new(100,50,100), Color3.fromRGB(120,235,150)},
		{Vector3.new(500,12,520),  Vector3.new(180,26,80),  Color3.fromRGB(255,214,84)},
		{Vector3.new(700,18,480),  Vector3.new(100,38,140), Color3.fromRGB(178,125,255)},
		{Vector3.new(380,10,760),  Vector3.new(120,22,80),  Color3.fromRGB(255,135,84)},
		{Vector3.new(830,14,370),  Vector3.new(80,30,120),  Color3.fromRGB(255,220,90)},
	}
	for i, d in ipairs(blocks) do
		createPart(mapFolder, "ToyBlock"..i, d[2], CFrame.new(d[1]), d[3], Enum.Material.Plastic)
	end
	createPart(mapFolder, "ToyBoxBig", Vector3.new(160,24,130), CFrame.new(640,13,650), Color3.fromRGB(235,116,87), Enum.Material.Plastic)
	createPart(mapFolder, "ToyBoxLid", Vector3.new(168,10,138), CFrame.new(640,29,650), Color3.fromRGB(255,193,87), Enum.Material.Plastic)
end

-- ─────────────────────────── 중앙 허브 플랫폼 ────────────────────────────────

local function buildCentralHub(mapFolder)
	createPart(mapFolder, "CenterPlatform", Vector3.new(320,14,320), CFrame.new(0,8,0), Color3.fromRGB(44,48,62), Enum.Material.Metal)
	for _, d in ipairs({
		{"RingN", Vector3.new(328,1.5,3), CFrame.new(0,16,-162)},
		{"RingS", Vector3.new(328,1.5,3), CFrame.new(0,16, 162)},
		{"RingW", Vector3.new(3,1.5,328), CFrame.new(-162,16,0)},
		{"RingE", Vector3.new(3,1.5,328), CFrame.new( 162,16,0)},
	}) do
		createNeonStrip(mapFolder, "CPlatform"..d[1], d[2], d[3], Color3.fromRGB(255,65,65))
	end

	local rampC = Color3.fromRGB(130, 96, 74)
	local rampP = math.rad(9)
	createPart(mapFolder, "RampN", Vector3.new(120,4,180), CFrame.new(0,4,-250)*CFrame.Angles(-rampP,0,0), rampC, Enum.Material.WoodPlanks)
	createPart(mapFolder, "RampS", Vector3.new(120,4,180), CFrame.new(0,4, 250)*CFrame.Angles( rampP,0,0), rampC, Enum.Material.WoodPlanks)
	createPart(mapFolder, "RampW", Vector3.new(180,4,120), CFrame.new(-250,4,0)*CFrame.Angles(0,0, rampP), rampC, Enum.Material.WoodPlanks)
	createPart(mapFolder, "RampE", Vector3.new(180,4,120), CFrame.new( 250,4,0)*CFrame.Angles(0,0,-rampP), rampC, Enum.Material.WoodPlanks)

	createPart(mapFolder, "HighBridgeEW", Vector3.new(500,6,60),  CFrame.new(0,38,0), Color3.fromRGB(62,68,84), Enum.Material.Metal)
	createPart(mapFolder, "HighBridgeNS", Vector3.new(60,6,500),  CFrame.new(0,38,0), Color3.fromRGB(62,68,84), Enum.Material.Metal)
	createNeonStrip(mapFolder, "BridgeGlowEW", Vector3.new(504,1.5,2), CFrame.new(0,42,0),   Color3.fromRGB(69,201,255))
	createNeonStrip(mapFolder, "BridgeGlowNS", Vector3.new(2,1.5,504), CFrame.new(0,42.2,0), Color3.fromRGB(255,215,74))

	createPart(mapFolder, "TunnelN", Vector3.new(28,22,250), CFrame.new(0,12,-480), Color3.fromRGB(56,84,112), Enum.Material.Glass)
	createPart(mapFolder, "TunnelS", Vector3.new(28,22,250), CFrame.new(0,12, 480), Color3.fromRGB(56,84,112), Enum.Material.Glass)
	createNeonStrip(mapFolder, "TunnelNGlow", Vector3.new(2,2,248), CFrame.new(0,24,-480), Color3.fromRGB(178,125,255))
	createNeonStrip(mapFolder, "TunnelSGlow", Vector3.new(2,2,248), CFrame.new(0,24, 480), Color3.fromRGB(178,125,255))
end

-- ──────────────────────── 복도 엄폐물 ───────────────────────────────────────

local function addCorridorCover(mapFolder)
	local pillarC = Color3.fromRGB(50, 58, 74)
	for i, pos in ipairs({
		Vector3.new(-150,21,-500), Vector3.new( 150,21,-500),
		Vector3.new(-150,21,-680), Vector3.new( 150,21,-680),
		Vector3.new(-150,21, 500), Vector3.new( 150,21, 500),
		Vector3.new(-150,21, 680), Vector3.new( 150,21, 680),
		Vector3.new(-500,21,-150), Vector3.new(-500,21, 150),
		Vector3.new(-680,21,-150), Vector3.new(-680,21, 150),
		Vector3.new( 500,21,-150), Vector3.new( 500,21, 150),
		Vector3.new( 680,21,-150), Vector3.new( 680,21, 150),
	}) do
		createPart(mapFolder, "Pillar"..i, Vector3.new(26,44,26), CFrame.new(pos), pillarC, Enum.Material.Concrete)
	end

	local barrierC = Color3.fromRGB(68, 78, 96)
	for i, d in ipairs({
		{Vector3.new(-420,12,-250), Vector3.new(140,26,22)},
		{Vector3.new( 420,12, 250), Vector3.new(140,26,22)},
		{Vector3.new(-250,12, 420), Vector3.new(22,26,140)},
		{Vector3.new( 250,12,-420), Vector3.new(22,26,140)},
		{Vector3.new(-600,12,  50), Vector3.new(22,26,120)},
		{Vector3.new( 600,12, -50), Vector3.new(22,26,120)},
		{Vector3.new(  50,12,-600), Vector3.new(120,26,22)},
		{Vector3.new( -50,12, 600), Vector3.new(120,26,22)},
	}) do
		createPart(mapFolder, "Barrier"..i, d[2], CFrame.new(d[1]), barrierC, Enum.Material.SmoothPlastic)
	end

	for i, pos in ipairs({
		Vector3.new(-350,12,-250), Vector3.new( 350,12, 250),
		Vector3.new(-250,12, 350), Vector3.new( 250,12,-350),
		Vector3.new( 750,12,  80), Vector3.new(-750,12, -80),
		Vector3.new(  80,12,-750), Vector3.new( -80,12, 750),
	}) do
		createPart(mapFolder, "ScatCrate"..i, Vector3.new(50,26,50),
			CFrame.new(pos)*CFrame.Angles(0,math.rad(i*22),0), Color3.fromRGB(140,105,68), Enum.Material.WoodPlanks)
	end
end

-- ─────────────────────────── 세트피스 & 위험구역 ─────────────────────────────

local function addSetPieces(mapFolder)
	createPart(mapFolder, "GateBase",     Vector3.new(160,28,8), CFrame.new(0,15,-800),   Color3.fromRGB(26,32,46),   Enum.Material.Metal)
	createNeonStrip(mapFolder, "GateL",   Vector3.new(4,36,4),   CFrame.new(-84,19,-797), Color3.fromRGB(38,218,255))
	createNeonStrip(mapFolder, "GateR",   Vector3.new(4,36,4),   CFrame.new( 84,19,-797), Color3.fromRGB(38,218,255))
	createNeonStrip(mapFolder, "GateTop", Vector3.new(178,4,4),  CFrame.new(0,38,-797),   Color3.fromRGB(255,215,74))
	local gp = createPart(mapFolder, "GateLabelAnchor", Vector3.new(1,1,1), CFrame.new(0,40,-797), Color3.fromRGB(255,215,74), Enum.Material.Neon)
	gp.Transparency = 1; gp.CanCollide = false
	createLabel(gp, "코어 3개 수집", UDim2.fromOffset(260,46), Vector3.new(0,0,0))

	for i, z in ipairs({-600, -300, 300, 600}) do
		createPart(mapFolder, "LaserPostL"..i, Vector3.new(10,24,10), CFrame.new(-22,13,z), Color3.fromRGB(28,33,42), Enum.Material.Metal)
		createPart(mapFolder, "LaserPostR"..i, Vector3.new(10,24,10), CFrame.new( 22,13,z), Color3.fromRGB(28,33,42), Enum.Material.Metal)
		local beam = createNeonStrip(mapFolder, "Laser"..i, Vector3.new(44,1.5,1.5), CFrame.new(0,14,z), Color3.fromRGB(255,65,65))
		beam.Transparency = 0.2
	end

	createHazardTile(mapFolder, "ShockA", Vector3.new(-500,1.36,-100), Vector3.new(100,0.4,200))
	createHazardTile(mapFolder, "ShockB", Vector3.new( 500,1.36, 100), Vector3.new(100,0.4,200))
	createHazardTile(mapFolder, "ShockC", Vector3.new(-100,1.36, 500), Vector3.new(200,0.4,100))
	createHazardTile(mapFolder, "ShockD", Vector3.new( 100,1.36,-500), Vector3.new(200,0.4,100))
end

-- ──────────────────────── 조명 ───────────────────────────────────────────────

local function addLights(mapFolder)
	for i, d in ipairs({
		{Vector3.new(-550,41,-550), Color3.fromRGB(255,62,62)},
		{Vector3.new( 550,41,-550), Color3.fromRGB(69,201,255)},
		{Vector3.new(-550,41, 550), Color3.fromRGB(255,215,74)},
		{Vector3.new( 550,41, 550), Color3.fromRGB(119,255,157)},
	}) do
		createPart(mapFolder, "AlarmBase"..i, Vector3.new(10,3,10), CFrame.new(d[1]), Color3.fromRGB(30,30,36), Enum.Material.Metal)
		local lamp = createPart(mapFolder, "AlarmLamp"..i, Vector3.new(6,6,6), CFrame.new(d[1]+Vector3.new(0,5,0)), d[2], Enum.Material.Neon)
		lamp.Shape = Enum.PartType.Ball; lamp.CanCollide = false
		local pt = Instance.new("PointLight"); pt.Brightness = 3; pt.Range = 100; pt.Color = d[2]; pt.Parent = lamp
	end
	createPart(mapFolder, "CeilRig", Vector3.new(700,3,12), CFrame.new(0,43,0), Color3.fromRGB(38,42,54), Enum.Material.Metal)
	for i, x in ipairs({-290,-145,0,145,290}) do
		local tube = createNeonStrip(mapFolder, "CeilTube"..i, Vector3.new(38,1.5,4), CFrame.new(x,42,0), Color3.fromRGB(210,240,255))
		local pt = Instance.new("PointLight"); pt.Brightness = 1.6; pt.Range = 120; pt.Color = tube.Color; pt.Parent = tube
	end
end

-- ───────────────────────────── 로비 ─────────────────────────────────────────

local function buildLobby(lobbyFolder, spawnsFolder)
	local lz = -1080
	createPart(lobbyFolder, "LobbyFloor",    Vector3.new(340,2,240),  CFrame.new(0,0,lz),      Color3.fromRGB(48,64,82),  Enum.Material.SmoothPlastic)
	createPart(lobbyFolder, "LobbyBackWall", Vector3.new(344,32,4),   CFrame.new(0,17,lz-120), Color3.fromRGB(45,53,68),  Enum.Material.Concrete)
	createPart(lobbyFolder, "LobbyLeftWall", Vector3.new(4,32,248),   CFrame.new(-170,17,lz),  Color3.fromRGB(45,53,68),  Enum.Material.Concrete)
	createPart(lobbyFolder, "LobbyRightWall",Vector3.new(4,32,248),   CFrame.new( 170,17,lz),  Color3.fromRGB(45,53,68),  Enum.Material.Concrete)

	local button = createPart(lobbyFolder, "StartButton", Vector3.new(26,4,18),
		CFrame.new(0,3,lz+80), Color3.fromRGB(255,197,73), Enum.Material.Neon)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StartPrompt"; prompt.ActionText = "시작"; prompt.ObjectText = "킬러진"
	prompt.HoldDuration = 0.2; prompt.MaxActivationDistance = 18; prompt.Parent = button

	local gate = createPart(lobbyFolder, "LobbyGate", Vector3.new(100,36,4),
		CFrame.new(0,19,lz+110), Color3.fromRGB(28,33,42), Enum.Material.Metal)
	createNeonStrip(lobbyFolder, "GateGlowTop",   Vector3.new(110,3,3),  CFrame.new(0,38,lz+108),   Color3.fromRGB(255,68,88))
	createNeonStrip(lobbyFolder, "GateGlowLeft",  Vector3.new(3,34,3),   CFrame.new(-54,20,lz+108), Color3.fromRGB(69,201,255))
	createNeonStrip(lobbyFolder, "GateGlowRight", Vector3.new(3,34,3),   CFrame.new( 54,20,lz+108), Color3.fromRGB(69,201,255))
	createLabel(gate, "킬러진", UDim2.fromOffset(280,64), Vector3.new(0,5,0))

	createSpawn(spawnsFolder, "LobbySpawn", Vector3.new(0,5,lz-60), Color3.fromRGB(69,201,255))
end

-- ─────────────────────────────── 방 빌드 ─────────────────────────────────────

local function buildRoom(mapFolder, spawnsFolder, itemsFolder)
	local ms   = GameConfig.MapSize
	local hx   = ms.X / 2
	local hz   = ms.Z / 2
	local wallH = GameConfig.WallHeight

	createPart(mapFolder, "RoomFloor", ms, CFrame.new(0,0,0), Color3.fromRGB(41,47,62), Enum.Material.SmoothPlastic)
	createWall(mapFolder, "WallN", Vector3.new(ms.X+8,wallH,4), Vector3.new(0,wallH/2,-hz))
	createWall(mapFolder, "WallS", Vector3.new(ms.X+8,wallH,4), Vector3.new(0,wallH/2, hz))
	createWall(mapFolder, "WallW", Vector3.new(4,wallH,ms.Z+8), Vector3.new(-hx,wallH/2,0))
	createWall(mapFolder, "WallE", Vector3.new(4,wallH,ms.Z+8), Vector3.new( hx,wallH/2,0))

	addFloorPatterns(mapFolder, hx, hz)
	addWallPanels(mapFolder, hx, hz, wallH)
	buildNWMaze(mapFolder)
	buildNECargo(mapFolder)
	buildSWBedroom(mapFolder)
	buildSEPlayroom(mapFolder)
	buildCentralHub(mapFolder)
	addCorridorCover(mapFolder)
	addSetPieces(mapFolder)
	addLights(mapFolder)

	createSpawn(spawnsFolder, "GameSpawn",   Vector3.new(-750,5,-750), Color3.fromRGB(69,201,255))
	createSpawn(spawnsFolder, "ChaserSpawn", Vector3.new( 750,5, 750), Color3.fromRGB(255,75,75))

	-- 점프패드
	createJumpPad(itemsFolder, "JumpPad_Center", Vector3.new(  0,16.5,  0))
	createJumpPad(itemsFolder, "JumpPad_NE",     Vector3.new(650,1.9,-650), Color3.fromRGB(255,215,74))
	createJumpPad(itemsFolder, "JumpPad_SW",     Vector3.new(-650,1.9,650), Color3.fromRGB(255,215,74))
	createJumpPad(itemsFolder, "JumpPad_Bridge", Vector3.new(  0,42, 140))

	-- 속도 포션 8개
	for i, pos in ipairs({
		Vector3.new(-620,5,-300), Vector3.new( 620,5, 300),
		Vector3.new(-300,5, 620), Vector3.new( 300,5,-620),
		Vector3.new(-750,5,-400), Vector3.new( 750,5, 400),
		Vector3.new(   0,16, 220), Vector3.new(  0,16,-220),
	}) do
		createSpeedPotion(itemsFolder, "SpeedPotion"..i, pos)
	end

	-- 보호막 오브 4개
	createPickupOrb(itemsFolder, "Shield1", "ShieldOrb", "보호막", Vector3.new(-800,5,-300), Color3.fromRGB(92,255,186), 5)
	createPickupOrb(itemsFolder, "Shield2", "ShieldOrb", "보호막", Vector3.new( 800,5, 300), Color3.fromRGB(92,255,186), 5)
	createPickupOrb(itemsFolder, "Shield3", "ShieldOrb", "보호막", Vector3.new(-300,5, 800), Color3.fromRGB(92,255,186), 5)
	createPickupOrb(itemsFolder, "Shield4", "ShieldOrb", "보호막", Vector3.new( 300,5,-800), Color3.fromRGB(92,255,186), 5)

	-- 미끼 비콘 3개
	createPickupOrb(itemsFolder, "Decoy1", "DecoyBeacon", "미끼", Vector3.new(-200,16, 100), Color3.fromRGB(178,125,255), 5)
	createPickupOrb(itemsFolder, "Decoy2", "DecoyBeacon", "미끼", Vector3.new( 200,16,-100), Color3.fromRGB(178,125,255), 5)
	createPickupOrb(itemsFolder, "Decoy3", "DecoyBeacon", "미끼", Vector3.new(   0,5,-750),  Color3.fromRGB(178,125,255), 5)

	-- 충격 오브 4개
	createPickupOrb(itemsFolder, "Shock1", "ShockOrb", "충격", Vector3.new(   0,5,-800), Color3.fromRGB(255,224,92), 5)
	createPickupOrb(itemsFolder, "Shock2", "ShockOrb", "충격", Vector3.new(   0,5, 800), Color3.fromRGB(255,224,92), 5)
	createPickupOrb(itemsFolder, "Shock3", "ShockOrb", "충격", Vector3.new(-800,5,   0), Color3.fromRGB(255,224,92), 5)
	createPickupOrb(itemsFolder, "Shock4", "ShockOrb", "충격", Vector3.new( 800,5,   0), Color3.fromRGB(255,224,92), 5)

	-- 에너지 코어 3개 (NW미로, 중앙다리, SE장난감)
	createPickupOrb(itemsFolder, "Core1", "EnergyCore", "코어", Vector3.new(-650,16,-650), Color3.fromRGB(255,88,118), 6.5)
	createPickupOrb(itemsFolder, "Core2", "EnergyCore", "코어", Vector3.new(   0,42,   0), Color3.fromRGB(255,88,118), 6.5)
	createPickupOrb(itemsFolder, "Core3", "EnergyCore", "코어", Vector3.new( 640,16, 640), Color3.fromRGB(255,88,118), 6.5)
end

-- ─────────────────────────── 조명 설정 ───────────────────────────────────────

local function configureLighting()
	Lighting.ClockTime = 20.7
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(40, 45, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(18, 22, 32)
	Lighting.FogColor = Color3.fromRGB(30, 36, 48)
	Lighting.FogStart = 400
	Lighting.FogEnd = 1600
end

-- ───────────────────────────── 실행 ──────────────────────────────────────────

local lobbyFolder   = ensureFolder(Workspace, "Lobby")
local mapFolder     = ensureFolder(Workspace, "Map")
local spawnsFolder  = ensureFolder(Workspace, "Spawns")
local itemsFolder   = ensureFolder(Workspace, "Items")
ensureFolder(Workspace, "Effects")

clearFolder(lobbyFolder)
clearFolder(mapFolder)
clearFolder(spawnsFolder)
clearFolder(itemsFolder)

configureLighting()
buildLobby(lobbyFolder, spawnsFolder)
buildRoom(mapFolder, spawnsFolder, itemsFolder)

Workspace.Gravity = 196.2
