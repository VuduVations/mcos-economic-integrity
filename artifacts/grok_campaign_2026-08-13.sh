#!/bin/zsh
# Grok 4.6 campaign (2026-08-13) — first frontier-lab platform for the
# Observatory. Cells: bundle (production config) n=10, then reactive
# (headroom ablated) n=10. Mirrors the Kimi continuation protocol with two
# xAI-specific adaptations, both stated here as the run's conditions of
# record:
#   1. MCOS_LLM_TIMEOUT=300 — grok-4.6 reasoning latency exceeded the 120s
#      default (6/10 agents timed out in smoke 1). Timeout events are
#      transport artifacts, not starvation; raising the ceiling removes the
#      instrument's own interference.
#   2. Per-part budget gate on CUMULATIVE LEDGER-COMPUTED SPEND (xAI exposes
#      no balance API). Rates: $2/M in, $6/M out at list; reasoning tokens
#      priced as output pending console reconciliation (upper bound).
set -u
cd /Users/voodoo/Documents/vudu/vuduvations_website/working_backends/mcos-core
set -a; source .env; set +a
PY=.venv312/bin/python
OUT=audits/4_model_accuracy
LEDGERS=$OUT/econ_ledgers
DATE=2026-08-13
BUDGET_CAP=${GROK_BUDGET_CAP:-16.00}   # total ledger-computed $ this campaign may spend
PART_MARGIN=2.50                        # est. upper bound for one part (2 reps)

spent() {
  $PY - <<'EOF'
import json, glob
total = 0.0
for f in glob.glob("audits/4_model_accuracy/econ_ledgers/econ_grok_*_2026-08-13.jsonl"):
    for line in open(f):
        if line.strip():
            r = json.loads(line)
            total += r["input_tokens"]/1e6*2.00 + (r["output_tokens"]+r.get("reasoning_tokens",0))/1e6*6.00
print(f"{total:.2f}")
EOF
}

run_part() {
  local cell=$1; shift
  local part=$1; shift
  local levers=$1; shift
  local s=$(spent)
  if (( $(echo "$s + $PART_MARGIN > $BUDGET_CAP" | bc -l) )); then
    echo "=== GROK BUDGET GATE (spent \$$s + \$$PART_MARGIN margin > cap \$$BUDGET_CAP) — stopping before $cell part $part ==="
    return 1
  fi
  echo "--- grok $cell part $part | ledger spend \$$s / cap \$$BUDGET_CAP ---"
  env -u MCOS_ABLATE_THINKING_HEADROOM -u MCOS_ABLATE_PORTABLE_RETRY -u MCOS_ABLATE_RETRY_HEADROOM \
      -u MCOS_MAD_PROSECUTOR -u MCOS_MAD_DEFENDER -u MCOS_MAD_JUDGE \
      ${=levers} \
      MCOS_LLM_TIMEOUT=300 \
      MCOS_ECON_LEDGER="$LEDGERS/econ_grok_${cell}_${DATE}.jsonl" \
      MCOS_ECON_CELL="grok_$cell:part$part" \
      $PY $OUT/bench_four_protocols.py grok --model grok-4.6 --reps 2 \
      --json "$OUT/results_econ_grok_${cell}_part${part}_${DATE}.json" 2>&1
}

echo "===== GROK CAMPAIGN START $(date) | cap \$$BUDGET_CAP ====="

echo "=== GROK CELL bundle | levers: none ==="
for part in 1 2 3 4 5; do
  run_part bundle $part "" || break
done
echo "=== GROK CELL bundle DONE | ledger spend \$$(spent) ==="

echo "=== GROK CELL reactive | levers: MCOS_ABLATE_THINKING_HEADROOM=1 ==="
for part in 1 2 3 4 5; do
  run_part reactive $part "MCOS_ABLATE_THINKING_HEADROOM=1" || break
done
echo "=== GROK CELL reactive DONE | ledger spend \$$(spent) ==="

echo "===== GROK CAMPAIGN COMPLETE $(date) | ledger spend \$$(spent) ====="
