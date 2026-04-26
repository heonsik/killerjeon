local GameConfig = {
	MinPlayers = 1,
	MaxPlayers = 10,

	AutoStartDelay = 5,
	PreparationTime = 10,
	RoundTime = 300,
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

	ChaserWalkSpeed = 24,
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
	DroneSpeed = 24,
	DroneTouchRadius = 7,
	DroneTouchCooldown = 1.5,
	DroneChaseRange = 38,
	DroneReturnRange = 56,
	DroneChaseSpeedBonus = 1.25,

	RushEventInterval = 38,
	RushEventDuration = 9,

	MapSize = Vector3.new(1700, 2, 1700),
	WallHeight = 42,
}

return GameConfig
