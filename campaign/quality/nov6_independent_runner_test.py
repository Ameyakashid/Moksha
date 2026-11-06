#!/usr/bin/env python3
"""Adversarial receipt/exit checks for the Nov6 aggregate runner, no Godot needed."""
from pathlib import Path
import importlib.util
import json
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("nov6_runner", ROOT / "tools/verify_nov6.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
MARKER = "FIXTURE_RESULT "
failures = []
checks = 0


def check(value, label):
    global checks
    checks += 1
    if not value:
        failures.append(label)


receipt = {"passed": True, "failures": [], "checks": 1}
valid = MARKER + json.dumps(receipt)
check(runner.parse_receipt(valid, MARKER)["passed"], "valid one-check receipt accepted")
for label, log in [
    ("missing", ""),
    ("duplicate", valid + "\n" + valid),
    ("malformed", MARKER + "{"),
    ("failure flag", MARKER + json.dumps({**receipt, "passed": False})),
    ("failure list", MARKER + json.dumps({**receipt, "failures": ["broken"]})),
    ("zero checks", MARKER + json.dumps({**receipt, "checks": 0})),
    ("negative checks", MARKER + json.dumps({**receipt, "checks": -1})),
    ("boolean checks", MARKER + json.dumps({**receipt, "checks": True})),
    ("missing checks", MARKER + json.dumps({"passed": True, "failures": []})),
]:
    check(not runner.parse_receipt(log, MARKER)["passed"], label + " rejects acceptance")

with tempfile.TemporaryDirectory(prefix="moksha-independent-runner-") as directory:
    output = Path(directory)
    for name, log, code, expected in [
        ("clean", valid, 0, True),
        ("engine_error", "SCRIPT ERROR: Fixture failed\n" + valid, 0, False),
        ("nonzero", valid, 1, False),
        ("receipt_missing", "nothing ran", 0, False),
    ]:
        command = [sys.executable, "-c", f"print({log!r}); raise SystemExit({code})"]
        result = runner.run_case(name, command, output, MARKER, 10)
        check(result["passed"] is expected, name + " run-case rejection semantics")
    command = [sys.executable, "-c", "print('NOV6_PRESENTATION checks=0 failures=[] worst_header=0')"]
    result = runner.run_case("presentation_empty", command, output, None, 10)
    check(not result["passed"], "zero-check presentation rejects acceptance")

print("NOV6_INDEPENDENT_RUNNER " + json.dumps({"passed": not failures, "checks": checks, "failures": failures}))
raise SystemExit(bool(failures))
