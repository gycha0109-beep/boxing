# TWELVE COUNT — Live UI 작업 환경

## 실행

프로젝트 루트의 `OPEN_LIVE_UI.cmd`를 실행하면 Godot 4.7.2 에디터가 열립니다.

## 에디터 설정

1. 상단 `Game` 화면으로 이동합니다.
2. Game 화면 오른쪽 위 메뉴에서 `Embed Game on Next Play`를 켭니다.
3. 실행 창 배치는 `Main Window` 또는 `Floating Window`를 선택합니다.
4. 크기 설정은 `Fixed Size`를 사용합니다. 프로젝트 기준 화면은 430×932입니다.
5. `Debug > Synchronize Scene Changes`를 켭니다.
6. F6/F5 또는 실행 버튼으로 게임을 시작합니다.

## 수정 반복

1. Godot 상단 `디버그(Debug)` 메뉴에서 `Synchronize Script Changes`를 켭니다.
2. 제가 로컬 GDScript 파일을 수정·저장하면 Godot가 실행 중인 게임에 스크립트 변경을 동기화합니다.
3. 개발용 실행 화면 왼쪽 위의 `UI 갱신` 버튼을 누르면 현재 화면을 다시 그립니다. 버튼이 없는 기존 실행 인스턴스는 최초 1회 F5로 다시 실행해야 합니다.
4. 선택적으로 임베디드 게임 화면에 포커스를 둔 상태에서 `Ctrl+Shift+F8`을 눌러도 됩니다. F8 단독은 Godot의 실행 중지 단축키이므로 사용하지 않습니다.
4. 화면 재구성은 현재 GameState를 그대로 사용합니다. 세이브, 선수, 전적, 상대 선택, 경기 상태를 초기화하지 않습니다.
5. 씬(.tscn) 배치 변경은 별도로 `Debug > Synchronize Scene Changes`를 켜서 반영합니다.

- 게임 바의 `2D` 상호작용 모드에서는 실행 중인 UI 노드를 선택하고 Inspector에서 속성을 확인할 수 있습니다.
- Remote 인스턴스에 직접 가한 변경은 게임 종료 시 사라질 수 있습니다. 보존할 수정은 Local 씬에서 변경하고 씬 동기화를 사용합니다.
- 스크립트 변경으로 현재 실행 흐름이나 노드 구조가 호환되지 않으면 재실행이 필요할 수 있습니다.

## ChatGPT와의 협업

현재 Desktop Commander 연결로 프로젝트 파일 수정, Godot 실행, 로그 확인, 캡처 파일 읽기가 가능합니다. 따라서 화면 캡처를 매번 수동으로 전달하지 않고 제가 수정 후 캡처를 읽어 반복 검수할 수 있습니다.

단, 이 연결 자체가 지속적인 화면 스트리밍이나 ChatGPT의 직접 마우스 제어를 제공하지는 않습니다. 게임 임베딩은 Godot 에디터 기능이며, ChatGPT 쪽은 파일/실행/캡처 기반 협업입니다.

## 안전

이 작업 환경은 별도 세이브 데이터나 초기화 동작을 추가하지 않습니다. 실제 플레이 데이터가 필요한 UI 검수는 기존 테스트용 샌드박스 세이브를 사용합니다.

## 참고

- Godot 4.7 Game Embedding: https://docs.godotengine.org/en/4.7/tutorials/editor/game_embedding.html
