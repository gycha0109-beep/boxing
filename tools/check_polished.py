from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont
import json
p=Path(r'D:\cha\boxing-current\docs\ui-audit\full-career-polished-20261123')
m=json.loads((p/'manifest.json').read_text(encoding='utf-8'))
f=sorted(p.glob('*.png'))
font=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',13)
for page in range((len(f)+11)//12):
 subset=f[page*12:(page+1)*12]
 sheet=Image.new('RGB',(840,1440),(19,22,28));d=ImageDraw.Draw(sheet)
 for j,src in enumerate(subset):
  im=Image.open(src).convert('RGB'); im.thumbnail((200,427))
  x=(j%4)*210+5;y=(j//4)*480+3
  sheet.paste(im,(x+(200-im.width)//2,y))
  d.text((x+4,y+431),f'{page*12+j:02d} {m["screenshots"][page*12+j]["phase"]}',font=font,fill='#eee4c9')
 out=p.parent/f'polished_sheet_{page+1}.jpg'; sheet.save(out,quality=88);print(out)
print('COUNT',len(f),'ISSUES',m['issues'])
