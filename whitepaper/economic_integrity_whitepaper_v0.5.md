# Economic Integrity in Production LLM Pipelines

## Measuring attempt amplification, discarded reasoning, and retry cost

**Whitepaper draft v0.5**  
**Date:** 2026-08-11  
**Prepared for:** VuduVations / MCOS research program  
**Based on:** `mcos_economic_integrity_paper_v0.2.1_2026-08-11.zip`

*Patent pending. One or more U.S. provisional patent applications have been
filed covering aspects of the systems and methods described herein.*

---

## Executive Summary

Production AI systems are increasingly built with retries, fallback paths,
reasoning models, validator agents, and adversarial review layers. These
mechanisms improve availability and answer quality, but they also break a
simple assumption behind most AI cost dashboards: one user-facing task does
not necessarily equal one paid model attempt.

A pipeline may return one accepted answer while paying for several physical
inference attempts underneath it. Some attempts succeed and contribute to the
final output. Others fail, starve, retry, or get replaced by downstream
recovery machinery. In reasoning-model systems, the discarded work can be
especially expensive because invisible reasoning tokens are billed even when
no visible answer is emitted.

This whitepaper introduces **economic integrity**: the ability to account for
the relationship between a logical unit of work, the physical model attempts
required to complete it, the compute paid for, and the output actually used.

Two metrics make that relationship measurable:

- **Inference Amplification Factor (IAF):** physical model attempts divided by
  logical jobs.
- **Economic Contamination Index (ECI):** total inference spend divided by
  spend on attempts whose output was actually used.

In a four-cell production ablation using a DeepSeek v4-pro direct channel,
all configurations produced broadly comparable scoreboards: answer-key means
ranged from 46.8 to 47.4 out of 48 checks, and each cell produced 9-10 of 10
execution-clean or recovered-clean repetitions. Underneath those similar
scoreboards, the attempt economics diverged sharply.

The proactive-headroom configuration ran at IAF 1.000 in both the primary
agent layer and adversarial validation layer. A pure same-budget retry
configuration reached debate-layer IAF 1.456 and ECI 1.957. In that cell,
48.9% of the validation layer's spend bought discarded attempts.

The lesson is simple:

> A retry can repair the answer. It cannot erase the first invoice.

For leaders building or buying production AI systems, this matters because
benchmark quality, user-facing success, and provider invoices do not tell the
whole story. Teams need attempt-level ledgers that show what the pipeline did,
not only what it answered.

### Market Timing

This is no longer a narrow engineering concern. Enterprise AI cost measurement
is becoming a board-level operating discipline. Accenture has launched an
enterprise "Tokenomics" offering focused on connecting token consumption to
business outcomes, workflows, teams, and decisions. The Linux Foundation
formally launched the Tokenomics Foundation in August 2026, with founding
members including JPMorgan Chase, Accenture, and IBM, as a vendor-neutral
standards body for measuring AI cost and connecting it to business value. Its
working materials frame tokenomics as a supply chain across production,
consumption, and value, and its roadmap includes token-cost telemetry in FOCUS
v1.5 and beyond. J.P. Morgan has also been publishing client-facing analysis
on exploding AI usage and token bills, including the challenge of deciding
whether AI outcomes justify their costs.

Those efforts validate the category. This whitepaper sharpens the unit of
measurement inside that category: enterprises should not only measure tokens
per request or aggregate AI spend. They should measure the attempt path behind
each accepted output. Tokenomics asks whether token-based AI turns energy and
capital into business value. Economic Integrity asks whether the paid
inference inside a workflow actually contributed to the accepted result.

---

## 1. The Hidden Denominator Problem

Most AI cost reporting starts from two familiar objects:

- the model provider's token price
- the application's user-facing request or task

That framing is incomplete for production systems. Between the user request
and the provider invoice sits a third object: the **attempt**.

A logical task may trigger:

- a first model attempt
- an empty-reply retry
- a fallback path
- a validator call
- an adversarial review role
- a re-ask by an orchestrator
- a salvage path that accepts a partial result

The final user-facing result may look clean. The scoreboard may show a pass.
The invoice may show tokens. But without attempt-level accounting, no one can
reconcile which physical model attempts produced the accepted answer and which
attempts were paid for but discarded.

This is the hidden denominator problem. "Cost per request" assumes a stable
relationship between one logical task and one physical model call. Modern LLM
pipelines routinely violate that assumption.

### Why response-level metering fails

Conventional metering often reads the final response object. That can miss
work that occurred earlier in the call path.

If a retry overwrites the failed response with a successful one, downstream
meters see only the survivor. The failed attempt's tokens may still be billed,
but they disappear from application-level cost accounting.

Reasoning models make the gap larger. A model can spend its completion budget
on internal reasoning and emit no visible output. That failed attempt still
has an economic footprint. In the measured study, every discarded output token
was effectively a reasoning token: 228,889 of 228,890 discarded output tokens
were recorded as reasoning tokens.

Layered systems multiply the effect. In the studied pipeline, the primary
client could retry an empty reply, and the adversarial validation layer could
re-ask failed roles as fresh logical jobs. The same user-facing repetition
could therefore pay for multiple recovery rings before the system returned a
usable result.

---

## 2. The Three-Layer Integrity Model

AI evaluation often starts and stops with output quality. Production systems
need deeper accounting.

### Capability Integrity

Capability integrity asks:

> Did the system produce an answer that satisfies the task?

This is what conventional benchmarks measure. In this study, capability was
represented by a 48-check answer key across four analysis protocols.

### Execution Integrity

Execution integrity asks:

> Did the intended model path actually produce the answer?

A system can produce a correct answer through fallback, salvage, or recovery.
That answer may be operationally useful, but the benchmark score alone no
longer proves that the model under test produced the result. This was the
subject of the companion reliability paper on degradation accounting.

### Economic Integrity

Economic integrity asks:

> How many paid physical attempts stood behind the accepted output?

This is the layer introduced here. Even when the answer is correct and the
intended model path ultimately succeeds, the system may have paid for failed
attempts, discarded reasoning, and validator retries along the way.

The three layers can fail independently:

- A correct answer may come from fallback rather than the target model.
- A fallback-free result may still require multiple paid attempts.
- A cheap-looking request may hide expensive discarded reasoning.

Production evaluation should therefore report all three layers: what the
system answered, what path produced it, and what paid inference was required.

### Relationship to Tokenomics

The Tokenomics Foundation's working docs organize AI economics around three
stages: production, consumption, and value. That taxonomy is complementary to
the integrity model here.

Production explains where tokens come from: energy, hardware, capacity,
serving infrastructure, and model access. Consumption explains how AI is used:
routing, prompting, caching, retrieval, orchestration, validation, and
governance. Value asks whether the resulting intelligence was worth more than
it cost.

Economic Integrity sits mainly at the consumption-to-value boundary. Before a
team can claim that an accepted output created value, it needs to know which
physical attempts were consumed to produce that output, which attempts were
discarded, and how much paid reasoning never contributed to the result.

The foundation's first published project, Big-T Notation, is the closest
neighbor to this work. Big-T classifies how token consumption grows as usage
scales, including a multiplicative class T(n*k) for hidden per-request
multipliers such as extended reasoning, and an agent-multiplicative class for
hierarchical agent structures. Big-T reasons about the growth class of a
workload before deployment. IAF and ECI measure the realized multiplier a
running system actually paid, from its own attempt ledger. The two are
complementary: Big-T predicts the shape of the cost curve, and attempt-level
accounting measures where a production system actually sits on that curve,
and why. The study's measured debate-layer IAF of 1.698 is exactly the kind
of hidden multiplier k that Big-T warns about, observed and priced in a live
system.

---

## 3. Metrics: IAF and ECI

Economic integrity becomes measurable once the pipeline records one row per
physical model attempt.

### Inference Amplification Factor

**IAF = physical attempts / logical jobs**

An IAF of 1.000 means the pipeline made one physical model call per logical
job. An IAF of 1.700 means the system made roughly 1.7 model calls for each
logical unit of work.

IAF should be computed per pipeline layer. A primary agent call and an
adversarial validation role do not have the same prompt shape, budget, or
recovery behavior. Pooling layers hides the structure that matters.

### Economic Contamination Index

**ECI = total inference spend / spend on used attempts**

An ECI of 1.000 means all paid inference contributed to accepted output. An
ECI of 2.000 means the system paid roughly twice as much as the used attempts
alone would suggest.

The study defined a **used attempt** conservatively: the final attempt of a
logical job, when that final attempt was non-empty. Empty attempts that were
retried, and final attempts that remained empty, were treated as discarded.

These metrics expose something conventional accuracy and aggregate billing
cannot: the gap between the architecture diagram and the physical execution
record.

---

## 4. Study Design

The economic-integrity study instrumented a production LLM analysis pipeline
at the HTTP client boundary. The ledger wrote one JSONL row per physical model
attempt, including:

- timestamp
- experiment cell and repetition
- logical job identity
- pipeline layer (`agent` or `debate`)
- attempt number
- requested and sent completion budgets
- intervention lever state
- input tokens
- output tokens
- reasoning tokens
- prompt-cache hit and miss token splits
- finish reason
- serving identity, where the channel exposes it
- content-emptiness flag
- outcome
- latency

The study reran a four-cell budget/retry ablation with `n=10` repetitions per
cell on 2026-08-10/11 using DeepSeek v4-pro direct.

The four cells were:

| Cell | Proactive Headroom | Empty-Reply Retry |
|---|---|---|
| reactive | off | on, retry adds headroom |
| proactive | on | off |
| pure retry | off | on, retry at unchanged budget |
| bundle | on | on, retry adds headroom |

The source-of-truth artifact chain is:

```text
raw JSONL ledgers
-> per-launch result JSONs
-> analyzer (retained privately; implements the definitions in this paper)
-> econ_report_2026-08-10.json
-> manuscript tables and figure
```

The whitepaper's reported values are drawn from the compiled report and
cross-checked against the raw ledgers.

---

## 5. Key Findings

### 5.1 Similar scoreboards hid different execution economics

All four cells produced comparable user-facing scoreboards:

| Cell | Answer Key Total | Execution Tier Summary |
|---|---:|---|
| reactive | 470/480 | 9/10 recovered-clean |
| proactive | 474/480 | 9/10 first-attempt-clean |
| pure retry | 472/480 | 9/10 recovered-clean |
| bundle | 468/480 | 10/10 execution-clean or recovered-clean |

These outcomes do not order the cells in a simple quality ranking. The bundle
cell had the cleanest execution tier result, but the lowest answer-key mean.
The important separation appears only when the attempt ledger is examined.

### 5.2 The validation layer was the economic amplifier

The primary agent layer was relatively calm in this run. Its ECI ranged from
1.000 to 1.046 across cells.

The adversarial validation layer behaved very differently:

| Cell | Debate Jobs | Debate Attempts | Debate IAF | Debate ECI | Discarded Debate Spend |
|---|---:|---:|---:|---:|---:|
| reactive | 119 | 202 | 1.698 | 1.576 | $0.1057 |
| proactive | 119 | 119 | 1.000 | 1.003 | $0.0006 |
| pure retry | 193 | 281 | 1.456 | 1.957 | $0.1860 |
| bundle | 110 | 110 | 1.000 | 1.000 | $0.0000 |

The two no-headroom cells discarded 37% and 49% of validation-layer spend.
The proactive and bundle cells effectively eliminated that contamination in
the debate layer.

### 5.3 Recovery is not prevention

Reactive recovery and proactive prevention can produce similar final
scoreboards, but they have different economic signatures.

The reactive cell recovered 82 of 83 starved debate jobs, but it still paid
for the failed attempts. That produced debate-layer IAF 1.698 and ECI 1.576.

The proactive cell had the same baseline debate job count of 119 and the same
attempt count of 119. Its debate-layer IAF was 1.000 and ECI was 1.003.

In other words, successful recovery restored output availability. It did not
restore economic integrity.

### 5.4 Same-budget retry was volatile

The companion reliability paper observed a same-budget retry anomaly: a
same-budget re-ask recovered roughly 19 of 20 starved jobs on 2026-08-09.

In the instrumented run two days later, the same mechanism recovered 5 of 16
agent-layer starvations and 19 of 88 debate-layer starvations.

That movement matters for economic forecasting. A prevention-based design
stabilizes attempt count at a configured budget. A recovery-based design adds
rescue rate as a load-bearing variable. If the rescue rate moves, the bill can
move in ways the architecture diagram does not predict.

### 5.5 Discarded spend was mostly invisible reasoning

Across the study:

- total ledger-computed spend was $3.6944
- discarded spend was $0.3552
- discarded spend was 9.6% of ledger-computed spend
- 82.3% of discarded spend was in the debate layer
- reasoning tokens were 65.1% of billed output tokens
- 228,889 of 228,890 discarded output tokens were reasoning tokens

This is the most concrete version of the problem: the pipeline paid for
thinking that no user or downstream program ever saw.

Existing tokenomics vocabulary recognizes reasoning tokens as a paid
consumption category. Attempt-level accounting makes it possible to
distinguish reasoning that contributed to an accepted result from reasoning
that was paid for and discarded.

---

## 6. Why This Matters Now

The industry is moving toward more controllable and more governable inference.
Open-weight models, portable serving stacks, and inference engines such as
vLLM make it easier for teams to choose where and how intelligence runs.
Enterprise tokenomics programs and emerging standards efforts show that
finance, procurement, technology, and risk leaders are now trying to govern
the cost side of AI at scale. That is an important shift.

But control over inference is not the same as accountability for inference.

An enterprise can own the model weights, operate its own serving stack, and
still fail to account for the economic path from logical job to accepted
output. The missing layer is not only infrastructure. It is the operating
procedure around the model:

- context assembly
- budget policy
- model routing
- retry behavior
- fallback behavior
- validator orchestration
- provenance capture
- cost attribution
- audit record

As model capability commoditizes, value increasingly migrates into these
complementary assets: proprietary procedures, domain-specific harnesses,
verification systems, trust layers, and deployment discipline.

Economic integrity belongs to that layer. It is a measurement system for the
AI operating procedure, not just for the model.

---

## 7. Practical Guidance for Production Teams

### Instrument below retry wrappers

The ledger should sit at the lowest practical model-call boundary, below any
wrapper that can retry, rebind, or replace a response. If instrumentation
starts after the retry layer, discarded attempts will disappear.

### Give every attempt a logical job identity

Each physical attempt should be tied to a logical job. Retries of the same
call should share a job identity and increment attempt number. Higher-level
orchestrator re-asks should be identifiable as new logical jobs.

### Preserve layer identity

Do not pool primary agents, validators, judges, and debate roles into one
cost metric. They often have different budgets and failure modes. In this
study, the debate layer carried the economic contamination that aggregate
metrics would have blurred.

### Track reasoning tokens separately

Reasoning tokens are not visible output, but they can dominate cost. Dashboards
should report reasoning tokens, discarded reasoning tokens, and reasoning share
of output spend.

### Separate pricing bases

This study had two honest cost bases:

- ledger-computed spend: $3.6944 at undiscounted list rates, with cache-hit
  input priced at the full input rate
- account-billed spend: $3.07 from provider balance delta, with prompt-cache
  discounts applied

Both are useful. They should not be mixed. The ledger-computed basis supports
per-attempt attribution. The account-billed basis reflects aggregate cash
movement.

### Report economic integrity beside quality

A useful production row looks like this:

```text
47.0/48 answer-key mean
9/10 execution-clean or recovered-clean
agent IAF 1.087
debate IAF 1.698
debate ECI 1.576
cell discarded spend share 12.9%
```

(Those are the reactive cell's measured values; the study-wide discarded
share across all four cells was 9.6%.)

That is the difference between saying "the system worked" and knowing what it
cost to make it work.

### Map metrics to operating owners

The emerging tokenomics role map also clarifies who should own which parts of
the ledger. The inference and serving engineer owns attempt-level
instrumentation and model-serving identity. The model routing owner owns IAF
by route and the cache effects of routing decisions. The AI cost analyst owns
discarded spend, forecast variance, and account-billed versus ledger-computed
reconciliation. The governance owner owns thresholds for retries, fallbacks,
reasoning budgets, and escalation. The value, monetization, and pricing owner
owns the link from ECI to margin, pricing, and business outcome.

---

## 8. Recommended Dashboard Metrics

The Tokenomics Foundation cautions that many metrics on today's AI dashboards
may be measuring the wrong things because the field has not yet converged on
the right units. The measurements proposed here are one attempt to make that
unit explicit: begin with the logical job, record every physical attempt
beneath it, and reconcile the resulting execution path to spend.

At minimum, production LLM dashboards should report:

- logical jobs
- physical attempts
- IAF by layer
- ECI by layer
- first-attempt empty rate
- recovered versus unrecovered empties
- discarded spend
- discarded spend share
- reasoning tokens
- discarded reasoning tokens
- cache-hit and cache-miss token splits
- latency by attempt number
- account-billed versus ledger-computed spend

For governance and audit workflows, each accepted output should be traceable
to:

- the final used attempt
- any discarded attempts before it
- retry or fallback policy engaged
- model and serving identity
- token usage and spend
- provenance of validators or judges

---

## 9. Limitations

This whitepaper summarizes one production measurement case study:

- one pipeline
- one provider and model channel
- one run night per cell
- `n=10` repetitions per cell
- a fixed developer-written benchmark corpus
- list-rate ledger dollars treated as upper bounds
- account-billed dollars inferred from balance deltas

The numerical results should not be read as universal model behavior. The
generalizable contribution is the measurement frame: attempt-level economic
accounting, IAF, ECI, and layer-specific attribution.

The study also leaves open the provider-side cause of cross-night retry
variance. Cache-state or serving-path effects remain plausible, and the raw
ledger captures cache hit/miss splits for future analysis.

---

## 10. Conclusion

Production LLM systems are no longer single-call demos. They are layered
software systems with retries, validators, fallbacks, reasoning budgets, and
orchestrators. Those systems need accounting that matches their execution
structure.

Capability metrics show what the system answered. Execution-integrity metrics
show whether the intended path produced the answer. Economic-integrity metrics
show how many paid attempts stood behind it.

The attempt ledger is the bridge between the scoreboard and the invoice.

A retry repairs the answer. It does not erase the first invoice.

---

## Artifact Note

The research package reviewed for this draft is:

`mcos_economic_integrity_paper_v0.2.1_2026-08-11.zip`

Its core source-of-truth files are:

- `artifacts/econ_report_2026-08-10.json`
- `artifacts/econ_ledgers/*.jsonl`
- `artifacts/results/*.json`
- the ledger analyzer (retained privately; its SHA-256 digest is committed in `artifacts/SHA256SUMS`)
- `artifacts/SHA256SUMS`
- `main.tex`

## References

- Sean Halverson, *Economic Integrity in Production LLM Pipelines: Measuring
  Attempt Amplification, Discarded Reasoning, and Retry Cost*, preprint v0.2.1,
  VuduVations, August 2026.
- Sean Halverson, *When the Model Isn't the Problem: Degradation Accounting in
  Fallback-Enabled Production LLM Pipelines*, preprint v0.13.1, VuduVations,
  August 2026.
- DeepSeek API documentation, Models and Pricing / Thinking Mode, accessed
  2026-08. https://api-docs.deepseek.com
- OpenAI API documentation, Reasoning Models, accessed 2026-08.
  https://platform.openai.com/docs/guides/reasoning
- Accenture, "Accenture Tokenomics Launched to Help Enterprises Manage AI
  Token Spend," 2026-07-29.
  https://newsroom.accenture.com/blogs/2026/accenture-tokenomics-launched-to-help-enterprises-manage-ai-token-spend
- Tokenomics Foundation / Linux Foundation Projects, "Linux Foundation
  Launches the Tokenomics Foundation to Define the Economics and ROI of AI
  Value," published 2026-08-03 and updated 2026-08-04.
  https://www.tokeneconomics.com/insights/linux-foundation-launches-tokenomics-foundation/
- Tokenomics Foundation, "Tokenomics overview," working draft, accessed
  2026-08-11.
  https://www.tokeneconomics.com/docs/overview/
- Tokenomics Foundation, "Production, Consumption, Value," working draft,
  accessed 2026-08-11.
  https://www.tokeneconomics.com/docs/overview/production-consumption-value/
- Tokenomics Foundation, "Key Players and Roles," working draft, accessed
  2026-08-11.
  https://www.tokeneconomics.com/docs/overview/key-players/
- Tokenomics Foundation, "Big-T Notation Paper," working draft, June 2026,
  accessed 2026-08-11.
  https://www.tokeneconomics.com/docs/projects/big-t-notation/
- Fortune, "JPMorgan Chase, Accenture and others are teaming up on a new
  venture to standardize how AI token use is measured," 2026-08-04.
  https://fortune.com/2026/08/04/jpmorgan-chase-accenture-others-are-teaming-up-venture-standardize-ai-token-use-measured-cfo/
- J.P. Morgan Private Bank, Justin Biemann, "AI use is exploding. So are the
  bills," 2026-07-17.
  https://privatebank.jpmorgan.com/nam/en/insights/markets-and-investing/tmt/ai-use-is-exploding-so-are-the-bills
