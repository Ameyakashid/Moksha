#!/usr/bin/env python3
"""Clean no-autoload/minimal-project reuse of just the onward marker dependencies."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'simulation/evidence'
WORK=ROOT.parent/'onward_marker_isolated'
FILES=['simulation/world/onward_marker.tscn','simulation/world/onward_marker.gd','demo/views/onward_marker_view.gd','demo/views/onward_marker_appearance.gd']
WORK.mkdir(exist_ok=True)
for rel in FILES:
 dest=WORK/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,dest)
(WORK/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Isolated Onward Marker"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
(WORK/'verify.gd').write_text('''extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var packed=load("res://simulation/world/onward_marker.tscn")
 var a=packed.instantiate();var b=packed.instantiate()
 root.add_child(a);root.add_child(b)
 assert(root.get_node_or_null("NoiseBus")==null)
 assert(a.appearance!=b.appearance)
 assert(a.get_node("GateContour/Shape").shape!=b.get_node("GateContour/Shape").shape)
 a.is_open=true;a.ending=true;a.appearance.open_ink=Color.RED
 assert(a.get_node("View").is_open and a.get_node("View").ending)
 assert(not b.is_open and not b.ending and b.appearance.open_ink==Color("a5e6cc"))
 assert(a.get_node("GateContour").collision_layer==0 and a.get_node("GateContour").collision_mask==0)
 assert(a.get_node("GateContour/Shape").shape.size==Vector2(40,76))
 print("ISOLATED ONWARD MARKER PASS")
 quit()
''')
env=dict(os.environ,XDG_DATA_HOME=str(WORK/'data'),XDG_CONFIG_HOME=str(WORK/'config'),XDG_CACHE_HOME=str(WORK/'cache'))
run=subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(WORK),'--script','res://verify.gd'],env=env,capture_output=True,text=True,timeout=90)
log=run.stdout+run.stderr
(OUT/'onward_marker_isolated.log').write_text(log)
passed=run.returncode==0 and 'ISOLATED ONWARD MARKER PASS' in log and 'ERROR:' not in log
report={'passed':passed,'exit_code':run.returncode,'runtime_files':{rel:hashlib.sha256((WORK/rel).read_bytes()).hexdigest() for rel in FILES},'autoloads':[],'project':str(WORK),'scope':'Fresh minimal project containing only the marker and its view/config dependencies.'}
(OUT/'onward_marker_isolated.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2));raise SystemExit(0 if passed else 1)
