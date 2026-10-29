#!/usr/bin/env python3
"""Actual clean no-autoload reuse with the four cache runtime dependencies."""
from pathlib import Path
import hashlib,json,os,shutil,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'simulation/evidence';WORK=ROOT.parent/'field_cache_isolated'
FILES=['simulation/world/field_cache.tscn','simulation/world/field_cache.gd','demo/views/field_cache_view.gd','demo/views/field_cache_appearance.gd']
WORK.mkdir(exist_ok=True)
for rel in FILES:
 dest=WORK/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/rel,dest)
(WORK/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Isolated Field Cache"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
(WORK/'verify.gd').write_text('''extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var packed=load("res://simulation/world/field_cache.tscn")
 var a=packed.instantiate();var b=packed.instantiate()
 root.add_child(a);root.add_child(b)
 assert(root.get_node_or_null("NoiseBus")==null)
 assert(a.appearance!=b.appearance)
 assert(a.get_node("CacheContour/Shape").shape!=b.get_node("CacheContour/Shape").shape)
 a.appearance.ink=Color.RED;a.is_found=true
 assert(a.get_node("View").is_found and a.get_node("CacheContour").is_in_group("sonar_ignore"))
 assert(not b.is_found and b.appearance.ink==Color("b1c9d1"))
 assert(a.get_node("CacheContour").collision_layer==0 and a.get_node("CacheContour").collision_mask==0)
 assert(a.get_node("CacheContour/Shape").shape.size==Vector2(16,18) and not a.get_node("CacheContour/Shape").disabled)
 a.get_node("View").free();a.is_found=false
 assert(not a.get_node("CacheContour").is_in_group("sonar_ignore"))
 print("ISOLATED FIELD CACHE PASS")
 quit()
''')
env=dict(os.environ,XDG_DATA_HOME=str(WORK/'data'),XDG_CONFIG_HOME=str(WORK/'config'),XDG_CACHE_HOME=str(WORK/'cache'))
run=subprocess.run([os.environ.get('GODOT_BIN','godot'),'--headless','--path',str(WORK),'--script','res://verify.gd'],env=env,capture_output=True,text=True,timeout=90)
log=run.stdout+run.stderr;(OUT/'field_cache_isolated.log').write_text(log)
passed=run.returncode==0 and 'ISOLATED FIELD CACHE PASS' in log and 'ERROR:' not in log
report={'passed':passed,'exit_code':run.returncode,'runtime_files':{rel:hashlib.sha256((WORK/rel).read_bytes()).hexdigest() for rel in FILES},'autoloads':[],'project':str(WORK)}
(OUT/'field_cache_isolated.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(0 if passed else 1)
