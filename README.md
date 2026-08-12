# Paper 2 — Economic Integrity in Production LLM Pipelines

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21903218.svg)](https://doi.org/10.5281/zenodo.21903218)

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
  - the ledger analyzer that produced the report is **retained privately** as
    part of the measurement implementation (see `PATENTS.md`). Its SHA-256
    digest remains in `SHA256SUMS` as a commitment. Every value in
    `econ_report_2026-08-10.json` is independently recomputable from
    `econ_ledgers/` + `results/` using the definitions stated in the paper
    (IAF, ECI, used-attempt classification, per-layer separation, dual cost
    bases)
  - `run_econ_ablation.sh` — run-of-record PROVENANCE, not a portable
    reproducer: it hardcodes the original machine's repo path and sources its
    `.env`; it documents exactly what executed
  - `ECONOMIC_INTEGRITY_LEDGER.md` — the engineering ledger write-up
  - `SHA256SUMS` — manifest over the run-of-record package, including the
    digest of the privately retained analyzer

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

Note on the filed artifact bundle: the archive
`mcos_economic_integrity_paper_v0.2.3_2026-08-11.zip`, whose SHA-256 digest is
recorded in U.S. Provisional Application No. 64/131,659, is a byte-frozen
snapshot that is never rebuilt. It is retained privately as evidence of what
existed at filing (it predates `LICENSES/` and `PATENTS.md` and includes the
privately retained analyzer); it is not distributed. The public repository is
the published record: data and manifest under CC BY 4.0, software under MIT,
as described above.
