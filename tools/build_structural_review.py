from pathlib import Path
from html import escape
import json,zipfile
root=Path(r'D:\cha\boxing-current\docs\ui-audit')
baseline=root/'full-career-20261123'
final=root/'full-career-ui-reworked-verified'
old=json.loads((baseline/'manifest.json').read_text(encoding='utf-8'))['screenshots']
new=json.loads((final/'manifest.json').read_text(encoding='utf-8'))['screenshots']
pairs=[(0,0,'타이틀'),(1,1,'첫 실행'),(2,2,'튜토리얼'),(3,3,'선수 생성'),
       (4,4,'재능 추첨'),(7,7,'훈련 선택'),(9,9,'선수 프로필'),
       (11,11,'커리어 기록'),(12,12,'장비 상점'),(14,14,'상대 선택'),
       (16,16,'상대 분석'),(17,17,'계체'),(18,18,'전투'),
       (20,21,'경기 결과'),(23,23,'경기 이후 캠프')]
def img(ref,folder):
 return escape(folder+'/'+ref['file'],quote=True)
cards=[]
for i,j,title in pairs:
 if i>=len(old) or j>=len(new):continue
 aa=img(old[i],baseline.name);bb=img(new[j],final.name)
 cards.append(f'<section class="pair"><h3>{escape(title)}</h3><div class="columns"><figure><a href="{aa}"><img loading="lazy" src="{aa}"></a><figcaption>기존 레이아웃</figcaption></figure><figure><a href="{bb}"><img loading="lazy" src="{bb}"></a><figcaption>정보 구조 수정본</figcaption></figure></div></section>')
gallery=[]
for k,x in enumerate(new):
 src=img(x,final.name)
 phase=escape(str(x.get('phase','')))
 label=escape(str(x.get('title','')))
 gallery.append(f'<figure><a href="{src}"><img loading="lazy" src="{src}"></a><figcaption>{k:02d}. {label} <small>{phase}</small></figcaption></figure>')
css='''body{font-family:system-ui,"Malgun Gothic",sans-serif;background:#0c121a;color:#f2eadc;margin:0}header{background:#15212c;border-bottom:2px solid #a98550;padding:26px}main{max-width:1160px;margin:auto;padding:20px}h1{color:#f3d08d;margin:0}h2{color:#f3d08d;margin-top:40px}h3{margin:0 0 13px;font-size:18px}p{line-height:1.65;color:#c5ced4}.pairs{display:grid;grid-template-columns:repeat(auto-fill,minmax(430px,1fr));gap:18px}.pair{background:#16202b;padding:14px;border:1px solid #645440;border-radius:12px}.columns{display:flex;gap:14px}.columns figure{width:50%;margin:0}.columns img{width:100%;border-radius:5px}.columns figcaption{font-size:12px;color:#efc784;padding-top:6px}.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(155px,1fr));gap:14px}.gallery figure{margin:0;background:#1b2530;padding:6px;border-radius:5px}.gallery img{width:100%}.gallery figcaption{font-size:12px;line-height:1.5}.gallery small{display:block;color:#acb7c2}'''
html='''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Twelve Count - UI 구조 개편 검수</title><style>'''+css+'''</style></head><body><header><h1>TWELVE COUNT — UI 구조 개편 전후 비교</h1><p>기존 37장 ↔ 최신 42장. 실제 Godot 4.7.2 화면을 430×932 해상도로 캡처했습니다.<br>커리어 진행은 실제 게임 상태 전환을 이용하되 경기 승패는 테스트 시뮬레이션으로 처리했습니다. 이벤트가 매번 달라 화면 수가 다릅니다.</p></header><main><h2>주요 화면 전후 비교</h2><div class="pairs">'''+''.join(cards)+'''</div><h2>최신 전체 화면 42장</h2><div class="gallery">'''+''.join(gallery)+'''</div></main></body></html>'''
out=root/'UI_Structure_Before_After.html'
out.write_text(html,encoding='utf-8')
notes=root/'UI_Structure_Changes.md'
notes.write_text('''# Twelve Count — 실제 UI 구조 개편 기록

- 기준 프로젝트: D:\\cha\\boxing-current, Godot 4.7.2.
- 비교: 기존 37장, 개편 검증 42장, 430x932.
- 선수 생성: 스타일별 이미지/설명/효과/선택의 내부 간격과 크기 조정.
- 훈련: 카드 내부 설명 2줄 제한, 증가 효과와 부작용 그룹 분리, 버튼 폭 통일.
- 상대 선택: 초상화/상대 정보/보상/분석/선택의 구획·간격 정돈.
- 상대 분석: 작전 카드 2열에서 읽기 쉬운 1열로 변경.
- 프로필: 초상화 비율과 정보 폭 조정, 능력치·설명 정돈.
- 커리어 기록: 타이틀 진척 카드 3열→2열, 수치 카드 간격 변경.
- 상점: 가격을 상품명 아래로 이동, 변화량과 구매 동작 구분.
- 경기: 공격 예고/조언 및 행동 버튼 간격 조정.
- 경기 결과: 순수익·랭킹을 상단에 분리, 상세 정산은 아래 유지.
- 이벤트: 변화량을 수치별로 분리해 행 간격 확대.
- 체육관 모금: 보상→설명→지금 보기/나중에 선택 구조로 개편.
- 시즌 계약: 이름/보상배율/설명/선택을 세로 구획으로 정리.
- 은퇴 유산: 3열을 1열의 상세 후보 카드로 변경.
- 튜토리얼: 안내 상자를 선택지의 반대쪽 화면에 배치하고 암막 농도 완화.

검증: 커리어 7경기(테스트용 결과 시뮬레이션)→은퇴→유산→다음 세대, 관련 테스트 통과.
제한: 한 커리어에서 발생하지 않은 챔피언·스폰서 등 선택지는 전체 캡처에 포함되지 않았고, 화면별 미세 비주얼 보정은 별도 검수 대상.
GitHub 미반영. 사용자 저장 데이터 변경 없음(별도 테스트 데이터).
''',encoding='utf-8')
dest=Path(r'C:\Users\M\Downloads\TwelveCount_UI_Structural_Redesign_Verified.zip')
with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for d in [baseline,final]:
  for f in sorted(d.iterdir()):
   if f.is_file():z.write(f,arcname=f'{d.name}/{f.name}')
 for f in [out,notes,root/'season_verified.png',root/'final_structural_review.jpg']:
  if f.exists():z.write(f,arcname=f.name)
print('SAVED',out,'BEFORE',len(old),'AFTER',len(new),'ZIP_MB',round(dest.stat().st_size/1024/1024,1))
