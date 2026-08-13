#!/bin/zsh
# Reactive part 5 re-run (2026-08-13, after second top-up) — completes kimi
# reactive to n=10. Same invocation as kimi_continuation's run_part.
set -u
cd /Users/voodoo/Documents/vudu/vuduvations_website/working_backends/mcos-core
set -a; source .env; set +a
PY=.venv312/bin/python
OUT=audits/4_model_accuracy
echo "=== KIMI reactive part 5 RERUN start $(date) ==="
env -u MCOS_ABLATE_PORTABLE_RETRY -u MCOS_ABLATE_RETRY_HEADROOM \
    -u MCOS_MAD_PROSECUTOR -u MCOS_MAD_DEFENDER -u MCOS_MAD_JUDGE \
    MCOS_ABLATE_THINKING_HEADROOM=1 \
    MCOS_ECON_LEDGER="$OUT/econ_ledgers/econ_kimi_reactive_2026-08-13.jsonl" \
    MCOS_ECON_CELL="kimi_reactive:part5" \
    $PY $OUT/bench_four_protocols.py kimi --reps 2 \
    --json "$OUT/results_econ_kimi_reactive_part5_2026-08-13.json" 2>&1
echo "=== KIMI reactive part 5 RERUN DONE $(date) ==="
