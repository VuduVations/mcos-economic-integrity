#!/usr/bin/env python3
"""Generate fig_econ.pdf for the economic integrity paper (v0.1).

Three panels over the four ablation cells, per layer (agent vs debate,
never pooled):
  (1) IAF: physical attempts per logical job,
  (2) ECI: total spend over spend on used attempts,
  (3) debate-layer spend split, used vs discarded, ledger-computed dollars.

Unlike the reliability paper's figure script, nothing is transcribed:
every number is read from the compiled report (the manuscript's source
of truth).

  python3 make_figures.py [path/to/econ_report_2026-08-10.json]
"""
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

_LOCAL = Path(__file__).parent / "artifacts/econ_report_2026-08-10.json"
_CORE = (Path(__file__).resolve().parents[2]
         / "vuduvations_website/working_backends/mcos-core/audits/4_model_accuracy"
         / "econ_report_2026-08-10.json")
REPORT = Path(sys.argv[1]) if len(sys.argv) > 1 else (
    _LOCAL if _LOCAL.exists() else _CORE)

EMERALD, BLUE, YELLOW, RED, INK = "#0D6B4E", "#1d4ed8", "#EAB308", "#b91c1c", "#1a1a1a"

ORDER = ["reactive", "proactive", "pure_retry", "bundle"]
LABELS = ["Reactive", "Proactive", "Pure retry", "Bundle"]

r = json.load(open(REPORT))
agent = [r[c]["agent"] for c in ORDER]
debate = [r[c]["debate"] for c in ORDER]

fig, axes = plt.subplots(1, 3, figsize=(12, 3.4))
plt.rcParams.update({"font.size": 9})
xs = range(len(ORDER))
w = 0.38

# ── Panel 1: IAF per layer ──
ax = axes[0]
ax.bar([x - w / 2 for x in xs], [a["IAF"] for a in agent], w,
       color=BLUE, label="agent layer")
ax.bar([x + w / 2 for x in xs], [d["IAF"] for d in debate], w,
       color=RED, label="debate layer")
ax.axhline(1.0, color=INK, lw=0.8, ls=":")
for x, a, d in zip(xs, agent, debate):
    ax.text(x - w / 2, a["IAF"] + 0.02, f"{a['IAF']:.2f}",
            ha="center", fontsize=7.5)
    ax.text(x + w / 2, d["IAF"] + 0.02, f"{d['IAF']:.2f}",
            ha="center", fontsize=7.5)
ax.set_xticks(list(xs)), ax.set_xticklabels(LABELS)
ax.set_ylim(0.9, 1.85)
ax.set_ylabel("IAF (attempts / logical jobs)")
ax.set_title("(1) Invisible Attempt Factor", fontsize=9.5)
ax.legend(frameon=False, fontsize=8)

# ── Panel 2: ECI per layer ──
ax = axes[1]
ax.bar([x - w / 2 for x in xs], [a["ECI"] for a in agent], w, color=BLUE)
ax.bar([x + w / 2 for x in xs], [d["ECI"] for d in debate], w, color=RED)
ax.axhline(1.0, color=INK, lw=0.8, ls=":")
for x, a, d in zip(xs, agent, debate):
    ax.text(x - w / 2, a["ECI"] + 0.02, f"{a['ECI']:.2f}",
            ha="center", fontsize=7.5)
    ax.text(x + w / 2, d["ECI"] + 0.02, f"{d['ECI']:.2f}",
            ha="center", fontsize=7.5)
ax.set_xticks(list(xs)), ax.set_xticklabels(LABELS)
ax.set_ylim(0.9, 2.15)
ax.set_ylabel("ECI (total spend / used spend)")
ax.set_title("(2) Economic Contamination Index", fontsize=9.5)

# ── Panel 3: debate-layer spend split ──
ax = axes[2]
used = [d["cost_used_usd"] for d in debate]
disc = [d["cost_discarded_usd"] for d in debate]
ax.bar(xs, used, 0.55, color=EMERALD, label="used")
ax.bar(xs, disc, 0.55, bottom=used, color=YELLOW,
       edgecolor=INK, lw=0.4, label="discarded")
for x, u, dd in zip(xs, used, disc):
    if dd > 0.002:
        ax.text(x, u + dd + 0.008, f"{dd / (u + dd) * 100:.0f}%\ndiscarded",
                ha="center", va="bottom", fontsize=7.5)
ax.set_ylim(0, max(u + dd for u, dd in zip(used, disc)) * 1.35)
ax.set_xticks(list(xs)), ax.set_xticklabels(LABELS)
ax.set_ylabel("debate-layer spend (USD, ledger basis)")
ax.set_title("(3) Debate-layer spend, used vs discarded", fontsize=9.5)
ax.legend(frameon=False, fontsize=8, loc="upper left")

for ax in axes:
    ax.spines[["top", "right"]].set_visible(False)

fig.tight_layout()
out = Path(__file__).parent / "fig_econ.pdf"
fig.savefig(out, bbox_inches="tight")
print(f"wrote {out}")
