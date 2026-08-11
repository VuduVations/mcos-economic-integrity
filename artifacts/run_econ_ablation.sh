#!/bin/zsh
# #390 — Economic Integrity re-run of the four DeepSeek ablation cells with the
# per-attempt ledger armed. Cells in article-priority order; a DeepSeek balance
# floor guards each launch so the account is never drained mid-cell.
set -u
cd /Users/voodoo/Documents/vudu/vuduvations_website/working_backends/mcos-core
set -a; source .env; set +a
PY=.venv312/bin/python
OUT=audits/4_model_accuracy
LEDGERS=$OUT/econ_ledgers
mkdir -p "$LEDGERS"
DATE=$(date +%F)
FLOOR=0.80

balance() {
  curl -s --max-time 20 https://api.deepseek.com/user/balance \
    -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['balance_infos'][0]['total_balance'])" 2>/dev/null || echo "?"
}

run_cell() {
  local cell=$1; shift
  local levers=$1; shift
  local bal=$(balance)
  echo "=== CELL $cell | balance \$$bal | levers: ${levers:-none} ==="
  if [[ "$bal" != "?" ]] && (( $(echo "$bal < $FLOOR" | bc -l) )); then
    echo "BUDGET FLOOR HIT (\$$bal < \$$FLOOR) — skipping cell $cell"
    return 1
  fi
  # 5 invocations x --reps 2 = n=10, matching the 2026-08-09 run-of-record shape.
  for part in 1 2 3 4 5; do
    echo "--- $cell part $part ---"
    env -u MCOS_ABLATE_THINKING_HEADROOM -u MCOS_ABLATE_PORTABLE_RETRY -u MCOS_ABLATE_RETRY_HEADROOM \
        -u MCOS_MAD_PROSECUTOR -u MCOS_MAD_DEFENDER -u MCOS_MAD_JUDGE \
        ${=levers} \
        MCOS_ECON_LEDGER="$LEDGERS/econ_${cell}_${DATE}.jsonl" \
        MCOS_ECON_CELL="$cell:part$part" \
        $PY $OUT/bench_four_protocols.py deepseek --reps 2 \
        --json "$OUT/results_econ_${cell}_part${part}_${DATE}.json" 2>&1
  done
  echo "=== CELL $cell DONE | balance \$$(balance) ==="
}

run_cell reactive   "MCOS_ABLATE_THINKING_HEADROOM=1"
run_cell proactive  "MCOS_ABLATE_PORTABLE_RETRY=1"
run_cell pure_retry "MCOS_ABLATE_THINKING_HEADROOM=1 MCOS_ABLATE_RETRY_HEADROOM=1"
run_cell bundle     ""
echo "===== ECON ABLATION COMPLETE | final balance \$$(balance) ====="
