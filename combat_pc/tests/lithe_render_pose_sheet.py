"""Render the exported Godot geometry; this is NOT a native game screenshot."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
samples = json.loads((HERE / 'lithe_pose_samples.json').read_text())
W, H, AA = 1400, 1080, 2
im = Image.new('RGB', (W*AA, H*AA), '#081218')
d = ImageDraw.Draw(im)
fontpath = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(n):
    try: return ImageFont.truetype(fontpath, n*AA)
    except OSError: return ImageFont.load_default()
def text(x,y,t,n=14,c='#91aab3'):
    d.text((x*AA,y*AA),t,font=font(n),fill=c)
def line(points,c,w=1):
    d.line([(x*AA,y*AA) for x,y in points],fill=c,width=max(1,round(w*AA)),joint='curve')

def draw_pose(p, origin, scale=2.8, lithe=True):
    j=p['bones']
    def pt(v): return (origin[0]+v[0]*scale, origin[1]+v[1]*scale)
    def chain(names,c,w=1): line([pt(j[n]) for n in names],c,w*scale)
    front, rear, core = '#ebfaf7','#618a96','#a6c9cf'
    for side,c,w in [('far',rear,.78),('near',front,1)]:
        chain(['hip_'+side,'knee_'+side,'ankle_'+side],c,w)
        chain(['shoulder_'+side,'elbow_'+side,'palm_'+side],c,w)
        chain(['ankle_'+side,'heel_'+side,'toe_'+side,'ankle_'+side],c,.75)
    chain(['shoulder_far','rib_far','waist_far','hip_far','hip_near','waist_near','rib_near','shoulder_near','shoulder_far'],core,.72)
    chain(['pelvis','chest','neck'],core,.72)
    if lithe:
        chain(['hip_far','pelvis','hip_near'],core,.65)
        chain(['shoulder_far','chest','shoulder_near'],core,.65)
    offsets=[(-2.1,-2),(.7,-2.7),(2.2,-1.6),(2.6,-.25),(3.2,.55),(1.6,1.1),(.7,2.5),(-1.8,2),(-2.5,.5),(-2.1,-2)]
    ang=math.radians(p['head_tilt']); hs=p['head_scale']; face=p['facing']
    points=[]
    for x,y in offsets:
        x*=hs[0]; y*=hs[1]
        rx=(x*math.cos(ang)-y*math.sin(ang))*face
        ry=x*math.sin(ang)+y*math.cos(ang)
        points.append(pt((j['head'][0]+rx,j['head'][1]+ry)))
    if lithe: line([pt(j['neck']),points[6]],core,.85*scale)
    line(points,front,.9*scale)
    weapon=p.get('weapon',{})
    if weapon.get('visible'):
        for a,b in [('pommel','grip'),('guard_a','guard_b'),('blade_a','tip'),('tip','blade_b'),('blade_b','blade_a')]:
            line([pt(weapon[a]),pt(weapon[b])],'#c4dce0',.8*scale)
    for i,side in enumerate(['near','far']):
        if p['planted_feet'][i]:
            x,y=pt(j['sole_'+side]);r=1.4*scale*AA
            d.ellipse((x*AA-r,y*AA-r,x*AA+r,y*AA+r),fill='#6bf5b5')

text(30,24,'MOKSHA / LITHE CONNECTED POSE STUDY',26,'#ebfaf7')
text(30,63,'Godot-evaluated geometry, original authored tuning. Diagnostic render; not a native game screenshot.',15)
rows=[('BASELINE RUN','run','baseline'),('LITHE RUN','run','lithe'),('LITHE JUMP','jump','lithe'),('LITHE ROLL START','roll_start','lithe'),('LITHE ROLL TRAVEL','roll_travel','lithe'),('PRESERVED MELEE','attack_slash_active','lithe')]
for ri,(label,mode,variant) in enumerate(rows):
    y=245+ri*156
    text(30,y-130,label,15,'#ebfaf7' if variant=='lithe' else '#91aab3')
    selected=[s for s in samples if s['mode']==mode and s['variant']==variant]
    for index,s in enumerate(selected):
        x=170+index*160
        line([(x-50,y),(x+50,y)],'#263e47',.7)
        draw_pose(s['pose'],(x,y),lithe=variant=='lithe')
        text(x-20,y+10,f"{s['phase']:.3f}",10)
im.resize((W,H),Image.Resampling.LANCZOS).save(HERE/'lithe_pose_sheet.png')
print(HERE/'lithe_pose_sheet.png')
