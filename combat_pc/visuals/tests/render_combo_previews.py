#!/usr/bin/env python3
"""Original MOKSHA vector previews. No reference pixels or gameplay-capture claim."""
from pathlib import Path
import json,math,copy
from PIL import Image,ImageDraw,ImageFont
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
DATA=json.loads((ROOT/'combo_pose_samples.json').read_text());SAMPLES=DATA['samples']
font=ImageFont.truetype(FONT,11);small=ImageFont.truetype(FONT,10);title=ImageFont.truetype(FONT,15)
def sample(step,phase,p,context='ground',slope=False):
 label=f'{step}_{phase}_{context}'+('_slope' if slope else '')
 return next(s for s in SAMPLES if s['label']==label and s['pose']['phase']==p)
def combo(d,pose,origin,scale,contacts=True):
 body=copy.deepcopy(pose);body['weapon']['visible']=False
 draw_pose(d,body,origin,scale,contacts)
 weapon=pose['weapon'];ox,oy=origin
 def pt(v):return (ox+v[0]*scale,oy+v[1]*scale)
 color='#faebb8' if weapon['contact'] else '#bacfd6'
 d.line([pt(weapon['pommel']),pt(weapon['grip'])],fill=color,width=max(1,round(scale*1.5)))
 d.line([pt(weapon['guard_a']),pt(weapon['guard_b'])],fill=color,width=max(1,round(scale*1.25)))
 for line in weapon['visible_blade_segments']:d.line([pt(x) for x in line],fill=color,width=max(1,round(scale*.85)))
def floor(d,t,origin,scale):
 if not t['grounded']:return
 ox,oy=origin;n=t['floor_normal'];plane=[t['floor_contact_point'][i]-t['position'][i] for i in range(2)]
 pts=[(ox+(plane[0]+k*(-n[1]))*scale,oy+(plane[1]+k*n[0])*scale) for k in [-18,38]]
 d.line(pts,fill='#345567',width=1)
im=Image.new('RGB',(960,2040),'#09121c');d=ImageDraw.Draw(im)
d.text((16,10),'MOKSHA | ORIGINAL THREE-STEP LIGHT CHAIN',font=title,fill='#e3f5f5')
d.text((16,34),'3x authored vectors. Motor phase fractions; offline inspection, not gameplay capture.',font=font,fill='#a8c8d0')
for row,(step,phase) in enumerate((s,p) for s in ['slash','backhand','finisher'] for p in ['windup','active','recovery']):
 y=60+row*220;d.rounded_rectangle((12,y,948,y+210),radius=5,fill='#112330',outline='#29414f')
 d.text((22,y+8),step+' / '+phase,font=font,fill='#d2e8ea')
 for col,p in enumerate([0,.25,.5,.75,1]):
  s=sample(step,phase,p);o=(68+col*183,y+180);floor(d,s['telemetry'],o,3);combo(d,s['pose'],o,3,True)
  d.text((o[0]-9,y+194),f'{p:.2f}',font=small,fill='#a8c8d0')
im.save(ROOT/'combo_contact_sheet.png')
im=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(im)
d.text((12,10),'MOKSHA | COMBO AT 1:1 GAME SCALE',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((12,30),'34px body / 20px low. Original offline vectors.',font=small,fill='#a8c8d0')
for row,context in enumerate(['ground','low','fall']):
 y=58+row*98;d.text((12,y),context,font=small,fill='#9abac5')
 for col,step in enumerate(['slash','backhand','finisher']):
  x=18+col*209;d.text((x+22,y+14),step,font=small,fill='#d2e8ea')
  for index,(phase,p) in enumerate([('windup',.75),('active',.25),('recovery',.25)]):
   s=sample(step,phase,p,context);o=(x+20+index*63,y+79);floor(d,s['telemetry'],o,1);combo(d,s['pose'],o,1,False)
im.save(ROOT/'combo_actual_scale.png')
im=Image.new('RGB',(960,1390),'#09121c');d=ImageDraw.Draw(im)
d.text((12,10),'MOKSHA | COMBO ON REPORTED 45-DEGREE SUPPORT',font=title,fill='#e3f5f5')
d.text((12,34),'3x vectors. Ground-only blade occlusion; raw blade and strike remain unchanged.',font=font,fill='#a8c8d0')
for row,(step,uphill) in enumerate((s,u) for u in [True,False] for s in ['slash','backhand','finisher']):
 y=65+row*218;d.text((14,y),step+(' uphill' if uphill else ' downhill'),font=font,fill='#d2e8ea')
 for col,(phase,p) in enumerate([('windup',.75),('active',.25),('recovery',.25)]):
  label=f'{step}_{phase}_ground_'+('slope_up' if uphill else 'slope')
  s=next(s for s in SAMPLES if s['label']==label and s['pose']['phase']==p)
  o=(100+col*290,y+182);floor(d,s['telemetry'],o,3);combo(d,s['pose'],o,3,True)
  d.text((o[0]+60,y+12),phase,font=font,fill='#a8c8d0')
im.save(ROOT/'combo_slope_sheet.png')
# Offline 60Hz normalized-key sequence. No actor motion or gameplay capture.
variants={v:[s for s in DATA['transitions'] if s['variant']==v] for v in ['forward','reverse','low','low_reverse']}
frames=[]
for i in range(len(variants['forward'])):
 im=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(im)
 d.text((12,10),'MOKSHA | AUTHORED CHAIN TRANSITIONS',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
 d.text((12,31),'1:1 rig beside 1.3x detail. Offline fixed-root pose sequence.',font=small,fill='#a8c8d0')
 for row,variant in enumerate(variants):
  s=variants[variant][i];y=50+row*75
  d.text((14,y),variant+' / '+s['step']+' / '+s['phase'],font=small,fill='#a8c8d0')
  floor(d,s['telemetry'],(115,y+67),1);combo(d,s['pose'],(115,y+67),1,False)
  # Larger copy framed with the overhead blade fully inside its column.
  combo(d,s['pose'],(415,y+67),1.3,False)
 frames.append(im)
frames[0].save(ROOT/'combo_transition_preview.gif',save_all=True,append_images=frames[1:]+[frames[-1]]*18,duration=17,loop=0,disposal=2)
print(ROOT/'combo_actual_scale.png');print(ROOT/'combo_contact_sheet.png');print(ROOT/'combo_slope_sheet.png');print(ROOT/'combo_transition_preview.gif')
