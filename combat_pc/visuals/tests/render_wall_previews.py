#!/usr/bin/env python3
"""Original wall vectors with collision-plane guides. Not gameplay capture."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
SAMPLES=json.loads((ROOT/'wall_pose_samples.json').read_text())['samples']
LABELS=list(dict.fromkeys(s['label'] for s in SAMPLES))
def wall(d,t,origin,scale):
 ox,oy=origin;root=t['position'];x=ox+(t['wall_plane_x']-root[0])*scale
 top=oy+max(-43,t['wall_top_y']-root[1])*scale;bottom=oy+min(3,t['wall_bottom_y']-root[1])*scale
 side=t['wall_side'];d.line((x,top,x,bottom),fill='#52716f',width=max(1,round(scale*.4)))
 for y in range(round(top),round(bottom),max(1,round(scale*8))):
  d.line((x,y,x+side*3*scale,y+3*scale),fill='#294541',width=max(1,round(scale*.3)))
font=ImageFont.truetype(FONT,12);title=ImageFont.truetype(FONT,16)
w=860;ch=176;h=64+ch*len(LABELS)
im=Image.new('RGB',(w,h),'#09121c');d=ImageDraw.Draw(im)
d.text((16,10),'MOKSHA | ORIGINAL WALL RUN / SLIDE / KICK',font=title,fill='#e3f5f5')
d.text((16,34),'3x motor-phase/travel samples. Green = planted sole. Offline vectors, not gameplay.',font=font,fill='#a8c8d0')
for i,label in enumerate(LABELS):
 y=60+i*ch;d.rounded_rectangle((12,y,w-12,y+ch-9),radius=5,fill='#112330',outline='#29414f')
 d.text((22,y+8),label,font=font,fill='#d2e8ea')
 for j,row in enumerate(s for s in SAMPLES if s['label']==label):
  x=85+j*205;oy=y+133
  wall(d,row['telemetry'],(x,oy),3)
  draw_pose(d,row['pose'],(x,oy),3,True)
  d.text((x-12,y+147),f"{row['pose']['phase']:.2f}",font=font,fill='#a8c8d0')
im.save(ROOT/'wall_contact_sheet.png')
im.crop((0,0,w,64+ch*3)).save(ROOT/'wall_run_detail.png')
im.crop((0,60+ch*3,w,60+ch*6)).save(ROOT/'wall_slide_detail.png')
im.crop((0,60+ch*6,w,h)).save(ROOT/'wall_kick_detail.png')
small=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(small)
d.text((14,10),'MOKSHA | MIRRORED WALL POSES AT 1:1',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((14,31),'Original34px rig. Authoritative wall-plane guides. Offline vectors.',font=ImageFont.truetype(FONT,10),fill='#9abac5')
entries=['wall_run','wall_slide','wall_kick','wall_run_left','wall_slide_left','wall_kick_left']
for i,label in enumerate(entries):
 phase=.25 if label.startswith('wall_kick') else .5
 row=next(s for s in SAMPLES if s['label']==label and s['pose']['phase']==phase)
 x=24+(i%3)*204;y=87+(i//3)*129
 d.text((x,y),label,font=ImageFont.truetype(FONT,10),fill='#a8c8d0')
 wall(d,row['telemetry'],(x+74,y+75),1);draw_pose(d,row['pose'],(x+74,y+75),1,False)
small.save(ROOT/'wall_actual_scale.png')
print(ROOT/'wall_contact_sheet.png');print(ROOT/'wall_actual_scale.png')
