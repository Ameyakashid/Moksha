#!/usr/bin/env python3
"""Original drop/dive vector inspection. Offline, not a gameplay recording."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
SAMPLES=json.loads((ROOT/'descent_pose_samples.json').read_text())['samples']
LABELS=list(dict.fromkeys(s['label'] for s in SAMPLES))
font=ImageFont.truetype(FONT,12);title=ImageFont.truetype(FONT,16)
w=860;ch=176;h=64+ch*len(LABELS)
im=Image.new('RGB',(w,h),'#09121c');d=ImageDraw.Draw(im)
d.text((16,10),'MOKSHA | ORIGINAL DROP AND DIVE KEYS',font=title,fill='#e3f5f5')
d.text((16,34),'3x authored vectors. Motor phases. Offline preview, not gameplay capture.',font=font,fill='#a8c8d0')
for i,label in enumerate(LABELS):
 y=60+i*ch;d.rounded_rectangle((12,y,w-12,y+ch-9),radius=5,fill='#112330',outline='#29414f')
 d.text((22,y+8),label,font=font,fill='#d2e8ea')
 for j,row in enumerate(s for s in SAMPLES if s['label']==label):
  x=86+j*205;oy=y+134
  d.line((x-52,oy,x+120,oy),fill='#29414f',width=1)
  draw_pose(d,row['pose'],(x,oy),3.0,True)
  d.text((x-12,y+147),f"{row['pose']['phase']:.2f}",font=font,fill='#a8c8d0')
im.save(ROOT/'descent_contact_sheet.png')
im.crop((0,0,w,64+ch*6)).save(ROOT/'drop_dive_detail.png')
im.crop((0,60+ch*6,w,h)).save(ROOT/'dive_impact_detail.png')
small=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(small)
d.text((14,10),'MOKSHA | DROP / DIVE AT 1:1 GAME SCALE',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((14,31),'Original 34px standing and 20px low bodies. Offline vectors.',font=ImageFont.truetype(FONT,10),fill='#9abac5')
base=['drop','dive_startup','dive_descent','dive_impact','dive_recovery']
for row in range(2):
 for col,label in enumerate(base):
  actual=label+('_low' if row else '');phase=.0 if label in ['dive_startup','dive_impact'] else .5
  sample=next(s for s in SAMPLES if s['label']==actual and s['pose']['phase']==phase)
  x=12+126*col;y=84+132*row
  d.text((x,y),label.removeprefix('dive_')+(' low' if row else ''),font=ImageFont.truetype(FONT,10),fill='#a8c8d0')
  d.line((x,y+75,x+112,y+75),fill='#29414f',width=1)
  draw_pose(d,sample['pose'],(x+52,y+75),1,False)
small.save(ROOT/'descent_actual_scale.png')
print(ROOT/'descent_contact_sheet.png');print(ROOT/'descent_actual_scale.png')
