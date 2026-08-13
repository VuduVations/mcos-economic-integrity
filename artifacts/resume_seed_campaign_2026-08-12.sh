#!/bin/zsh
set -u
cd /Users/voodoo/Documents/vudu/vuduvations_website/working_backends/mcos-core
set -a; source .env; set +a
OUT=audits/4_model_accuracy
echo "===== SEED CAMPAIGN RESUME $(date) ====="
zsh $OUT/run_econ_ablation.sh 2>&1
# Kimi leg: reuse the kimi_cell logic from the original script by sourcing its tail
PY=.venv312/bin/python
LEDGERS=$OUT/econ_ledgers
DATE=$(date +%F)
KIMI_FLOOR=2.00
kimi_balance() {
  curl -s --max-time 20 https://api.moonshot.ai/v1/users/me/balance \
    -H "Authorization: Bearer $MOONSHOT_API_KEY" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['available_balance'])" 2>/dev/null || echo "?"
}
kimi_cell() {
  local cell=$1; shift
  local levers=$1; shift
  local bal=$(kimi_balance)
  echo "=== KIMI CELL $cell | balance \$$bal | levers: ${levers:-none} ==="
  if [[ "$bal" != "?" ]] && (( $(echo "$bal < $KIMI_FLOOR" | bc -l) )); then
    echo "KIMI BUDGET FLOOR HIT (\$$bal < \$$KIMI_FLOOR) — skipping cell $cell"
    return 1
  fi
  for part in 1 2 3 4 5; do
    echo "--- kimi $cell part $part ---"
    env -u MCOS_ABLATE_THINKING_HEADROOM -u MCOS_ABLATE_PORTABLE_RETRY -u MCOS_ABLATE_RETRY_HEADROOM \
        -u MCOS_MAD_PROSECUTOR -u MCOS_MAD_DEFENDER -u MCOS_MAD_JUDGE \
        ${=levers} \
        MCOS_ECON_LEDGER="$LEDGERS/econ_kimi_${cell}_${DATE}.jsonl" \
        MCOS_ECON_CELL="kimi_$cell:part$part" \
        $PY $OUT/bench_four_protocols.py kimi --reps 2 \
        --json "$OUT/results_econ_kimi_${cell}_part${part}_${DATE}.json" 2>&1
  done
  echo "=== KIMI CELL $cell DONE | balance \$$(kimi_balance) ==="
}
kimi_cell reactive   "MCOS_ABLATE_THINKING_HEADROOM=1"
kimi_cell proactive  "MCOS_ABLATE_PORTABLE_RETRY=1"
kimi_cell pure_retry "MCOS_ABLATE_THINKING_HEADROOM=1 MCOS_ABLATE_RETRY_HEADROOM=1"
kimi_cell bundle     ""
echo "===== SEED CAMPAIGN COMPLETE $(date) ====="
