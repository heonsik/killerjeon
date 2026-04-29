local GameConfig = {
	MinPlayers = 1,
	MaxPlayers = 10,

	AutoStartDelay = 4,
	PreparationTime = 6,
	RoundTime = 210,
	ResultDisplayTime = 5,
	EliminationDisplayTime = 2.5,

	DefaultWalkSpeed = 16,
	SpeedPotionWalkSpeed = 32,
	SpeedPotionDuration = 5,
	SpeedPotionRespawnTime = 12,
	ShieldDuration = 9,
	DecoyDuration = 8,
	ShockStunDuration = 4,
	ItemRespawnTime = 16,
	RequiredEnergyCores = 3,

	ChaserWalkSpeed = 26,
	ChaserTouchCooldown = 1.25,
	ChaserSpawnDelay = 0.2,
	ChaserRushMultiplier = 1.35,
	ChaserMaxSpeedBonus = 0.35,
	ChaserDangerRadius = 85,
	ChaserSteerCheckDist = 22,

	JumpPadPower = 82,
	JumpPadCooldown = 1.2,

	SlideSpeed = 62,
	SlideDuration = 0.55,
	SlideCooldown = 2.2,
	SlideHipHeightOffset = -1.1,

	DroneCount = 5,
	DroneSpeed = 28,
	DroneTouchRadius = 7,
	DroneTouchCooldown = 1.5,
	DroneChaseRange = 38,
	DroneReturnRange = 56,
	DroneChaseSpeedBonus = 1.25,

	RushEventInterval = 38,
	RushEventDuration = 9,

	MapSize = Vector3.new(1700, 2, 1700),
	WallHeight = 42,

	-- 난이도 프리셋
	DifficultyPresets = {
		Easy   = { ChaserCount = 1, ChaserSpeedMult = 0.85, DroneCount = 3 },
		Normal = { ChaserCount = 2, ChaserSpeedMult = 1.00, DroneCount = 5 },
		Hard   = { ChaserCount = 3, ChaserSpeedMult = 1.18, DroneCount = 5 },
	},
	DefaultDifficulty = "Normal",

	-- 발각 시스템
	DetectionRange = 55,
	DetectionFOVAngle = 65,
	DetectionBuildRate = 0.9,
	DetectionDecayRate = 1.4,
	DetectionAlertDuration = 7,
	DetectionAlertSpeedBonus = 0.25,

	-- 손전등
	FlashlightRange = 65,
	FlashlightFOVAngle = 50,
	FlashlightBlindDuration = 5,
	FlashlightRespawnTime = 25,

	-- 랜덤 출현 킬러
	RandomKillerCount = 3,
	RandomKillerActiveDuration = 40,
	RandomKillerEventInterval = 70,
}

return GameConfig
