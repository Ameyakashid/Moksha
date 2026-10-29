#!/usr/bin/env python3
"""Original climb vectors with authoritative rung guides. Not gameplay capture."""
import json,math
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from render_previews import draw_pose,FONT
ROOT=Path(__file__).resolve().parent
SAMPLES=json.loads((ROOT/'climb_pose_samples.json').read_text())['samples']
LABELS=list(dict.fromkeys(s['label'] for s in SAMPLES))
def guide(d,t,origin,scale):
 if not t.get('climb_active'):return
 ox,oy=origin;root=t['position'];axis=t['climb_axis_x']-root[0];top=max(-42,t['climb_top_y']-root[1]);bottom=min(2,t['climb_bottom_y']-root[1]);half=t.get('climb_width',20)*.3
 def p(x,y):return(ox+x*scale,oy+y*scale)
 color='#315852';width=max(1,round(scale*.35));vine=t['climb_type']=='vine'
 if vine:d.line([p(axis,top),p(axis,bottom)],fill=color,width=width)
 else:
  for direction in [-1,1]:d.line([p(axis+half*direction,top),p(axis+half*direction,bottom)],fill=color,width=width)
 rung=t['climb_bottom_y']-t['climb_rung_origin_offset']-root[1]
 spacing=t['climb_rung_spacing']
 while rung>bottom:rung-=spacing
 while rung>=top:
  if vine:d.line([p(axis-4,rung+3),p(axis+4,rung-3)],fill=color,width=width)
  else:d.line([p(axis-half,rung),p(axis+half,rung)],fill=color,width=width)
  rung-=spacing
font=ImageFont.truetype(FONT,12);title=ImageFont.truetype(FONT,16)
w=860;ch=176;h=64+ch*len(LABELS)
im=Image.new('RGB',(w,h),'#09121c');d=ImageDraw.Draw(im)
d.text((16,10),'MOKSHA | ORIGINAL LADDER / VINE POSES',font=title,fill='#e3f5f5')
d.text((16,34),'3x travel/phase samples. Idle holds do not cycle. Offline vectors, not gameplay.',font=font,fill='#a8c8d0')
for i,label in enumerate(LABELS):
 y=60+i*ch;d.rounded_rectangle((12,y,w-12,y+ch-9),radius=5,fill='#112330',outline='#29414f')
 d.text((22,y+8),label,font=font,fill='#d2e8ea')
 for j,row in enumerate(s for s in SAMPLES if s['label']==label):
  x=86+j*205;oy=y+134
  guide(d,row['telemetry'],(x,oy),3)
  draw_pose(d,row['pose'],(x,oy),3,True)
  d.text((x-12,y+147),f"{row['pose']['phase']:.2f}",font=font,fill='#a8c8d0')
im.save(ROOT/'climb_contact_sheet.png')
im.crop((0,0,w,64+ch*4)).save(ROOT/'climb_entry_hold_detail.png')
im.crop((0,h-6*ch,w,h)).save(ROOT/'climb_exit_detail.png')
small=Image.new('RGB',(640,360),'#09121c');d=ImageDraw.Draw(small)
d.text((14,10),'MOKSHA | CLIMB AT 1:1 GAME SCALE',font=ImageFont.truetype(FONT,13),fill='#e3f5f5')
d.text((14,31),'Original 34px rig / 20px low body. Offline vectors.',font=ImageFont.truetype(FONT,10),fill='#9abac5')
entries=['climb_align','climb_idle','climb_ascend','climb_descend','climb_top_exit','climb_blocked','climb_release','climb_idle_vine','climb_ascend_vine','climb_ascend_low']
for i,label in enumerate(entries):
 row=next(s for s in SAMPLES if s['label']==label and s['pose']['phase']==.5)
 x=12+126*(i%5);y=84+132*(i//5)
 d.text((x,y),label.removeprefix('climb_'),font=ImageFont.truetype(FONT,10),fill='#a8c8d0')
 guide(d,row['telemetry'],(x+52,y+75),1)
 draw_pose(d,row['pose'],(x+52,y+75),1,False)
small.save(ROOT/'climb_actual_scale.png')
print(ROOT/'climb_contact_sheet.png');print(ROOT/'climb_actual_scale.png')
