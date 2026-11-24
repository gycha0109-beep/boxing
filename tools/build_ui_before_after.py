from pathlib import Path
from html import escape
import json,zipfile
root=Path(r'D:\cha\boxing-current\docs\ui-audit')
old=root/'full-career-20261123'
new=root/'full-career-polished-final-20261123'
a=json.loads((old/'manifest.json').read_text(encoding='utf-8'))['screenshots']
b=json.loads((new/'manifest.json').read_text(encoding='utf-8'))['screenshots']
pairs=[
(0,0,'메인 타이틀'),(1,1,'첫 실행'),(2,2,'튜토리얼 개요'),(3,3,'선수 생성'),
(4,4,'재능 추첨'),(5,5,'재능 결과'),(7,7,'훈련'),
(9,9,'선수 프로필'),(11,11,'커리어 기록'),(12,12,'장비 상점'),
(14,14,'경기 제안'),(16,16,'상대 분석'),(17,17,'계체'),
(18,18,'전투 HUD'),(20,20,'경기 결과'),(22,26,'커리어 이벤트'),
(31,32,'시즌 종료'),(34,36,'은퇴 후 유산'),(35,38,'유산 선택'),(36,39,'다음 세대')
]
style='''<style>body{margin:0;background:#10141a;color:#f4efe5;font:15px system-ui,Malgun Gothic,sans-serif}header{padding:26px 24px;background:#1a222d;border-bottom:1px solid #74603b}h1{margin:0;color:#f1cc85;font-size:24px}p{line-height:1.65;color:#c2c8cc}main{max-width:1280px;margin:25px auto;padding:0 14px}.pair{margin:20px 0 36px;background:#1b232d;padding:18px;border:1px solid #756044;border-radius:12px}.pair h2{font-size:18px;margin:0 0 14px}.cols{display:flex;gap:20px;justify-content:center;flex-wrap:wrap}.shot{width:260px}.shot img{width:100%;height:auto;border:1px solid #695232;border-radius:6px}.shot p{margin:6px 0;color:#e9d5a4;font-size:13px}.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(155px,1fr));gap:15px}.gallery figure{margin:0}.gallery img{width:100%}.gallery figcaption{font-size:12px;color:#c6b99e}.tag{font-weight:600;color:#f0ce83}a{color:#eec67a}</style>'''
blocks=[]
for idx,(i,j,title) in enumerate(pairs):
    lhs=escape('full-career-20261123/'+a[i]['file'])
    rhs=escape('full-career-polished-final-20261123/'+b[j]['file'])
    blocks.append(f'<section class="pair"><h2>{idx+1:02d} · {escape(title)}</h2><div class="cols"><div class="shot"><a href="{lhs}"><img loading="lazy" src="{lhs}"></a><p>BEFORE · 기존 UI</p></div><div class="shot"><a href="{rhs}"><img loading="lazy" src="{rhs}"></a><p>AFTER · 공통 디자인 적용</p></div></div></section>')
gallery=[]
for i,x in enumerate(b):
    fn=escape('full-career-polished-final-20261123/'+x['file'])
    gallery.append(f'<figure><a href="{fn}"><img loading="lazy" src="{fn}"></a><figcaption>{i:02d} · {escape(str(x["phase"]))}</figcaption></figure>')
html=f'''<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Twelve Count UI 고도화 전후 비교</title>{style}</head><body><header><h1>TWELVE COUNT · UI 전후 비교</h1><p>기존 37장과 개선 후 40장 중 동일 단계 20쌍을 비교합니다. 레이아웃, 게임 흐름과 이미지 에셋은 유지하고 공통 UI 스타일을 적용했습니다.<br>캡처는 실제 Godot 4.7.2 화면이며 경기 결과는 테스트용 자동 재현입니다. 이벤트 발생 순서는 회차마다 달라질 수 있습니다.</p></header><main><h2>핵심 화면 20쌍 비교</h2>{''.join(blocks)}<h2>개선판 전체 40장</h2><div class="gallery">{''.join(gallery)}</div></main></body></html>'''
target=root/'UI_Before_After_Comparison.html'
target.write_text(html,encoding='utf-8')
readme=root/'UI_POLISH_IMPLEMENTATION.md'
readme.write_text('''# Twelve Count — UI polish application (2026-11-23)

## Policy
Retain the exact flow and existing screen hierarchy from the 37-screen audit. All source images, card order, save logic, and action semantics remain unchanged.

## Implemented
- Shared near-black / dark slate and restrained gold palette in main_v17.gd.
- Raised-card background / muted border / hover and focus states from twelve_design_system.gd.
- Better Korean body copy sizing and contrast; font fallback across gameplay.
- Shared bevel geometry and gold metallic primary buttons via reference_ui.gd.
- Inherited screen finishing hooks in main_v18_release.gd; retain title-specific art and layouts.
- Primary gold-button style harmonized in main_v18_release_base.gd.

## Verification
- Original audit 37 captures and upgraded run 40 captures, at 430x932.
- 7 scripted bout outcomes produce an actual retirement and next-generation transition.
- Seven targeted regression suites PASS, after aligning two old tests with title-first launch behavior.
- One Godot resource-in-use warning observed in preparation test despite exit 0.
- User save remains untouched (isolated test user-data directory).

## Limitations
- This is a full-screen shared-style pass, not reillustration or hand-made bespoke art for every screen.
- Event draws differ between audit runs; comparisons are stage-matched rather than frame-perfect.
- Tutorial spotlights intentionally dim non-target UI and remain unchanged.
- Championship and other optional endings were not captured in this route.
''',encoding='utf-8')
bundle=Path(r'C:\Users\M\Downloads\TwelveCount_UI_Polished_Comparison_20261123.zip')
with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED,compresslevel=5) as z:
    for folder in [old,new]:
        for f in folder.iterdir():
            if f.is_file():z.write(f,arcname=f'{folder.name}/{f.name}')
    for f in [target,readme]:
        z.write(f,arcname=f.name)
print('COMPARISON',target,'PAIRS',len(pairs),'NEW',len(b),'ZIP',bundle,round(bundle.stat().st_size/1024/1024,1),'MB')
