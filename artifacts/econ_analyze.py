#!/usr/bin/env python3
"""#390 — Economic Integrity analyzer.

Reads the per-attempt ledgers (econ_ledgers/econ_<cell>_<date>.jsonl, written
by layer3/portable_client._econ_log) plus the bench result JSONs
(results_econ_<cell>_part*_<date>.json, which carry per-rep agent_modes and
boards) and computes the measured quantities the reliability paper could not:

  per cell, per LAYER (agent vs debate — never pooled):
    logical jobs, physical attempts, IAF = attempts / logical jobs
    starvation events (attempt-1 empty), recovered (attempt-2 non-empty),
    unrecovered (final attempt empty)
    paid-but-discarded tokens/cost: every attempt whose output was thrown
    away (an empty attempt followed by a retry, or a final empty attempt)
    ECI = total spend / spend on attempts whose output was actually used
  per rep: cost joined to outcome tier (first-attempt-clean / recovered /
    degraded) using agent_modes from the result JSONs.

Pricing: per-model list rates keyed on the ledger row's `model` field —
DeepSeek direct list (0.435 in / 0.87 out per M) from the repo price tables;
kimi-k3 Moonshot list (3.00 in / 15.00 out per M, platform.kimi.ai/docs/
pricing/chat-k3.md, verified 2026-08-13 against the measured ~$14 reactive-cell
balance drain — output_tokens already include reasoning tokens). Cache-hit
input tokens are priced at the FULL input rate, so dollar figures are upper
bounds; hit/miss splits are reported alongside. IAF/ECI
denominators are MEASURED here (every attempt is a ledger row) — the paper's
"attempts were not instrumented" caveat does not apply to these runs.

Usage: econ_analyze.py [--date YYYY-MM-DD]
"""
import argparse
import glob
import json
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).parent
# $/M tokens (input, output), list prices — see module docstring for sources.
RATES = {
    "deepseek": (0.435, 0.87),   # DeepSeek direct
    "kimi-k3": (3.00, 15.00),    # Moonshot list; output includes reasoning
}
_DEFAULT_RATE = RATES["deepseek"]


def cost_usd(row):
    model = (row.get("model") or "").lower()
    rate_in, rate_out = _DEFAULT_RATE
    for key, rates in RATES.items():
        if key in model:
            rate_in, rate_out = rates
            break
    return (row["input_tokens"] / 1e6) * rate_in + (row["output_tokens"] / 1e6) * rate_out


def load_ledger(cell, date):
    path = HERE / "econ_ledgers" / f"econ_{cell}_{date}.jsonl"
    if not path.exists():
        return []
    rows = []
    for line in path.read_text().splitlines():
        if line.strip():
            rows.append(json.loads(line))
    return rows


def load_results(cell, date):
    # Result JSONs live beside the analyzer in the repo run layout, but under
    # results/ in the published artifact bundle — accept either.
    files = sorted(
        set(glob.glob(str(HERE / f"results_econ_{cell}_part*_{date}.json")))
        | set(glob.glob(str(HERE / "results" / f"results_econ_{cell}_part*_{date}.json"))))
    reps = []
    for f in files:
        part = f.rsplit("part", 1)[1].split("_")[0]
        for r in json.load(open(f)):
            r["_part"] = part
            reps.append(r)
    return reps


def analyze_cell(cell, date):
    ledger = load_ledger(cell, date)
    results = load_results(cell, date)
    if not ledger:
        return None

    out = {"cell": cell, "date": date, "reps_graded": len(results)}

    for layer in ("agent", "debate"):
        rows = [r for r in ledger if r["layer"] == layer]
        if not rows:
            out[layer] = {"logical_jobs": 0, "attempts": 0}
            continue
        # A logical job is unique within (cell:part, rep, logical_job_id).
        jobs = defaultdict(list)
        for r in rows:
            jobs[(r["cell"], r["rep"], r["logical_job_id"])].append(r)
        for k in jobs:
            jobs[k].sort(key=lambda r: r["attempt_no"])

        attempts = len(rows)
        n_jobs = len(jobs)
        starved = sum(1 for js in jobs.values() if js[0]["content_empty"])
        retried = sum(1 for js in jobs.values() if len(js) > 1)
        recovered = sum(1 for js in jobs.values()
                        if len(js) > 1 and not js[-1]["content_empty"])
        unrecovered = sum(1 for js in jobs.values() if js[-1]["content_empty"])
        errors = sum(1 for r in rows if r["outcome"] == "error")

        total_cost = sum(cost_usd(r) for r in rows)
        # An attempt's output was USED iff it is the job's final attempt and
        # non-empty. Everything else was paid for and discarded.
        used_cost = sum(cost_usd(js[-1]) for js in jobs.values()
                        if not js[-1]["content_empty"])
        discarded_rows = [r for js in jobs.values() for r in js
                          if r is not js[-1] or js[-1]["content_empty"]]
        discarded_cost = sum(cost_usd(r) for r in discarded_rows)
        discarded_reasoning = sum(r["reasoning_tokens"] for r in discarded_rows)
        discarded_out = sum(r["output_tokens"] for r in discarded_rows)

        out[layer] = {
            "logical_jobs": n_jobs,
            "attempts": attempts,
            "IAF": round(attempts / n_jobs, 4) if n_jobs else None,
            "starvation_events_attempt1": starved,
            "retries_issued": retried,
            "recovered_by_retry": recovered,
            "unrecovered_final_empty": unrecovered,
            "transport_errors": errors,
            "tokens_in": sum(r["input_tokens"] for r in rows),
            "tokens_out": sum(r["output_tokens"] for r in rows),
            "tokens_reasoning": sum(r["reasoning_tokens"] for r in rows),
            "cache_hit_tokens": sum(r["cache_hit_tokens"] for r in rows),
            "cache_miss_tokens": sum(r["cache_miss_tokens"] for r in rows),
            "cost_total_usd": round(total_cost, 4),
            "cost_used_usd": round(used_cost, 4),
            "cost_discarded_usd": round(discarded_cost, 4),
            "discarded_reasoning_tokens": discarded_reasoning,
            "discarded_output_tokens": discarded_out,
            "ECI": round(total_cost / used_cost, 4) if used_cost else None,
        }

    # Per-rep outcome tiers joined to per-rep agent-layer cost.
    rep_cost = defaultdict(float)
    rep_retries = defaultdict(int)
    for r in ledger:
        if r["layer"] != "agent":
            continue
        part = r["cell"].split("part")[-1] if "part" in r["cell"] else "?"
        key = (part, r["rep"])
        rep_cost[key] += cost_usd(r)
        if r["attempt_no"] > 1:
            rep_retries[key] += 1
    tiers = []
    for res in results:
        key = (res["_part"], str(res["rep"]))
        modes = res.get("agent_modes") or {}
        agent_clean = all(v == "llm" for v in modes.values()) if modes else None
        n_ret = rep_retries.get(key, 0)
        tier = ("first_attempt_clean" if agent_clean and n_ret == 0 else
                "recovered_clean" if agent_clean else "degraded")
        tiers.append({
            "part": key[0], "rep": key[1], "tier": tier,
            "agent_retries": n_ret,
            "agent_cost_usd": round(rep_cost.get(key, 0.0), 4),
            "fallback_agents": [k for k, v in modes.items() if v != "llm"],
        })
    out["rep_tiers"] = tiers
    by_tier = defaultdict(list)
    for t in tiers:
        by_tier[t["tier"]].append(t["agent_cost_usd"])
    out["cost_by_tier"] = {
        k: {"n": len(v), "mean_usd": round(sum(v) / len(v), 4)}
        for k, v in by_tier.items()
    }
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", default=None)
    args = ap.parse_args()
    date = args.date
    if not date:
        candidates = sorted(glob.glob(str(HERE / "econ_ledgers" / "econ_*_*.jsonl")))
        if not candidates:
            raise SystemExit("no ledgers found")
        date = candidates[-1].rsplit("_", 1)[1].replace(".jsonl", "")

    report = {}
    base_cells = ("reactive", "proactive", "pure_retry", "bundle")
    # Cross-model legs write ledgers as econ_<prefix>_<cell>_<date>.jsonl
    # (e.g. kimi_reactive from the 2026-08-12 seed campaign).
    cells = list(base_cells) + [f"kimi_{c}" for c in base_cells]
    for cell in cells:
        a = analyze_cell(cell, date)
        if a:
            report[cell] = a
            ag = a["agent"]
            print(f"\n== {cell} (n graded: {a['reps_graded']}) ==")
            print(f"  agent : jobs={ag['logical_jobs']} attempts={ag['attempts']} "
                  f"IAF={ag['IAF']} starved={ag['starvation_events_attempt1']} "
                  f"recovered={ag['recovered_by_retry']} unrecovered={ag['unrecovered_final_empty']}")
            print(f"          cost total=${ag['cost_total_usd']} used=${ag['cost_used_usd']} "
                  f"discarded=${ag['cost_discarded_usd']} ECI={ag['ECI']}")
            db = a["debate"]
            if db.get("logical_jobs"):
                print(f"  debate: jobs={db['logical_jobs']} attempts={db['attempts']} "
                      f"IAF={db['IAF']} starved={db['starvation_events_attempt1']} "
                      f"cost total=${db['cost_total_usd']} ECI={db['ECI']}")
            print(f"  tiers : {a['cost_by_tier']}")

    out_path = HERE / f"econ_report_{date}.json"
    out_path.write_text(json.dumps(report, indent=1))
    print(f"\nwrote {out_path}")


if __name__ == "__main__":
    main()
