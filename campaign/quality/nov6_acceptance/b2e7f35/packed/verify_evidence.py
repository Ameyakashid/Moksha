#!/usr/bin/env python3
"""Read-only validation of this portable packed/native evidence set."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
for folder in (ROOT,BASE/"native"):
    index=read(folder/"EVIDENCE_INDEX.json")
    actual={p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file()}
    assert actual==set(index["files"])|{"EVIDENCE_INDEX.json","SHA256SUMS"},"Missing or extra evidence file"
    for relative,row in index["files"].items():
        p=folder/relative;assert p.stat().st_size==row["bytes"] and sha(p)==row["sha256"],relative
    expected="".join(f"{sha(folder/name)}  {name}\n" for name in sorted(actual-{"SHA256SUMS"}))
    assert (folder/"SHA256SUMS").read_text()==expected,"Checksum listing mismatch"
    for row in read(folder/"COPY_RECEIPT.json")["copies"]:
        assert sha(folder/row["destination"])==row["sha256"],"Copied file changed"
report=read(ROOT/"CONTINUED_REHEARSAL_REPORT.json")
assert report["stage_count"]==28 and report["passed"] is True
for row in report["checks"]:
    assert row["passed"] is True and row["exit_code"]==0 and row["errors"]==[]
    assert sha(ROOT/"verification"/(row["name"]+".log"))==row["log_sha256"]
    if "fixture_receipt" in row:
        r=row["fixture_receipt"];assert r["passed"] is True and type(r["checks"]) is int and r["checks"]>0 and r["failures"]==[]
assert read(ROOT/"verification/packed_audio_contract_60.json")["passed"] is False
assert read(ROOT/"aborted-r2/ABORTED_ATTEMPT.json")["completion_claim"] is False
for f in read(ROOT/"AUDIO_FIXTURE_OVERRIDE_MANIFEST.json")["fixtures"]:
    assert sha(ROOT/"frozen-fixtures"/f["path"])==f["frozen_b2_sha256"]
    assert sha(ROOT/"corrected-fixtures"/f["path"])==f["patched_sha256"]
    assert sha(ROOT/"corrected-fixtures"/(f["path"]+".patch"))==f["patch_sha256"]
negative=read(ROOT/"source-root-negative/audio_output_guard_negative.json")["fixture_receipt"]
assert negative["passed"] is True and negative["checks"]==37 and negative["failures"]==[]
native=BASE/"native";capture=read(native/"NATIVE_CAPTURE_RECEIPT.json")
assert capture["capture_count"]==31 and capture["all_capture_errors_zero"] is True and capture["pck_sha256"]==report["pck_sha256"]
assert sha(native/"capture.log")==capture["capture_log_sha256"]
assert sha(native/"fixture/nov6_native_review.gd")==capture["fixture_sha256"]
assert sha(native/"native_review_wrapper.gd")==capture["wrapper_sha256"]
assert len(list((native/"captures").glob("*.png")))==31
for row in capture["captures"]:assert sha(native/row["path"])==row["sha256"]
print("PASS: two hash-indexed evidence folders, 28 accepted stages, preserved failed/aborted attempts, 37 guard checks, 31 native PNGs")
