from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageFilter

source = Path(r"C:\Users\M\Downloads\twelve_count_title_composite.png")
project = Path(r"D:\cha\boxing-web-preview")
output = project / "assets" / "visual" / "title_layers_v2"
output.mkdir(parents=True, exist_ok=True)
im = Image.open(source).convert("RGBA")
rgb = np.array(im)[:,:,:3].copy()
h,w=rgb.shape[:2]
print("Source:",w,h)
# The composition is a reference canvas. Only individual components are exported.
# A tighter polygon identifies the boxer independently of the boxing ring.
poly = np.array([
 (429,225),(479,224),(528,247),(556,267),(580,308),(582,354),
 (559,384),(610,401),(628,441),(645,505),(653,564),(675,628),
 (703,688),(722,738),(744,788),(741,828),(708,853),(681,856),
 (647,818),(630,772),(625,863),(316,863),(316,796),(297,815),
 (263,852),(223,861),(202,842),(203,797),(217,754),(245,693),
 (261,630),(275,559),(296,476),(332,421),(377,384),
 (385,343),(389,301),(402,267)
],np.int32)
mask=np.full((h,w),cv2.GC_BGD,np.uint8)
region=np.zeros((h,w),np.uint8)
cv2.fillPoly(region,[poly],255)
dilate=cv2.dilate(region,np.ones((27,27),np.uint8),iterations=1)
erode=cv2.erode(region,np.ones((27,27),np.uint8),iterations=1)
mask[dilate>0]=cv2.GC_PR_BGD
mask[region>0]=cv2.GC_PR_FGD
mask[erode>0]=cv2.GC_FGD
bg=np.zeros((1,65),np.float64)
fg=np.zeros((1,65),np.float64)
cv2.grabCut(cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR),mask,None,bg,fg,8,cv2.GC_INIT_WITH_MASK)
alpha=np.where((mask==cv2.GC_FGD)|(mask==cv2.GC_PR_FGD),255,0).astype(np.uint8)
parts,labels,stats,_=cv2.connectedComponentsWithStats(alpha,8)
if parts>1:
 largest=1+np.argmax(stats[1:,cv2.CC_STAT_AREA])
 alpha=np.where(labels==largest,255,0).astype(np.uint8)
# Enforce a human silhouette with independently outlined arms, torso and shorts.
# This removes dark stadium pixels that GrabCut can otherwise retain inside arm gaps.
shape=np.zeros((h,w),np.uint8)
body=np.array([(433,225),(492,230),(546,259),(576,311),(567,371),
 (599,394),(628,431),(635,493),(625,553),(611,641),
 (633,849),(318,849),(322,632),(307,564),(299,504),
 (313,450),(374,394),(388,353),(383,309),(403,253)],np.int32)
left=np.array([(345,411),(308,440),(283,499),(262,575),
 (239,663),(213,744),(195,804),(205,844),(250,861),(294,849),
 (306,815),(310,764),(303,721),(320,659),(349,582),(363,502)],np.int32)
right=np.array([(597,406),(622,439),(644,522),(668,598),
 (700,677),(731,757),(748,803),(736,842),(696,861),
 (652,842),(646,796),(659,745),(651,690),(625,640),
 (601,574),(592,487)],np.int32)
for line in [body,left,right]:
 cv2.fillPoly(shape,[line],255)
shape=cv2.GaussianBlur(shape,(7,7),1.35)
alpha=np.uint8(np.minimum(alpha,shape))
# Only soften the physical cut at the end of the shorts.
fade=np.clip((855-np.arange(h,dtype=np.float32))/15.0,0,1)
alpha=np.uint8(np.clip(alpha.astype(np.float32)*fade[:,None],0,255))
bbox=cv2.boundingRect((alpha>20).astype(np.uint8))
x,y,bw,bh=bbox
boxer=np.dstack([rgb,alpha])[max(0,y-8):min(h,y+bh+8),max(0,x-8):min(w,x+bw+8)]
Image.fromarray(boxer).save(output/"boxer_foreground.png",optimize=True)

# Stage contains no baked boxer; reconstruct the occluded area with arena texture,
# then blend original clean side rails/crowds and stadium lights back in.
arena=Image.open(project/"assets/visual/v0.7/arena/arena_title_night.png").convert("RGB")
stage_top,stage_bot=190,895
stage=np.array(im.crop((21,stage_top,w-21,stage_bot)).convert("RGB"))
mh,mw=stage.shape[:2]
alpha_stage=alpha[stage_top:stage_bot,21:w-21]
arena_np=np.array(arena.resize((mw,mh),Image.Resampling.LANCZOS))
# Replace the whole central strip, not a feathered figure outline: no boxer ghosting.
# Preserve the original outer stadium banners and border.
xx=np.arange(mw,dtype=np.float32)[None,:]
blend=np.minimum(np.clip((xx-125)/115,0,1),np.clip((mw-xx-120)/115,0,1))
blend=np.tile(blend,(mh,1))[:,:,None]
arena_np=np.clip(arena_np.astype(np.float32)*.70,0,255)
mixed=stage.astype(np.float32)*(1-blend)+arena_np*blend
Image.fromarray(np.uint8(np.clip(mixed,0,255))).save(output/"arena_clean.png",optimize=True)
# Ornamental header and lower belt are separate art layers (no live text).
im.crop((0,0,w,210)).save(output/"gold_header.png",optimize=True)
im.crop((0,1263,w,h)).save(output/"champion_belt_footer.png",optimize=True)
# Clean background plates; typography is generated separately by Godot.
im.crop((55,889,885,1098)).save(output/"button_gold_plate.png",optimize=True)
im.crop((167,1113,770,1254)).save(output/"button_dark_plate.png",optimize=True)
print("boxer bbox:",bbox,"alpha pixels:",np.count_nonzero(alpha))
for p in output.iterdir():
 if p.suffix==".png": print(p.name,Image.open(p).size,p.stat().st_size)
