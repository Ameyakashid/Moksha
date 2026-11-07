from pathlib import Path
import subprocess,os,json,time
root=Path(__file__).resolve().parents[1];out=root/'multipad_evidence/final';out.mkdir(exist_ok=True)
cases=[]
for hz in [60,120]:
 for filename,marker in [('campaign/quality/nov6_controller_devices.gd','NOV6_CONTROLLER_DEVICES_RESULT'),('campaign/quality/nov6_gameplay_input.gd','NOV6_GAMEPLAY_INPUT_RESULT'),('campaign/quality/nov6_gamepad_navigation.gd','NOV6_GAMEPAD_NAVIGATION_RESULT'),('campaign/quality/nov6_independent_paused_release.gd','NOV6_INDEPENDENT_PAUSED_RELEASE')]:cases.append((Path(filename).stem+'_'+str(hz),filename,marker,hz))
for name,marker in [('sampling_lifecycle','MULTIPAD_SAMPLING_RESULT'),('unentered_lifecycle','MULTIPAD_UNENTERED_RESULT')]:cases.append((name,'multipad_evidence/'+name+'.gd',marker,120))
results=[]
for name,script,marker,hz in cases:
 case=out/name;case.mkdir(exist_ok=True);env=os.environ.copy()
 for var,part in [('HOME','home'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache')]:
  path=case/part;path.mkdir(exist_ok=True);env[var]=str(path)
 cmd=['godot','--headless','--fixed-fps',str(hz),'--path',str(root),'--script','res://'+script,'--','--hz='+str(hz)]
 start=time.time();p=subprocess.run(cmd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120);(case/'engine.log').write_text(p.stdout)
 lines=[l for l in p.stdout.splitlines() if l.startswith(marker+' ')];r=json.loads(lines[0].split(' ',1)[1]) if len(lines)==1 else {};errors=[l for l in p.stdout.splitlines() if l.startswith(('ERROR:','SCRIPT ERROR:','WARNING:'))]
 result={'name':name,'returncode':p.returncode,'marker_count':len(lines),'passed':p.returncode==0 and len(lines)==1 and r.get('passed') is True and isinstance(r.get('checks'),int) and r['checks']>0 and not r.get('failures') and not errors,'result':r,'errors':errors,'seconds':time.time()-start,'command':cmd};results.append(result);(out/'results.json').write_text(json.dumps(results,indent=2)+'\n');print(name,result['passed'],r.get('checks'),r.get('failures'),errors,flush=True)
raise SystemExit(0 if all(r['passed'] for r in results) else 1)
