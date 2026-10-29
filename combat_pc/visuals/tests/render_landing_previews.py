#!/usr/bin/env python3
"""Original MOKSHA landing vectors; independent offline inspection, not gameplay."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
SAMPLES=json.loads((ROOT/'landing_pose_samples.json').read_text())['samples']
font=ImageFont.truetype(FONT,11);title=ImageFont.truetype(FONT,15)
labels=['ordinary_hard_land_impact','ordinary_hard_land_recovery','dive_hard_land_impact','dive_hard_land_recovery']
im=Image.new('RGB',(920,780),'#09121c');d=ImageDraw.Draw(im)
d.text((16,10),'MOKSHA | ORIGINAL HARD CONTACT AND RECOVERY',font=title,fill='#e3f5f5')
d.text((16,34),'3x authored vectors. Held contact, then recovery. Offline preview, not gameplay.',font=font,fill='#a8c8d0')
for r,label in enumerate(labels):
 y=62+r*172
 d.rounded_rectangle((12,y,907,y+160),radius=5,fill='#112330',outline='#29414f')
 d.text((24,y+10),label,font=font,fill='#d2e8ea')
 for c,row in enumerate(s for s in SAMPLES if s['label']==label):
  x=75+c*174;oy=y+120
  d.line((x-48,oy,x+56,oy),fill='#345567')
  draw_pose(d,row['pose'],(x,oy),3,True)
  d.text((x-20,y+136),f"{row['pose']['phase']:.2f}",font=font,fill='#a8c8d0')
im.save(ROOT/'landing_contact_sheet.png')
small=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(small)
d.text((14,10),'MOKSHA | LANDING AT 1:1 GAME SCALE',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((14,32),'Original34px rig; hard recovery stays inside20px. Offline vectors.',font=ImageFont.truetype(FONT,10),fill='#a8c8d0')
for r,mirror in enumerate(['','_left']):
 for c,(label,phase,caption) in enumerate([('land',0,'soft contact'),('ordinary_hard_land_impact',0,'hard impact'),('ordinary_hard_land_recovery',.75,'hard recovery'),('dive_hard_land_impact',0,'dive hard'),('dive_hard_land_recovery',.75,'dive recovery')]):
  lookup=label+mirror if c else label
  row=next(s for s in SAMPLES if s['label']==lookup and s['pose']['phase']==phase)
  pose=row['pose']
  if r and not c:
   pose=json.loads(json.dumps(pose));pose['facing']=-1
   for bone in pose['bones'].values():bone[0]*=-1
  x=10+c*127;y=80+r*131
  d.text((x,y),caption,font=ImageFont.truetype(FONT,9),fill='#a8c8d0')
  d.line((x,y+68,x+114,y+68),fill='#345567')
  draw_pose(d,pose,(x+51,y+68),1,False)
small.save(ROOT/'landing_actual_scale.png')
print(ROOT/'landing_actual_scale.png');print(ROOT/'landing_contact_sheet.png')
