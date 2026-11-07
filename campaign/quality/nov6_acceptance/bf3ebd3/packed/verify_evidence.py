#!/usr/bin/env python3
"""Read-only validation of the compact exact-source packed/native evidence."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
for folder in (ROOT,BASE/"native"):
 index=read(folder/"EVIDENCE_INDEX.json");actual={p.relative_to(folder).as_posix() for p in folder.rglob("*") if p.is_file()}
 assert actual==set(index["files"])|{"EVIDENCE_INDEX.json","SHA256SUMS"}
 for relative,row in index["files"].items():
  p=folder/relative;assert p.stat().st_size==row["bytes"] and sha(p)==row["sha256"],relative
 assert (folder/"SHA256SUMS").read_text()=="".join(f"{sha(folder/n)}  {n}\n" for n in sorted(actual-{"SHA256SUMS"}))
 for row in read(folder/"COPY_RECEIPT.json")["copies"]:assert sha(folder/row["destination"])==row["sha256"]
r=read(ROOT/"REHEARSAL_REPORT.json");a=read(ROOT/"ARCHIVE_AUDIT_REPORT.json")
assert len(r["checks"])==30 and a["passed"] and a["pck_sha256"]==r["pck_sha256"]
for row,logs in [(x,ROOT/"verification") for x in r["checks"]]+[(a["fresh_archive_check"],ROOT/"archive-audit/verification")]:
 assert row["passed"] is True and row["exit_code"]==0 and not row["errors"]
 assert sha(logs/(row["name"]+".log"))==row["log_sha256"]
 if "fixture_receipt" in row:
  f=row["fixture_receipt"];assert f["passed"] is True and type(f["checks"]) is int and f["checks"]>0 and f["failures"]==[]
for hz in (60,120):
 f=read(ROOT/f"verification/packed_controller_devices_{hz}.json")["fixture_receipt"]
 assert f["checks"]==213 and f["hz"]==hz and f["devices"]==[0,1,3]
identity=read(ROOT/"FROZEN_FIXTURE_VERIFICATION.json");assert identity["exact_git_blobs"] and not identity["fixture_overlays_used"]
for relative,digest in identity["external_fixture_sha256"].items():assert sha(ROOT/"external-fixtures"/relative)==digest
f=read(ROOT/"source-root-negative/audio_output_guard_negative.json")["fixture_receipt"];assert f["passed"] and f["checks"]==37 and f["failures"]==[]
assert read(ROOT/"packaging-unit-tests.json")["tests"]==16
native=BASE/"native";capture=read(native/"NATIVE_CAPTURE_RECEIPT.json")
assert capture["capture_count"]==31 and capture["all_capture_errors_zero"] and capture["pck_sha256"]==r["pck_sha256"]
assert capture["visual_review"]["all_31_reviewed"] and capture["visual_review"]["status"]=="complete"
assert sha(native/"capture.log")==capture["capture_log_sha256"]
assert sha(native/"fixture/nov6_native_review.gd")==capture["fixture_sha256"]
assert sha(native/"native_review_wrapper.gd")==capture["wrapper_sha256"]
assert len(list((native/"captures").glob("*.png")))==31
for row in capture["captures"]:assert sha(native/row["path"])==row["sha256"]
print("PASS: exact-source 30-stage PCK rehearsal plus archive audit, 213 device checks at each rate, 37 guard checks, 16 unit tests, 31 reviewed native PNGs")
