#!/usr/bin/env python3
"""Reproduce stale observer holds and verify ordinary neutral-input recovery.

This is diagnostic/observer evidence, never a production workaround or a full
campaign claim. Explicit initial district/build setup precedes measured input.
Existing reports are not reused or overwritten.
"""
from __future__ import annotations
import argparse, concurrent.futures, hashlib, json, os, pathlib, re, subprocess, time

PROJECT = pathlib.Path(__file__).resolve().parents[2]
SOURCE_PATHS = ["campaign/logic/campaign.gd", "campaign/logic/campaign_input_gate.gd", "combat_pc/player.gd", "campaign/quality/nov6_gameplay_exchange_probe.gd", "campaign/quality/nov6_modal_route_input.gd", "campaign/quality/nov6_freight_route_input.gd", "campaign/quality/nov6_modal_route_observer_test.gd", "campaign/quality/nov6_full_campaign_route.gd", "campaign/quality/nov6_full_campaign_strength_route.gd", "campaign/quality/nov6_full_campaign_route_120_sonar.gd"]

def hashes():
    return {name: hashlib.sha256((PROJECT/name).read_bytes()).hexdigest() for name in SOURCE_PATHS}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output",type=pathlib.Path,required=True)
    args=parser.parse_args();out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    before=hashes()
    cases=[]
    for hz in [60,120]:
        for lens in ["neutral","strength"]:
            for mode in ["stale","release"]:
                cases.append(("l2_exchange",lens,hz,mode))
        for mode in ["stale","release"]:
            cases.append(("l3_homes","agility",hz,mode))
    cases.append(("l2_exchange","neutral",60,"rescue"))
    def run(case):
        district,lens,hz,mode=case
        name=f"{district}_{lens}_{hz}_{mode}"
        env=dict(os.environ)
        for key in ["HOME","XDG_DATA_HOME","XDG_CONFIG_HOME","XDG_CACHE_HOME"]:
            d=out/"user_data"/name/key;d.mkdir(parents=True);env[key]=str(d)
        report_path=out/(name+".json")
        command=[os.environ.get("GODOT_BIN","godot"),"--headless","--path",str(PROJECT),"--fixed-fps",str(hz),"--script","res://campaign/quality/nov6_gameplay_exchange_probe.gd","--",f"--hz={hz}",f"--lens={lens}",f"--district={district}","--seconds=240",f"--output={report_path}"]
        if mode=="release":command.append("--release-after-modal")
        elif mode=="rescue":command.append("--rescue-after-stall")
        start=time.monotonic()
        with (out/(name+".log")).open("w") as log:
            try:result=subprocess.run(command,cwd=PROJECT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240);code=result.returncode
            except subprocess.TimeoutExpired:code=124
        log=(out/(name+".log")).read_text()
        report=json.loads(report_path.read_text()) if report_path.exists() else {}
        stall=report.get("stalled_evidence",{})
        errors=[line for line in log.splitlines() if re.match(r"^\s*(SCRIPT ERROR:|ERROR:)",line)]
        expected=(not report.get("reached_next_district",False) and bool(stall)) if mode=="stale" else report.get("reached_next_district",False)
        if mode=="rescue":expected=expected and report.get("did_rescue",False) and bool(stall)
        if mode=="release":expected=expected and any(e.get("event")=="observer_modal_controls_released" and e.get("neutral_physics_frames",0)>=1 for e in report.get("events",[]))
        row={"name":name,"passed":code==0 and not errors and "NOV6_EXCHANGE_PROBE " in log and expected and not report.get("failures") and report.get("deaths")==0,"exit_code":code,"engine_errors":errors,"active_seconds":report.get("actual_seconds"),"reached_next_district":report.get("reached_next_district"),"stall_position":stall.get("position"),"blocked":stall.get("blocked"),"raw":stall.get("raw_input"),"admitted_x":stall.get("admitted_input",{}).get("x"),"wall_seconds":round(time.monotonic()-start,3),"command":command}
        print(json.dumps(row),flush=True)
        return row
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(run,cases))
    after=hashes();drift=[name for name,value in before.items() if after.get(name)!=value]
    summary={"passed":not drift and all(row["passed"] for row in results),"source_sha256":before,"source_drift":drift,"cases":results,"scope":"Explicit isolated district/build fixtures, measured ordinary input only. Stale-input failures are expected diagnostic controls. Automated times are not human duration or full campaign acceptance."}
    (out/"summary.json").write_text(json.dumps(summary,indent=2)+"\n")
    print("NOV6_MODAL_OBSERVER_CHECKS "+str(out/"summary.json"),flush=True)
    raise SystemExit(0 if summary["passed"] else 1)

if __name__=="__main__":main()
