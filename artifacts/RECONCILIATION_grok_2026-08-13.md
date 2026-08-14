# Grok 4.6 ledger vs xAI console reconciliation (2026-08-14)

Source of truth for the provider side: xAI console usage breakdown,
"Text" tab, read 2026-08-14 06:23 PT (owner screenshot). Aug 13, 2026
day bar tooltip:

| Console line item          | Console tokens | Console spend |
|---------------------------|---------------:|--------------:|
| Reasoning text tokens     | 1.2M (7d)      | $7.01 (Aug 13)|
| Completion text tokens    | 1.1M (7d)      | $6.40 (Aug 13)|
| Prompt text tokens        | 546.5K (7d)    | $1.05 (Aug 13)|
| Cached prompt text tokens | 392.7K (7d)    | $0.19 (Aug 13)|
| Total (Aug 13)            |                | $14.65        |

Ledger side (all four econ_*grok*2026-08-13 ledgers in this bundle:
bundle, reactive, smoke, smoke.timeout120):

- reasoning 1,168,846 tokens x $6/M = **$7.013** — matches the console's
  $7.01 exactly. Reasoning bills at the output list rate; the "upper
  bound pending reconciliation" caveat on the campaign's pricing basis
  is resolved: it was the exact basis.
- completion 1,067,247 tokens x $6/M = **$6.403** — matches $6.40 exactly.
- prompt 907,223 tokens x $2/M = $1.81 vs console $1.05 + $0.19 = $1.24.
  The console shows 392.7K of the prompt tokens were cache hits billed
  at roughly $0.48/M. The ledger recorded cache_hit_tokens = 0 for every
  Grok row because xAI reports prompt caching in a different usage field
  than the DeepSeek-style `prompt_cache_hit_tokens` the ledger captures.
  All prompt tokens were therefore booked at the full input rate.

Net: ledger-computed total $15.23 vs console-billed $14.65 — the ledger
overstates by ~4%, entirely on the input side, in the conservative
direction (the instrument never understates spend). IAF and ECI are
unaffected (attempt counts and per-attempt ratios do not depend on the
price basis).

Known instrument limitation recorded: capture xAI's cached-token usage
field (`prompt_tokens_details.cached_tokens`-style) in a future
portable_client revision so cached input can be priced at the provider's
discount instead of the full-rate upper bound.
