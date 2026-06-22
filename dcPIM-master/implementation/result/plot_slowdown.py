#!/usr/bin/env python3
"""
Plot dcPIM FCT-slowdown summary from a *_slowdown_size.dat file produced by
parse_result.py.

The .dat format (whitespace-separated, one header line then 6 buckets):
    <FLOW_SIZE> <MEAN_SLOWDOWN> <DIFF_BETWEEN_TAIL_AND_MEAN>
    <1BDP   <mean>   <p99 - mean>
    ...
    infi    <mean>   <p99 - mean>

Column 2 is the mean FCT slowdown (actual FCT / ideal FCT; 1.0 = ideal).
Column 3 is (p99 - mean), i.e. an UPPER-tail spread, so it's drawn as an
upper-only error bar.

Usage:
    python plot_slowdown.py [path/to/file_slowdown_size.dat]

If no path is given, it plots every *_slowdown_size.dat next to this script.
Each input produces a PNG with the same basename.
"""
import os
import sys
import glob
import math
import matplotlib
matplotlib.use("Agg")            # no GUI / headless safe
import matplotlib.pyplot as plt


def read_dat(path):
    labels, means, upper_err = [], [], []
    with open(path) as f:
        lines = f.read().splitlines()      # handles CRLF and LF
    for line in lines:
        parts = line.split()
        if len(parts) < 3:
            continue
        # skip the header row
        if parts[0].upper().startswith("<FLOW_SIZE"):
            continue
        try:
            mean = float(parts[1])
            err = float(parts[2])
        except ValueError:
            continue
        if math.isnan(mean):               # empty bucket -> nothing to plot
            continue
        labels.append(parts[0])
        means.append(mean)
        upper_err.append(max(err, 0.0))    # tail spread is one-sided / non-negative
    return labels, means, upper_err


def plot(path):
    labels, means, upper_err = read_dat(path)
    if not means:
        print("No plottable rows in {} (all empty/NaN?)".format(path))
        return

    # asymmetric error bars: lower = 0, upper = (p99 - mean)
    yerr = [[0.0] * len(means), upper_err]

    fig, ax = plt.subplots(figsize=(7.5, 4.5))
    bars = ax.bar(labels, means, yerr=yerr, capsize=5,
                  color="steelblue", edgecolor="black", linewidth=0.5)

    # log scale so the tiny sub-2.0 buckets stay readable next to 'infi'
    ax.set_yscale("log")
    ax.axhline(1.0, color="grey", linestyle="--", linewidth=1,
               label="ideal (slowdown = 1.0)")

    ax.set_xlabel("Flow size bucket")
    ax.set_ylabel("FCT slowdown  (mean; upper bar = p99)")
    title = os.path.basename(path).replace("_slowdown_size.dat", "")
    ax.set_title("dcPIM FCT slowdown by flow size — {}".format(title))
    ax.legend()

    # annotate each bar with its mean value
    for rect, m in zip(bars, means):
        ax.annotate("{:.2f}".format(m),
                    xy=(rect.get_x() + rect.get_width() / 2, m),
                    xytext=(0, 4), textcoords="offset points",
                    ha="center", va="bottom", fontsize=8)

    fig.tight_layout()
    out = os.path.splitext(path)[0] + ".png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print("wrote {}".format(out))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    if len(sys.argv) > 1:
        targets = sys.argv[1:]
    else:
        targets = sorted(glob.glob(os.path.join(here, "*_slowdown_size.dat")))
    if not targets:
        print("No *_slowdown_size.dat found. Pass a path explicitly.")
        return
    for t in targets:
        plot(t)


if __name__ == "__main__":
    main()
