#!/bin/zsh
# Kimi leg continuation (2026-08-13) — after $20 Moonshot top-up.
# Lesson from the overnight run: the $2 floor only checked at CELL start, so
# reactive's part 5 ran into account suspension mid-part (quarantined).
# This script checks the floor before EVERY PART so runs stop at clean
# part boundaries. Priority: bundle (production config) n=10 first, then
# re-run reactive part 5 (its overnight attempt was balance-starved) if
# funds remain.
set -u
cd /Users/voodoo/Documents/vudu/vuduvations_website/working_backends/mcos-core
set -a; source .env; set +a
PY=.venv312/bin/python
OUT=audits/4_model_accuracy
LEDGERS=$OUT/econ_ledgers
DATE=2026-08-13   # pinned: must match the overnight kimi ledger date
PART_FLOOR=4.00   # ~2 reps at ~$1.80/rep + margin

kimi_balance() {
  curl -s --max-time 20 https://api.moonshot.ai/v1/users/me/balance \
    -H "Authorization: Bearer $MOONSHOT_API_KEY" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['available_balance'])" 2>/dev/null || echo "?"
}

run_part() {
  local cell=$1; shift
  local part=$1; shift
  local levers=$1; shift
  local bal=$(kimi_balance)
  if [[ "$bal" == "?" ]] || (( $(echo "$bal < $PART_FLOOR" | bc -l) )); then
    echo "=== KIMI PART FLOOR HIT (\$$bal < \$$PART_FLOOR) — stopping before $cell part $part ==="
    return 1
  fi
  echo "--- kimi $cell part $part | balance \$$bal ---"
  env -u MCOS_ABLATE_THINKING_HEADROOM -u MCOS_ABLATE_PORTABLE_RETRY -u MCOS_ABLATE_RETRY_HEADROOM \
      -u MCOS_MAD_PROSECUTOR -u MCOS_MAD_DEFENDER -u MCOS_MAD_JUDGE \
      ${=levers} \
      MCOS_ECON_LEDGER="$LEDGERS/econ_kimi_${cell}_${DATE}.jsonl" \
      MCOS_ECON_CELL="kimi_$cell:part$part" \
      $PY $OUT/bench_four_protocols.py kimi --reps 2 \
      --json "$OUT/results_econ_kimi_${cell}_part${part}_${DATE}.json" 2>&1
}

echo "===== KIMI CONTINUATION START $(date) | balance \$$(kimi_balance) ====="

echo "=== KIMI CELL bundle (continuation) | levers: none ==="
for part in 1 2 3 4 5; do
  run_part bundle $part "" || break
done
echo "=== KIMI CELL bundle DONE | balance \$$(kimi_balance) ==="

echo "=== KIMI reactive part 5 re-run (overnight attempt was balance-starved) ==="
run_part reactive 5 "MCOS_ABLATE_THINKING_HEADROOM=1" || true

echo "===== KIMI CONTINUATION COMPLETE $(date) | balance \$$(kimi_balance) ====="
