#!/usr/bin/env python3
"""Independent original slope joint/contact inspection; not gameplay capture."""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
rows=json.loads((ROOT/'slope_pose_samples.json').read_text())['samples']
font=ImageFont.truetype(FONT,10)
def ground(d,t,origin,scale,extent):
 n=t['floor_normal'];p=t['floor_contact_point'];axis=(-n[1],n[0]);dot=p[0]*n[0]+p[1]*n[1]
 mid=(n[0]*dot,n[1]*dot)
 points=[(origin[0]+scale*(mid[0]+a*extent*axis[0]),origin[1]+scale*(mid[1]+a*extent*axis[1])) for a in [-1,1]]
 d.line(points,fill='#44616d',width=1)
small=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(small)
d.text((14,10),'MOKSHA | PASSIVE SLOPE CONTACTS AT 1:1',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((14,32),'Original joint fit. Mirrored 26.6/45 degree planes. Offline vectors.',font=font,fill='#a8c8d0')
for r,angle in enumerate([-26.6,26.6,-45.0,45.0]):
 for c,mode in enumerate(['idle','run','brake','crouch']):
  s=next(s for s in rows if s['label']==f'{mode}_{angle:+.1f}' and s['pose']['phase']==(.25 if mode=='run' else 0))
  x=16+c*156;y=65+r*70;origin=(x+66,y+48)
  d.text((x,y),f'{mode} {angle:+.1f}',font=font,fill='#a8c8d0')
  ground(d,s['telemetry'],origin,1,35);draw_pose(d,s['pose'],origin,1,False)
small.save(ROOT/'slope_actual_scale.png')
large=Image.new('RGB',(960,816),'#09121c');d=ImageDraw.Draw(large)
d.text((14,10),'MOKSHA | SLOPE KEYS AND NORMAL-ALIGNED FEET',font=ImageFont.truetype(FONT,16),fill='#e3f5f5')
d.text((14,34),'3x original vectors. Green means reachable planted stance. No actor root offset.',font=font,fill='#a8c8d0')
for r,angle in enumerate([-26.6,26.6,-45.0,45.0]):
 for c,mode in enumerate(['idle','run','brake','crouch']):
  s=next(s for s in rows if s['label']==f'{mode}_{angle:+.1f}' and s['pose']['phase']==(.25 if mode=='run' else 0))
  x=12+c*238;y=60+r*188;origin=(x+120,y+143)
  d.rectangle((x,y,x+226,y+176),fill='#112330',outline='#29414f')
  d.text((x+8,y+8),f'{mode} {angle:+.1f}',font=font,fill='#d2e8ea')
  ground(d,s['telemetry'],origin,3,33);draw_pose(d,s['pose'],origin,3,True)
large.save(ROOT/'slope_contact_sheet.png')
print(ROOT/'slope_actual_scale.png');print(ROOT/'slope_contact_sheet.png')
specials=[('roll_start',0),('roll_recovery',.75),('attack_windup',.5),('attack_active',0),('attack_recovery',.5),('hurt',.75)]
special=Image.new('RGB',(1268,620),'#09121c');d=ImageDraw.Draw(special)
d.text((14,10),'MOKSHA | EXISTING GROUNDED SPECIAL CONTACTS',font=ImageFont.truetype(FONT,15),fill='#e3f5f5')
d.text((14,34),'3x original vectors; only authored support is fitted. Strike geometry stays motor-owned.',font=font,fill='#a8c8d0')
for r,angle in enumerate([-45.0,45.0]):
 for c,(mode,phase) in enumerate(specials):
  s=next(s for s in rows if s['label']==f'{mode}_{angle:+.1f}' and s['pose']['phase']==phase)
  x=12+c*210;y=62+r*274;origin=(x+96,y+203)
  d.rectangle((x,y,x+198,y+260),fill='#112330',outline='#29414f')
  d.text((x+6,y+8),mode.replace('attack_','melee '),font=ImageFont.truetype(FONT,9),fill='#d2e8ea')
  ground(d,s['telemetry'],origin,3,23);draw_pose(d,s['pose'],origin,3,True)
  d.text((x+6,y+241),f'{angle:+.0f} deg',font=font,fill='#a8c8d0')
special.save(ROOT/'slope_special_contact_sheet.png')
