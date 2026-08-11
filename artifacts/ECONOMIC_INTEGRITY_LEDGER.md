---
title: Economic Integrity Ledger — first measured IAF/ECI (#390)
description: Per-attempt economic instrumentation of the four-cell DeepSeek ablation, making the reliability paper's un-instrumented attempt denominators measurable.
version: 1.1.1
status: Published
created: 2026-08-11
updated: 2026-08-11
author: VuduVations Engineering
tags: [audits, economic-integrity, ablation, layer3]
---

# Economic Integrity Ledger

**What this is.** The reliability paper counted starvation EVENTS from run
logs and explicitly declined attempt denominators ("attempts were not
instrumented"). This run instruments the attempt itself:
`layer3/portable_client._econ_log` writes one JSONL row per HTTP attempt
(tokens incl. reasoning and prompt-cache splits, budget, lever state, layer
tag, outcome, latency), gated on `MCOS_ECON_LEDGER` — zero behavior change
when unset. The four ablation cells were re-run with the ledger armed
(`run_econ_ablation.sh`, n=10 per cell, DeepSeek direct, MAD_* unset,
2026-08-10/11). Analyzer: `econ_analyze.py` → `econ_report_2026-08-10.json`;
raw ledgers in `econ_ledgers/`; result JSONs `results_econ_*`.

**Definitions.** IAF = physical attempts / logical jobs (per layer, never
pooled). ECI = total spend / spend on attempts whose output was used.
Logical jobs include the summarizer/validator calls beyond the ten graded
agents (~12.7 agent-layer jobs per rep), so job counts exceed 10×reps; the
outcome tiers still grade on the paper's ten-agent `agent_modes`. Dollars use
the DeepSeek direct list (0.435/0.87 per M); cache-hit input is priced at the
full input rate, so costs are upper bounds (hit/miss splits are in the rows).

## 1. Measured results (n=10 per cell)

| cell | agent IAF | agent starved / recovered / unrecovered | debate IAF | debate ECI | debate starved | cell cost | execution tiers (n=10) | answer key (/480) |
|---|---|---|---|---|---|---|---|---|
| reactive (+2000 retry) | 1.087 | 12 / 11 / 1 | 1.698 | 1.576 | 83 (82 rec / 1 unrec) | $0.93 | 9/10 recovered-clean | 470 (47.0) |
| proactive (headroom) | **1.000** | 1 / 0 / 1 | **1.000** | 1.003 | 1 | $0.87 | 9/10 first-attempt-clean | 474 (47.4) |
| pure retry (same budget) | 1.109 | 16 / **5** / **11** | 1.456 | **1.957** | 88 (19 rec / 69 unrec) | $1.03 | 9/10 recovered-clean | 472 (47.2) |
| bundle (headroom+retry) | 1.016 | 2 / 2 / 0 | 1.000 | 1.000 | 0 | $0.86 | **10/10 exec-clean** (8 first-attempt) | 468 (46.8) |

Execution tiers and answer-key scores are DISTINCT measurements and neither
orders the cells (the only zero-degraded cell, bundle, has the lowest
answer-key mean). "9–10/10" always means execution-clean or recovered-clean
repetitions, never 48/48 board perfection — per cell only 2–5 of 10 boards
were exact 48s.

Cell costs above are LEDGER-COMPUTED (sum of both layers at undiscounted
list rates; cache-hit input priced at the full input rate) and sum to $3.69.
The ACCOUNT-BILLED total was $3.07 (balance $4.74 → $1.67); the $0.62 gap is
the provider's prompt-cache discount, which the ledger does not apply — the
gap is itself a measured artifact of cache participation. The two aggregates
have different bases and must never be mixed in one figure. Every cell
produced 9–10/10 execution-clean-or-recovered repetitions and answer-key
means within 0.6 checks of one another; the attempt machinery underneath
differed by up to a factor of two in the debate layer.

## 2. What the measurements say

1. **Prevention measures as a counted residual with no hidden
   amplification.** Caveat first: with the retry ablated, inner-ring
   IAF = 1.000 is structural, not evidence by itself. The evidence: the
   proactive cell — where the paper's "0 events" claim previously rested
   on a retry log line that cannot fire with the retry ablated — now
   shows 127 agent jobs, 127 attempts, one empty first reply, directly
   observed, AND no outer-ring re-asks (debate jobs at the baseline 119,
   not pure_retry's 193). The blind spot is closed and the claim
   survives (as 1-in-127, not 0).
2. **The retry mechanism ranking is measured, and it reverses the 08-09
   anomaly.** Same-budget re-asks rescued 5 of 16 starved jobs tonight;
   +2000-headroom retries rescued 11 of 12; the bundle rescued 2 of 2. On
   2026-08-09 the same-budget re-ask rescued ~19/20 — the rescue rate of an
   identical configuration moved this much in two days. Attempt outcomes are
   non-exchangeable AND non-stationary; single-night rescue rates must not
   be generalized (either direction).
3. **Tonight the debate layer was the amplification story.** Agent-layer
   starvation was calm (12–16 events vs the paper's 96–102 for the same
   levers — temporal variance, now priced), but the adversarial validation
   layer's 400-token role budgets starved 83–88 times in the no-headroom
   cells: ECI 1.58–1.96, i.e. up to HALF of the debate spend bought
   discarded attempts. With headroom on: zero to one events, ECI ≈ 1.0.
4. **Cost-per-outcome was nearly flat across cells (~$0.065–0.078/rep)** at
   tonight's event rates. The measured economic difference between recovery
   and prevention tonight lives in the debate layer and in latency/variance,
   not in the agent-layer bill. The article should present the reactive
   ($0.0146 agent-discarded) and pure-retry ($0.0288 + $0.19 debate-discarded)
   dollars as measured, and the paper's 96-event night as the count-only
   upper contrast — never a rate.
5. **Paid-but-discarded is now a first-class number:** the pure_retry cell
   discarded $0.0288 agent-layer + $0.1860 debate-layer of a $1.03
   ledger-computed cell — 48.9% of the debate bill ($0.3804 total, $0.1944
   used). In that cell only 19 of 88 starved debate jobs were rescued by the
   same-budget re-ask (69 ended empty), versus 82 of 83 rescued by the
   reactive cell's +2000 retry. Starved attempts bill mostly reasoning
   tokens (invisible output), which is exactly the spend category no
   scoreboard sees.

## 3. Instrumentation notes

- The hook lives INSIDE `PortableLLMClient.complete` around each
  `_compat.complete` call, below the bench's MeteredClient rebinding — it
  cannot be shadowed and it also captures chamber traffic (roles route
  through the injected client when MAD_* are unset, as here).
- Legacy counters (`input_tokens`/`output_tokens` on the client, and
  MeteredClient) still meter only the RETURNED attempt — unchanged for
  comparability with published figures. The ledger-vs-legacy delta is the
  paid-but-discarded metric.
- `agent_modes` records the ATTEMPT ("llm") even when an agent later
  crashes into fallback; the ledger's final-attempt outcome is the
  authoritative per-job record.
- Cache splits are recorded per attempt (prompt_cache_hit/miss); retry
  attempts show high hit ratios, bearing on the paper's unresolved cache
  hypothesis for why re-asks sometimes succeed. Analysis deferred — the
  rows exist.
