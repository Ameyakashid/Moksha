#!/usr/bin/env python3
"""Summarize frozen input-route JSONs without making human-playtime claims."""
from __future__ import annotations
import argparse
import collections
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--baseline", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
prefix = "mission_route_baseline_" if args.baseline else "mission_route_"
rows = []
for hz in (60, 120):
    for choice in ("retained", "sacrificed"):
        path = root / "demo" / "evidence" / f"{prefix}{hz}hz_{choice}.json"
        if not path.exists():
            rows.append({"hz": hz, "choice": choice, "status": "missing"})
            continue
        data = json.loads(path.read_text())
        entered = {}
        for event in data.get("events", []):
            if event.get("event") == "sector_enter":
                entered.setdefault(event["sector"], event)
        authored = sum(len(event.get("enemy_tuning", [])) for event in entered.values())
        outcomes = collections.Counter(receipt.get("outcome", "unknown") for receipt in data.get("damage_receipts", []))
        rows.append({
            "hz": hz, "choice": choice,
            "phase": data.get("validation_phase", "unspecified"),
            "completed": data.get("completed", False),
            "simulated_active_seconds": round(data.get("simulated_active_seconds", 0), 3),
            "sector_completions": len(data.get("sectors", [])),
            "authored_enemies": authored,
            "kills_including_retries": data.get("kills", 0),
            "archives": data.get("caches", 0),
            "deaths": data.get("deaths", 0), "retries": data.get("retry_count", 0),
            "failures": data.get("failures", []),
            "sources_changed_during_run": data.get("sources_changed_during_run", []),
            "damage_outcomes": dict(outcomes),
            "human_duration_validated": False,
        })
print(json.dumps(rows, indent=2))
