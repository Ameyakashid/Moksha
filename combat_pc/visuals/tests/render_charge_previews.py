#!/usr/bin/env python3
"""Original optional loading/thrust vectors. No reference pixels or game capture."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,copy
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
SAMPLES=json.loads((ROOT/'charge_pose_samples.json').read_text())['samples']
font=ImageFont.truetype(FONT,11);small=ImageFont.truetype(FONT,10);title=ImageFont.truetype(FONT,15)
def get(mode,phase,context):return next(s for s in SAMPLES if s['label']==mode+'_'+context and s['pose']['phase']==phase)
def draw(d,s,o,k=1):
 pose=s['pose'];t=s['telemetry'];body=copy.deepcopy(pose);body['weapon']['visible']=False
 if t['grounded']:d.line((o[0]-18*k,o[1],o[0]+42*k,o[1]),fill='#345567',width=1)
 draw_pose(d,body,o,k,False)
 w=pose['weapon'];color='#faebb8' if w['contact'] else '#bacfd6'
 def point(v):return (o[0]+v[0]*k,o[1]+v[1]*k)
 d.line([point(w['pommel']),point(w['grip'])],fill=color,width=max(1,round(k*1.5)))
 d.line([point(w['guard_a']),point(w['guard_b'])],fill=color,width=max(1,round(k*1.25)))
 for seg in w['visible_blade_segments']:d.line([point(p) for p in seg],fill=color,width=max(1,round(k*.85)))
im=Image.new('RGB',(960,820),'#09121c');d=ImageDraw.Draw(im)
d.text((14,10),'MOKSHA | OPTIONAL CHARGE AND SWEPT THRUST',font=title,fill='#e3f5f5')
d.text((14,34),'3x original vectors, normalized motor phases. Offline preview, not gameplay capture.',font=font,fill='#a8c8d0')
for row,(mode,label) in enumerate([('attack_charge','loading / increasing tension'),('attack_charged_thrust_windup','thrust / set'),('attack_charged_thrust_active','thrust / contact and follow-through'),('attack_charged_thrust_recovery','thrust / recovery')]):
 y=62+row*185;d.rounded_rectangle((12,y,948,y+176),radius=5,fill='#112330',outline='#29414f')
 d.text((22,y+9),label,font=font,fill='#d2e8ea')
 for col,p in enumerate([0,.25,.5,.75,1]):
  draw(d,get(mode,p,'ground'),(62+col*181,y+140),3)
  d.text((58+col*181,y+155),f'{p:.2f}',font=small,fill='#a8c8d0')
im.save(ROOT/'charge_contact_sheet.png')
im=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(im)
d.text((12,10),'MOKSHA | CHARGE / THRUST AT 1:1 GAME SCALE',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((12,30),'34px body / 20px low. Original offline vectors.',font=small,fill='#a8c8d0')
entries=[('attack_charge',0,'gather'),('attack_charge',1,'loaded'),('attack_charged_thrust_windup',.75,'set'),('attack_charged_thrust_active',.25,'contact'),('attack_charged_thrust_recovery',.25,'recoil'),('attack_charged_thrust_recovery',1,'recover')]
for row,context in enumerate(['ground','low','fall']):
 y=62+row*97;d.text((12,y),context,font=small,fill='#a8c8d0')
 for col,(mode,p,label) in enumerate(entries):
  x=14+col*104;d.text((x,y+18),label,font=small,fill='#a8c8d0');draw(d,get(mode,p,context),(x+29,y+75),1)
im.save(ROOT/'charge_actual_scale.png')
# Charge progress is deliberately fixed to expose the independent actual-travel gait input.
frames=[]
for i in range(20):
 im=Image.new('RGB',(640,260),'#09121c');d=ImageDraw.Draw(im)
 d.text((12,10),'MOKSHA | MOVING LOAD / LOW SHUFFLE',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
 d.text((12,31),'1:1 and 2x. Fixed charge 0.60, varied travel phase; offline vectors.',font=small,fill='#a8c8d0')
 for row,label in enumerate(['attack_charge_gait','attack_charge_low_gait']):
  s=[s for s in SAMPLES if s['label']==label][i];y=64+row*97
  d.text((14,y),'standing load' if row==0 else 'low load',font=small,fill='#a8c8d0')
  draw(d,s,(100,y+69),1);draw(d,s,(365,y+72),2)
 frames.append(im)
frames[0].save(ROOT/'charge_moving_preview.gif',save_all=True,append_images=frames[1:],duration=50,loop=0,disposal=2)
print(ROOT/'charge_actual_scale.png');print(ROOT/'charge_contact_sheet.png');print(ROOT/'charge_moving_preview.gif')
