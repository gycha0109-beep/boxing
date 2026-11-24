from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont
import json, zipfile, hashlib
base=Path(r"D:\cha\boxing-current\docs\ui-audit\full-career-20261123")
shots=sorted(base.glob("*.png"))
titles=[
"00 Main Title","01 First Launch Welcome","02 Tutorial Overview","03 Boxing Style Select",
"04 Talent Roulette","05 Talent Result","06 Talent Confirmation","07 First Training",
"08 Training Scrolled","09 Fighter Profile","10 Fighter Profile Scrolled","11 Career Record",
"12 Equipment Shop","13 Training Result","14 Opponent Selection","15 Opponent Selection Scrolled",
"16 Scouting and Gameplan","17 Weigh-in","18 Fight Opening","19 Fight Exchange",
"20 Bout 1 Result","21 Tutorial Complete","22 Career Event","23 Camp After Bout",
"24 Second Bout Offers","25 Second Bout Fight","26 Bout 2 Result","27 Event After Bout",
"28 Bout 3 Result","29 Career Progress 3","30 Gym Fund Intro","31 Season Review",
"32 Later Career Camp","33 Final Bout Result","34 Retirement Summary",
"35 Legacy Selection","36 Next Generation"
]
assert len(shots)==len(titles),(len(shots),len(titles))
manifest=json.loads((base/"manifest.json").read_text(encoding="utf-8"))
for i,(file,title) in enumerate(zip(shots,titles)):
    renamed=base/f"{i:02d}_{title[3:].lower().replace(' ','_')}.png"
    file.rename(renamed)
    manifest["screenshots"][i]["file"]=renamed.name
    manifest["screenshots"][i]["title_en"]=title
(base/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
fontfile=Path(r"C:\Windows\Fonts\arial.ttf")
font=ImageFont.truetype(str(fontfile),18) if fontfile.exists() else ImageFont.load_default()
small=ImageFont.truetype(str(fontfile),13) if fontfile.exists() else ImageFont.load_default()
paths=sorted(base.glob("*.png"))
for page in range(3):
    chunk=paths[page*14:(page+1)*14]
    if not chunk: continue
    columns=4
    tw,th=205,445
    rows=(len(chunk)+columns-1)//columns
    canvas=Image.new("RGB",(columns*tw,rows*th+45),(18,20,25))
    draw=ImageDraw.Draw(canvas)
    draw.text((12,11),f"TWELVE COUNT  |  FULL CAREER UI AUDIT  |  {page+1}/3",fill=(230,208,146),font=font)
    for k,f in enumerate(chunk):
        im=Image.open(f).convert("RGB")
        thumb=ImageOps.contain(im,(197,395),Image.Resampling.LANCZOS)
        x=(k%columns)*tw+4
        y=(k//columns)*th+45
        canvas.paste(thumb,(x+(197-thumb.width)//2,y))
        title=titles[page*14+k]
        draw.text((x+1,y+399),title[:26],fill=(245,243,234),font=small)
    out=base.parent/f"contact_sheet_{page+1}.jpg"
    canvas.save(out,quality=88)
    print("SHEET",out,canvas.size)
bundle=Path(r"C:\Users\M\Downloads\TwelveCount_FullCareer_UI_37screens_20261123.zip")
with zipfile.ZipFile(bundle,'w',zipfile.ZIP_DEFLATED,compresslevel=5) as z:
 for f in paths+[base/"manifest.json"]:
    z.write(f,arcname="screens/"+f.name)
 for f in sorted(base.parent.glob("contact_sheet_*.jpg")):
    z.write(f,arcname=f.name)
print("ZIP",bundle,bundle.stat().st_size, "PNG_COUNT",len(paths))
