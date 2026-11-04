#!/usr/bin/env bash
# Re-draw every final figure (main Fig 3-7 + supplementary figures + panels/) from
# already-processed data, in dependency order. No pipeline / heavy processing re-runs:
# process_benchmark_stats.R, integration_gain.R, process_cost.R, 01_compute_metrics.R, sim_all_metrics.R
# are NOT run here (run them first if the raw data changed). recall_at_k.R and sc_biology.R ARE run:
# they are light, and Fig 4 reads their tables.
# Fig 1, Fig 2 and Fig 5A are BioRender artwork; no script.
# Usage (repo root or anywhere): bash scripts/replot_figures.sh
# Stops at the first failing script (set -e) and prints the tail of its log.
set -euo pipefail
cd "$(dirname "$0")/.."
LOG=logs
mkdir -p "$LOG"
T0=$(date +%s)
run() {
  local f="$1" log="$LOG/$(basename "$1" .R).log" t=$(date +%s)
  echo ">>> [$(date +%H:%M:%S)] Rscript $f"
  if ! Rscript "$f" > "$log" 2>&1; then
    echo "    FAILED after $(( $(date +%s) - t ))s — last lines of $log:"; tail -n 25 "$log"; exit 1
  fi
  echo "    ok ($(( $(date +%s) - t ))s)"
}

# ---- Fig 3 + bulk supplementary (S1-S5) -------------------------------------------------------
run src/benchmark_stats/plot_benchmark_stats.R        # S2, S9
run src/benchmark_stats/plot_benchmark_overview.R     # S1
run src/benchmark_stats/pca50_baseline_comparison.R   # S3A
run src/benchmark_stats/single_modality_baseline.R                        # S3B-C
run src/cost/plot_cost.R                              # S4
run src/benchmark_stats/figure3_bulk.R                # Fig 3 + panels; writes T/mean_ranks_by_metric_dataset_level.csv

# ---- biology tables (bulk + single cell) -> Fig 4 + S5 ----------------------------------------
run src/biology_validation/recall_at_k.R              # BIO/known_gene_discrimination.csv, ranked_genes.rds (-> Fig 4)
run src/biology_validation/sc_biology.R               # SC/sc_known_gene_discrimination.csv (-> Fig 4), SC/figure_sc_biology_{full,covid} (-> S9)
run src/biology_validation/figure4_biology.R          # Fig 4 + panels + S5; writes BIO/{auroc_credibility_cancer,method_by_disease_heatmap}.csv (-> Fig 8)


# ---- Fig 5 single cell + S6 --------------------------------------------------------------------
run src/benchmark_stats/figure_sc_main.R              # SC/*.rds panels, SC/sc_pooled_metrics.csv
run src/benchmark_stats/figure5_single_cell.R         # Fig 5 + panels; copies SC figures into supp (S6)

# ---- Fig 6 simulation + S7, Fig 7 survival + S8 ------------------------------------------
run src/simulated_brief/03_sim_cost.R
run src/simulated_brief/figure6_simulation.R
run src/survival/figure7_survival.R


echo "=== all figures replotted in $(( $(date +%s) - T0 ))s"
