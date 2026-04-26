# Roblox Studio 확인 방법

## 먼저 할 일

1. Roblox Studio에서 열려 있는 기존 게임 파일 탭을 닫는다.
2. 이 폴더의 `KillerJeon.rbxlx`를 다시 연다.
3. Explorer에서 `Workspace`를 펼친다.
4. `Workspace > Map > RoomFloor`를 선택하고 `F` 키를 눌러 맵으로 초점 이동한다.
5. 그 다음 Play 버튼으로 실제 게임을 테스트한다.

Studio는 이미 열려 있는 `.rbxlx` 파일을 디스크에서 자동 새로고침하지 않는다. 빌드 후에는 반드시 닫고 다시 열어야 최신 맵이 보인다.

## 맵 편집

- 맵은 Play를 누르기 전에도 `Workspace` 안에 들어 있다.
- 새 구조물이나 장식은 `Workspace/Map` 안에 넣는다.
- 새 아이템은 `Workspace/Items` 안에 넣는다.
- 새 시작 위치는 `Workspace/Spawns` 안에 넣는다.
- Play를 눌러도 기존 `Workspace/Map`, `Workspace/Lobby`, `Workspace/Spawns`, `Workspace/Items`는 지워지지 않는다.

## 빌드

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1
```

빌드 후 `KillerJeon.rbxlx` 안에는 실제 `Workspace`가 포함되어야 한다.

## 현재 구현된 주요 기능

- 편집 모드에서 보이는 정적 맵
- 1700x1700 대형 방 맵, 로비, 원거리 스폰 위치
- 외곽 8개 구역과 긴 연결 다리
- 아케이드, 장난감 마을, 도서관, 공장 느낌의 밀집 구역
- 추격 NPC, 순찰 드론, 위험 구역
- 슬라이딩 회피 버튼과 키보드 조작
- 속도 물약, 점프 패드, 보호막, 미끼, 충격 오브, 에너지 코어
- 한글 UI와 라운드 진행 메시지
- Play 시 기존 맵 보존
