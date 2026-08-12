# Paper 2 — Economic Integrity in Production LLM Pipelines

Measuring Attempt Amplification, Discarded Reasoning, and Retry Cost.
Preprint v0.2.1 (revised 2026-08-11). Companion to Paper 1
(`../mcos-reliability-paper/`).

## Layout

- `main.tex` — manuscript source; build with `tectonic main.tex`
- `make_figures.py` — regenerates `fig_econ.pdf`; reads every value from
  `artifacts/econ_report_2026-08-10.json` (falls back to the mcos-core copy),
  nothing transcribed. Needs `matplotlib` (see `requirements.txt`)
- `main.pdf`, `fig_econ.pdf` — current build
- `artifacts/` — the run-of-record data package (copied from mcos-core
  `audits/4_model_accuracy/`, which remains the source of truth):
  - `econ_report_2026-08-10.json` — compiled per-cell/per-layer metrics; the
    manuscript's numerical source of truth
  - `econ_ledgers/` — 4 raw per-attempt JSONL ledgers (one per ablation cell)
  - `results/` — 20 per-launch bench result JSONs (boards + agent_modes)
  - `econ_analyze.py` — ledger analyzer that produced the report; running it
    inside `artifacts/` regenerates the report from the ledgers and
    `results/` (stdlib only)
  - `run_econ_ablation.sh` — run-of-record PROVENANCE, not a portable
    reproducer: it hardcodes the original machine's repo path and sources its
    `.env`; it documents exactly what executed
  - `ECONOMIC_INTEGRITY_LEDGER.md` — the engineering ledger write-up
  - `SHA256SUMS` — manifest over all of the above

## Numbers discipline

Every figure in the manuscript traces to the report JSON. Layers (agent vs
debate) are never pooled. Counts carry denominators and dates; single-night
rescue rates are never generalized. Ledger-computed dollars (undiscounted
list, cache-hit input at full rate; upper bound) and account-billed dollars
(balance delta, provider cache discount applied) are two bases that are
never mixed in one figure.

## Licensing

Software source files in this repository are licensed under the MIT License
unless otherwise noted.

The research manuscript, whitepaper, documentation, and published research
data are licensed under CC BY 4.0 unless otherwise noted.

See LICENSES/ and PATENTS.md for additional information.

Note on the release artifact: `mcos_economic_integrity_paper_v0.2.3_2026-08-11.zip`
(the release asset whose SHA-256 is recorded in U.S. Provisional Application
No. 64/131,659) is a byte-frozen snapshot taken before `LICENSES/` and
`PATENTS.md` were added, and is never rebuilt. The licensing above applies to
the repository contents, including the corresponding files inside that
snapshot.
