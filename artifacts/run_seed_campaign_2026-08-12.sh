#!/bin/zsh
# Observatory seed campaign — overnight run (2026-08-12).
# Sequence: n=1 smokes on both models (gate) → DeepSeek full 4-cell n=10
# (third volatility date) → Kimi full 4-cell n=10 (first cross-model row).
# Balance floors guard every cell so neither account is drained mid-run.
set -u
cd /Users/voodoo/Documents/vudu/vuduvations_website/working_backends/mcos-core
set -a; source .env; set +a
PY=.venv312/bin/python
OUT=audits/4_model_accuracy
LEDGERS=$OUT/econ_ledgers
mkdir -p "$LEDGERS" "$OUT/run_logs"
DATE=$(date +%F)
DS_FLOOR=0.80
KIMI_FLOOR=2.00

ds_balance() {
  curl -s --max-time 20 https://api.deepseek.com/user/balance \
    -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['balance_infos'][0]['total_balance'])" 2>/dev/null || echo "?"
}
kimi_balance() {
  curl -s --max-time 20 https://api.moonshot.ai/v1/users/me/balance \
    -H "Authorization: Bearer $MOONSHOT_API_KEY" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['available_balance'])" 2>/dev/null || echo "?"
}

echo "===== SEED CAMPAIGN START $(date) | DeepSeek \$$(ds_balance) | Kimi \$$(kimi_balance) ====="

# ---- Phase 1: n=1 smokes (production config, ledger armed) ----
echo "=== SMOKE deepseek n=1 ==="
MCOS_ECON_LEDGER="$LEDGERS/econ_smoke_deepseek_${DATE}.jsonl" \
MCOS_ECON_CELL="smoke:deepseek" \
$PY $OUT/bench_four_protocols.py deepseek --reps 1 \
  --json "$OUT/results_smoke_deepseek_${DATE}.json" 2>&1
DS_SMOKE=$?
echo "=== SMOKE kimi n=1 ==="
MCOS_ECON_LEDGER="$LEDGERS/econ_smoke_kimi_${DATE}.jsonl" \
MCOS_ECON_CELL="smoke:kimi" \
$PY $OUT/bench_four_protocols.py kimi --reps 1 \
  --json "$OUT/results_smoke_kimi_${DATE}.json" 2>&1
KIMI_SMOKE=$?
echo "=== SMOKES: deepseek=$DS_SMOKE kimi=$KIMI_SMOKE (0=pass) ==="

# ---- Phase 2: DeepSeek full 4-cell n=10 (gated on its smoke) ----
if [[ $DS_SMOKE -eq 0 ]]; then
  echo "=== DEEPSEEK FULL RUN (run_econ_ablation.sh) ==="
  zsh $OUT/run_econ_ablation.sh 2>&1
else
  echo "DEEPSEEK SMOKE FAILED — skipping full run"
fi

# ---- Phase 3: Kimi full 4-cell n=10 (gated on its smoke + balance floor) ----
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

if [[ $KIMI_SMOKE -eq 0 ]]; then
  kimi_cell reactive   "MCOS_ABLATE_THINKING_HEADROOM=1"
  kimi_cell proactive  "MCOS_ABLATE_PORTABLE_RETRY=1"
  kimi_cell pure_retry "MCOS_ABLATE_THINKING_HEADROOM=1 MCOS_ABLATE_RETRY_HEADROOM=1"
  kimi_cell bundle     ""
else
  echo "KIMI SMOKE FAILED — skipping full run"
fi

echo "===== SEED CAMPAIGN COMPLETE $(date) | DeepSeek \$$(ds_balance) | Kimi \$$(kimi_balance) ====="
