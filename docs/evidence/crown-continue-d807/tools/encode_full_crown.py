#!/usr/bin/env python3
"""Encode accepted native raw movie continuously, without speed-up; split if necessary."""
import argparse,json,pathlib,subprocess,math,hashlib
p=argparse.ArgumentParser();p.add_argument('output',type=pathlib.Path);a=p.parse_args();out=a.output
v=json.loads((out/'verification.json').read_text());m=json.loads((out/'manifest.json').read_text())
assert v['passed'] and m['mode']=='continue'
raw=out/'raw-crown-continue.avi';assert raw.is_file()
probe=lambda f:json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(f)]))
meta=probe(raw);duration=float(meta['format']['duration'])
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
labels=[f"FULL CROWN | {m['commit'][:7]} | Linux native | AUTOMATED",'Continue from genuine campaign checkpoint | 1x playback',f"{m['lens'].title()} | Sight {m['sight']} | 60 Hz simulation"]
vf='fps=30,pad=640:416:0:0:black,'+','.join(f"drawtext=fontfile={font}:text='{s}':fontsize=11:fontcolor=white:x=8:y={365+17*i}" for i,s in enumerate(labels))
master=out/('MOKSHA-Full-Crown-'+m['commit'][:7]+'-native-automated.mp4')
assert not master.exists()
subprocess.run(['ffmpeg','-v','warning','-i',str(raw),'-vf',vf,'-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart','-threads','2',str(master)],check=True)
limit=19*1024*1024;parts=[];coverage=[]
master_info=probe(master);master_video=next(x for x in master_info['streams'] if x['codec_type']=='video');master_frames=int(master_video['nb_frames'])
assert abs(float(master_info['format']['duration'])-duration)<(1/30+0.01),'Unexpected timeline duration change'
if master.stat().st_size<=limit:
 parts=[master];coverage=[{'first_frame':0,'end_frame_exclusive':master_frames}]
else:
 info=probe(master);video=next(s for s in info['streams'] if s['codec_type']=='video');count=int(video['nb_frames']);n=math.ceil(master.stat().st_size/limit)+1;span=math.ceil(count/n)
 for i,start in enumerate(range(0,count,span)):
  end=min(count,start+span);part=out/(master.stem+f'-part{i+1:02d}.mp4');assert not part.exists()
  subprocess.run(['ffmpeg','-v','warning','-i',str(master),'-vf',f'trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS','-af',f'atrim=start={start/30}:end={end/30},asetpts=PTS-STARTPTS','-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart','-threads','2',str(part)],check=True)
  assert part.stat().st_size<limit,'Part exceeded limit; preserve and split more finely, do not deliver'
  parts.append(part);coverage.append({'first_frame':start,'end_frame_exclusive':end})
  actual=int(next(x for x in probe(part)['streams'] if x['codec_type']=='video')['nb_frames']);assert actual==end-start,'Part frame loss or duplication'
assert coverage[0]['first_frame']==0 and coverage[-1]['end_frame_exclusive']==master_frames
assert all(coverage[i]['end_frame_exclusive']==coverage[i+1]['first_frame'] for i in range(len(coverage)-1))
result={'master_frame_count':master_frames,'part_frame_coverage':coverage,'timeline_verified':True,'raw_duration':duration,'master':master.name,'master_bytes':master.stat().st_size,'parts':[{'name':f.name,'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'duration':probe(f)['format']['duration']} for f in parts],'method':'Continuous entire raw native Continue movie, including ending;30fps1x from60Hz, no gameplay omissions or speed-up. Split master by adjacent frame intervals if needed.'}
(out/'media-manifest.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
