#!/usr/bin/env python3
"""Generate review-only data artifacts. Never launches Godot or renders game art."""
import hashlib
from html import escape
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
from check_static import BASE, LAYOUT, ROOT, git, parse

OUT = Path(__file__).resolve().parent
source = (ROOT/LAYOUT).read_text()
before = parse(git('show', f'{BASE}:{LAYOUT}'))
after = parse(source)
report = {
    'scope':'Authored data diff, not verified actor passage or a game screenshot',
    'base_commit':BASE,
    'candidate_layout_sha256':hashlib.sha256(source.encode()).hexdigest(),
    'district_id':after['id'],
    'stable_objective_ids':[goal['id'] for goal in after['objectives']],
    'changes':{key:{'before':before.get(key),'candidate':after.get(key)}
               for key in sorted(set(before)|set(after)) if before.get(key)!=after.get(key)},
}
(OUT/'geometry_diff.json').write_text(json.dumps(report,indent=2)+'\n')
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="610" viewBox="0 0 1200 610">',
       '<rect width="1200" height="610" fill="#111822"/>',
       '<style>text{font-family:monospace;fill:#dce2eb;font-size:11px}.small{font-size:10px}.title{font-size:16px;font-weight:bold}</style>']
def text(x,y,label,css=''):
    svg.append(f'<text x="{x}" y="{y}" class="{css}">{escape(str(label))}</text>')
def rect(x,y,w,h,fill,extra=''):
    svg.append(f'<rect x="{x:g}" y="{y:g}" width="{w:g}" height="{h:g}" fill="{fill}" {extra}/>')
text(25,28,'Memory Loom: same-scale authored geometry comparison','title')
text(25,49,'DATA SCHEMATIC ONLY. No engine run, physics certification, native screenshot or game-art preview.')
text(25,69,'0.2 drawing px / world unit. Blue: fixed ladders. Gold: closed goal doors. Grey: actual supports.')
for data, top, title in [(before,110,'BEFORE / 891f781 / width 5600'),(after,340,'CANDIDATE / width 3900 / public commons; east isolation desk')]:
    text(25,top-16,title,'title')
    X=lambda value:25+value*.2
    Y=lambda value:top+(value+300)*.2
    rect(X(0),Y(300),data['width']*.2,16,'#354452')
    for x,y,w,h in data['platforms']:
        rect(X(x),Y(y),w*.2,max(2,h*.2),'#8898a8' if h>18 else '#596d82')
    for x,bottom,height in data['ladders']:
        rect(X(x)-1.5,Y(bottom-height),3,height*.2,'#5dbac7')
    for door in data['objective_doors']:
        x,y=door['at'];w,h=door['size']
        rect(X(x-w/2),Y(y-h/2),max(4,w*.2),h*.2,'#e7b557')
    for source in data.get('irritants',[]):
        x,y=source['at'];rect(X(x-60),Y(y-32),24,12.8,'#bdb86f','fill-opacity=".55"')
    for enemy in data['enemies']:
        x,kind,y=enemy
        color={'listener':'#ca8eaa','sentinel':'#cd875e','sentry':'#c6b3ed'}[kind]
        rect(X(x)-2.5,Y(y)-8,5,8,color)
    for prop in data['props']:
        x,y=prop;rect(X(x)-2,Y(y)-5,4,5,'#6b786d')
    for goal in data['objectives']:
        x,y=goal['at'];svg.append(f'<circle cx="{X(x)}" cy="{Y(y)-5}" r="3.3" fill="#a6ddbd"/>')
        text(X(x)-24,Y(y)+28,goal['id'],'small')
    spawn=data.get('spawn',[75,300]);x,y=spawn
    svg.append(f'<path d="M {X(x)} {Y(y)-19} l -4 -7 h 8 z" fill="#ffffff"/>')
    text(X(x)-16,Y(y)-32,'START','small')
    text(X(0),Y(300)+52,'0','small');text(X(data['width'])-32,Y(300)+52,data['width'],'small')
text(25,543,'Candidate: no floor gaps, no electric damage, no moving-lift reliance. Same seven enemies and six physical props.')
text(25,563,'West door = first_account. East door = other_account. Exit = preserve after both. Index remains optional vitality.')
text(25,583,'Desk relocation APPLIED / RUNTIME PENDING. Prior 81fbcd0 receipts do not certify this changed route.')
svg.append('</svg>')
(OUT/'geometry_review.svg').write_text('\n'.join(svg)+'\n')
print('Wrote geometry_diff.json and geometry_review.svg (data only).')
