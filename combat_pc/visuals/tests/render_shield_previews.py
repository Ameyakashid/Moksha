#!/usr/bin/env python3
"""Original shield vectors and authoritative contact-band inspection; offline only."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
rows=json.loads((ROOT/'shield_pose_samples.json').read_text())['samples']
font=ImageFont.truetype(FONT,10)
def shield_draw(d,pose,origin,scale):
 draw_pose(d,pose,origin,scale,False)
 sh=pose.get('shield',{})
 if not sh.get('visible'):return
 def pt(v):return origin[0]+v[0]*scale,origin[1]+v[1]*scale
 color='#e8ffdf' if sh['parry_open'] else '#c2e8f5'
 for segment in sh['visible_segments']:d.line([pt(v) for v in segment],fill=color,width=max(1,round(scale)),joint='curve')
 d.line([pt(pose['bones']['elbow_near']),pt(sh['grip'])],fill=color,width=max(1,round(scale*1.5)))
 n=sh['normal'];g=sh['grip'];t=(-n[1],n[0])
 d.line([pt((g[0]-t[0]*1.5,g[1]-t[1]*1.5)),pt((g[0]+t[0]*1.5,g[1]+t[1]*1.5))],fill=color,width=max(1,round(scale)))
phases=['raise','parry','hold','miss_recovery','success_recovery','release_recovery']
small=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(small)
d.text((12,10),'MOKSHA | ORIGINAL SHIELD AT 1:1 GAME SCALE',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((12,31),'Reported guard band. Standing / low / rising. Offline vectors.',font=font,fill='#a8c8d0')
for r,suffix in enumerate(['','_low','_air']):
 for c,phase in enumerate(phases):
  mode='shield_'+phase+suffix;p=0 if phase in ['raise','success_recovery'] else .5
  row=next(s for s in rows if s['label']==mode and s['pose']['phase']==p)
  x=11+c*106;y=63+r*96
  d.text((x,y),phase.replace('_recovery',''),font=font,fill='#a8c8d0')
  if r<2:d.line((x,y+68,x+90,y+68),fill='#344e5c')
  shield_draw(d,row['pose'],(x+39,y+68),1)
small.save(ROOT/'shield_actual_scale.png')
large=Image.new('RGB',(960,1180),'#09121c');d=ImageDraw.Draw(large)
d.text((14,10),'MOKSHA | ORIGINAL SHIELD PHASE KEYS',font=ImageFont.truetype(FONT,16),fill='#e3f5f5')
d.text((14,34),'3x vectors, motor phase progress. Incoming defense is separate from confirmed effects.',font=font,fill='#a8c8d0')
for r,phase in enumerate(phases):
 y=62+r*184;d.rectangle((12,y,947,y+172),fill='#112330',outline='#29414f')
 d.text((24,y+8),phase,font=font,fill='#d2e8ea')
 for c,row in enumerate(s for s in rows if s['label']=='shield_'+phase):
  origin=(72+c*184,y+135)
  d.line((origin[0]-35,origin[1],origin[0]+80,origin[1]),fill='#344e5c')
  shield_draw(d,row['pose'],origin,3)
  d.text((origin[0]-10,y+150),f"{row['pose']['phase']:.2f}",font=font,fill='#a8c8d0')
large.save(ROOT/'shield_contact_sheet.png')
print(ROOT/'shield_actual_scale.png');print(ROOT/'shield_contact_sheet.png')
