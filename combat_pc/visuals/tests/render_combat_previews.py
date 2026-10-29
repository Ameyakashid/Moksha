#!/usr/bin/env python3
"""Original combat vector inspection. No reference image pixels or gameplay capture."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
SAMPLES=json.loads((ROOT/'combat_pose_samples.json').read_text())['samples']
labels=[x for x in dict.fromkeys(s['label'] for s in SAMPLES) if not x.startswith('roll_') or not x.endswith('_air')]
font=ImageFont.truetype(FONT,12);title=ImageFont.truetype(FONT,16)
w=860;ch=176;h=64+ch*len(labels)
im=Image.new('RGB',(w,h),'#09121c');d=ImageDraw.Draw(im)
d.text((16,10),'MOKSHA | ORIGINAL COMBAT KEYS',font=title,fill='#e3f5f5')
d.text((16,34),'3x authored vectors. Motor phase fractions. Offline preview, not gameplay capture.',font=font,fill='#a8c8d0')
for i,label in enumerate(labels):
 y=60+i*ch;d.rounded_rectangle((12,y,w-12,y+ch-9),radius=5,fill='#112330',outline='#29414f')
 d.text((22,y+8),label,font=font,fill='#d2e8ea')
 for j,sample in enumerate(s for s in SAMPLES if s['label']==label):
  x=84+j*205;oy=y+134
  d.line((x-52,oy,x+124,oy),fill='#29414f',width=1)
  draw_pose(d,sample['pose'],(x,oy),3.0,True)
  d.text((x-12,y+147),f"{sample['pose']['phase']:.2f}",font=font,fill='#a8c8d0')
im.save(ROOT/'combat_contact_sheet.png')
im.crop((0,0,w,64+ch*3)).save(ROOT/'roll_detail.png')
im.crop((0,60+ch*3,w,60+ch*7)).save(ROOT/'attack_hurt_detail.png')
im.crop((0,60+ch*7,w,h)).save(ROOT/'recovery_hurt_detail.png')
scale=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(scale)
d.text((14,10),'MOKSHA | COMBAT AT 1:1 GAME SCALE',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((14,30),'Original 34px rig / 20px roll. Offline vector preview.',font=ImageFont.truetype(FONT,10),fill='#9abac5')
entries=[('roll_start',.0),('roll_travel',.25),('roll_recovery',.5),('hurt',.0),('attack_windup',.75),('attack_active',.25),('attack_recovery',.5),('attack_active_air',.25)]
small=ImageFont.truetype(FONT,10)
for i,(label,phase) in enumerate(entries):
 x=14+i%4*156;y=80+i//4*132
 sample=next(s for s in SAMPLES if s['label']==label and s['pose']['phase']==phase)
 d.text((x,y),label,font=small,fill='#a8c8d0');d.line((x,y+75,x+138,y+75),fill='#29414f',width=1)
 draw_pose(d,sample['pose'],(x+55,y+75),1,False)
scale.save(ROOT/'combat_actual_scale.png')
print(ROOT/'combat_contact_sheet.png');print(ROOT/'combat_actual_scale.png')
