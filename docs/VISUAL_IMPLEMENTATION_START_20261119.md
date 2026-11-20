# TWELVE COUNT — 화면 구현 착수 기록 (2026-11-19)

## 실제 코드 확인
- 프로젝트: D:\cha\boxing-web-preview
- 엔진: Godot 4.7.2 stable; 메인 장면 res://scenes/Main.tscn
- 화면 코드: scripts/main_v18_release.gd
- 기준 해상도: 430×932 세로; canvas_items stretch
- 기존 시각 자산: assets/visual/v0.7/arena, fighters, fx, manifest.json
- 기존 전투용 이미지: idle, jab, power, body, guard, counter, hurt, knockdown 자세별 PNG
- 현재 v19 화면 레이어는 레이아웃·타이포·절차적 효과 사용, 생성 레퍼런스 이미지 미반영

## 구현 원칙 — 엔진 변경 금지
React/Phaser/PixiJS로 재작성하지 않고 Godot Control/Container/Theme/TextureRect/StyleBoxTexture를 사용한다.
기존 GameState, 전투 계산, 저장 기능을 유지한다.

## 실제 이미지 재현 작업
1. 레퍼런스에서 배경·복서 초상·프레임·아이콘·텍스트를 구분.
2. 글자가 없는 독립 이미지 자산을 생성해 assets/visual/v1_reference/에 저장.
3. 공통 헤더·하단 내비·버튼·패널·게이지를 금색/남색으로 통일.
4. 선수 프로필을 430×932 실제 브라우저 스크린샷으로 레퍼런스와 비교.
5. 동일 구성요소를 훈련·경기 제안·분석·전술·계체·결과·유산으로 확장.
6. 전투는 기존 자세별 PNG와 피격 모션을 검증한 뒤 그래픽 개선.

## 미완료/차단
- 생성 레퍼런스 이미지의 PC 프로젝트 반입 미확인.
- 글자 박힌 이미지 크롭 대신 무문자 에셋 재생성 필요.
- 전투 캐릭터와 현재 자세별 PNG 그림체 일관성 확인 필요.
- 2세대 전체 완주 미검증.

## 첫 합격 게이트
선수 프로필의 배경·초상·능력치·버튼을 430×932에서 정상 표시,
기존 게임 데이터·메뉴 동작 유지, 레퍼런스 비교 스크린샷 제출.
