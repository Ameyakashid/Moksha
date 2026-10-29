#!/usr/bin/env python3
"""Independent offline rendering of MOKSHA authored vectors; not a gameplay capture."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,math,html
ROOT=Path(__file__).resolve().parent
DATA=json.loads((ROOT/'pose_samples.json').read_text());SAMPLES=DATA['samples']
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
HEAD=[(-2.1,-2),(.7,-2.7),(2.2,-1.6),(2.6,-.25),(3.2,.55),(1.6,1.1),(.7,2.5),(-1.8,2),(-2.5,.5),(-2.1,-2)]
CHAINS=[(['hip_far','knee_far','ankle_far'],'#6e96a3',.82),(['shoulder_far','elbow_far','palm_far'],'#6e96a3',.82),(['shoulder_far','rib_far','waist_far','hip_far','hip_near','waist_near','rib_near','shoulder_near','shoulder_far'],'#adcfd6',.85),(['pelvis','chest','neck'],'#adcfd6',.7),(['hip_near','knee_near','ankle_near'],'#e3f5f5',1),(['shoulder_near','elbow_near','palm_near'],'#e3f5f5',1)]
def rotate(v,a):return (v[0]*math.cos(a)-v[1]*math.sin(a),v[0]*math.sin(a)+v[1]*math.cos(a))
def draw_pose(draw,pose,origin,scale,contacts=True,ledge=None):
 b=pose['bones'];f=pose['facing'];ox,oy=origin
 def point(v):return (ox+v[0]*scale,oy+v[1]*scale)
 if ledge:
  x,y=point(ledge);draw.line((x,y,x+26*scale,y),fill='#7f805d',width=max(1,round(scale*.4)));draw.line((x,y,x,y+35*scale),fill='#7f805d',width=max(1,round(scale*.4)))
 for names,color,w in CHAINS:draw.line([point(b[k]) for k in names],fill=color,width=max(1,round(scale*w)),joint='curve')
 for side,c in [('far','#6e96a3'),('near','#e3f5f5')]:
  draw.line([point(b['heel_'+side]),point(b['toe_'+side])],fill=c,width=max(1,round(scale*1.35)))
  draw.line([point(b['heel_'+side]),point(b['ankle_'+side]),point(b['toe_'+side])],fill=c,width=max(1,round(scale*.7)),joint='curve')
  p=b['palm_'+side];e=b['elbow_'+side];v=(p[0]-e[0],p[1]-e[1]);mag=max(math.hypot(*v),.0001);d=(v[0]/mag,v[1]/mag);n=(-d[1],d[0])
  idx=0 if side=='near' else 1
  if pose.get('wall_support') and pose['wall_touch_hands'][idx]:
   normal=pose['wall_normal']
   draw.line([point((p[0],p[1]-1.1)),point((p[0],p[1]+1.1))],fill=c,width=max(1,round(scale*1.2)))
   draw.line([point((p[0],p[1]-1.1)),point((p[0]+normal[0],p[1]+normal[1]))],fill=c,width=max(1,round(scale*.8)))
  elif (pose['ledge_support'] or pose.get('climb_support')) and pose['planted_hands'][idx]:
   draw.line([point((p[0]-1.1*f,p[1])),point((p[0]+1.1*f,p[1]))],fill=c,width=max(1,round(scale*1.2)))
   draw.line([point((p[0]-1.1*f,p[1])),point((p[0],p[1]-1))],fill=c,width=max(1,round(scale*.8)))
  else:
   draw.line([point((p[0]-.9*n[0],p[1]-.9*n[1])),point((p[0]+.9*n[0],p[1]+.9*n[1])),point((p[0]+1.7*d[0]+.65*n[0],p[1]+1.7*d[1]+.65*n[1]))],fill=c,width=max(1,round(scale*.8)),joint='curve')
  if contacts:
   idx=0 if side=='near' else 1
   for kind,on,color in [('sole',pose['planted_feet'][idx],'#6beaac'),('palm',pose['planted_hands'][idx],'#f2bd66')]:
    if on:
     x,y=point(b[kind+'_'+side]);r=max(1,scale*.5);draw.ellipse((x-r,y-r,x+r,y+r),fill=color)
 h=b['head'];a=math.radians(pose['head_tilt']);hs=pose['head_scale'];outline=[]
 for x,y in HEAD:
  x,y=rotate((x*hs[0],y*hs[1]),a);outline.append(point((h[0]+x*f,h[1]+y)))
 draw.line(outline,fill='#e3f5f5',width=max(1,round(scale)),joint='curve')
 x,y=rotate((1,-.4),a);draw.line([point(h),point((h[0]+x*f,h[1]+y))],fill='#e3f5f5',width=max(1,round(scale*.8)))
 for k in ['knee_near','elbow_near']:
  x,y=point(b[k]);r=scale*.55;draw.ellipse((x-r,y-r,x+r,y+r),fill='#e3f5f5')
 weapon=pose.get('weapon',{})
 if weapon.get('visible'):
  color='#faebb8' if weapon.get('contact') else '#bacfd6'
  draw.line([point(weapon['pommel']),point(weapon['grip'])],fill=color,width=max(1,round(scale*1.5)))
  draw.line([point(weapon['guard_a']),point(weapon['guard_b'])],fill=color,width=max(1,round(scale*1.25)))
  draw.line([point(weapon[k]) for k in ['blade_a','tip','blade_b','blade_a']],fill=color,width=max(1,round(scale*.85)),joint='curve')
  if weapon.get('confirmed'):
   tip=weapon['tip']
   for a in [-.8,0,.8]:
    v=rotate((f,0),a);draw.line([point((tip[0]+v[0]*2,tip[1]+v[1]*2)),point((tip[0]+v[0]*5,tip[1]+v[1]*5))],fill='#ffd17a',width=max(1,round(scale)))

def make_sheet():
 labels=list(dict.fromkeys(r['label'] for r in SAMPLES));cw=306;ch=196;w=3*cw+24;h=62+math.ceil(len(labels)/3)*ch
 im=Image.new('RGB',(w,h),'#09121c');d=ImageDraw.Draw(im);font=ImageFont.truetype(FONT,11);title=ImageFont.truetype(FONT,16)
 d.text((14,10),'MOKSHA | ORIGINAL MOVEMENT KEY POSES',font=title,fill='#e3f5f5');d.text((14,34),'4x inspection. Authored vectors, not a gameplay capture. Green soles / amber palm contacts.',font=font,fill='#a8c8d0')
 for i,name in enumerate(labels):
  x=12+(i%3)*cw;y=60+(i//3)*ch
  d.rounded_rectangle((x,y,x+cw-10,y+ch-10),radius=4,fill='#112330',outline='#29414f');d.text((x+8,y+6),name,font=font,fill='#d2e8ea')
  for k,row in enumerate(r for r in SAMPLES if r['label']==name):
   ox=x+35+k*72;oy=y+157
   d.line((ox-30,oy,ox+31,oy),fill='#274657',width=1)
   pose=row['pose'];ledge=row['telemetry']['palm_target'] if name.startswith('ledge') else None
   draw_pose(d,pose,(ox,oy),3.65,True,ledge)
   d.text((ox-12,y+172),f"{pose['phase']:.2f}",font=font,fill='#a8c8d0')
 im.save(ROOT/'pose_contact_sheet.png')
 im.crop((0,0,w,min(h,62+3*ch))).save(ROOT/'ground_air_detail.png')
 im.crop((0,max(0,h-3*ch),w,h)).save(ROOT/'landing_ledge_detail.png')

def actual_scale():
 # This is deliberately640x360 at1 drawing pixel per authored source pixel.
 im=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(im);font=ImageFont.truetype(FONT,10);title=ImageFont.truetype(FONT,13)
 d.text((14,10),'MOKSHA | 34 PX RIG AT 1:1 GAME SCALE',font=title,fill='#e3f5f5');d.text((14,29),'Offline pose preview. No gameplay or controller-capture claim.',font=font,fill='#9abac5')
 groups=[['idle','start','run','brake','turn'],['jump','air_jump','jump_apex','fall','land'],['land_run','crouch','ledge_hang','ledge_pull','ledge_step']]
 for ry,labels in enumerate(groups):
  for cx,label in enumerate(labels):
   x=16+cx*124;y=65+ry*96
   row=next(r for r in SAMPLES if r['label']==label and r['pose']['phase']==(.5 if label not in ['land','land_run'] else .0))
   d.text((x,y),label,font=font,fill='#a8c8d0')
   d.line((x,y+58,x+104,y+58),fill='#345567',width=1)
   draw_pose(d,row['pose'],(x+46,y+58),1,False,row['telemetry']['palm_target'] if label.startswith('ledge') else None)
 im.save(ROOT/'actual_scale_preview.png')
if __name__=='__main__':
 make_sheet();actual_scale()
 print(ROOT/'pose_contact_sheet.png');print(ROOT/'actual_scale_preview.png')
