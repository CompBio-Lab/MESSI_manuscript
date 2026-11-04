#!/usr/bin/env bash
# Raw Nextflow outputs (data/raw/...) -> derived tables that the figure scripts read.
# Chain: data/raw -> process_all.sh (this file) -> replot_figures.sh   (= `make all`)
# Writes only derived tables / working plots outside results/final_figures:
#   data/processed/{sim_src,sc_src,survival_src}/   short-path raw copies (md5-checked)
#   data/processed/benchmark_stats/                 PLOTDATA rds + tables/ (stats, integration gain)
#   data/processed/cost/                            COST rds + tables/
#   results/biology_validation/tables/              BIO (bulk known-gene validation)
#   results/sc_new/sc_known_gene_discrimination*.csv + figure_sc_biology_* (single-cell biology)
#   results/simulated_brief/data_derived/           SIM (prediction/recovery/cost/all metrics)
# Tables written as side outputs of figure scripts (figure3_bulk, figure4_biology, figure_sc_main,
# figure7_survival, plot_benchmark_*, single_modality_baseline, pca50...)
# are produced by replot_figures.sh, which runs them in dependency order.
# No Nextflow re-runs. ~sim feature table is 589 MB, so steps 7-9 take most of the time.
# Usage (from anywhere): bash scripts/process_all.sh
set -euo pipefail
cd "$(dirname "$0")/.."
LOG=logs/process
mkdir -p "$LOG"
T0=$(date +%s)
run() {
  local f="$1" log="$LOG/$(basename "$1" | sed 's/\.[^.]*$//').log" t=$(date +%s)
  echo ">>> [$(date +%H:%M:%S)] $f"
  case "$f" in *.sh) cmd=(bash "$f") ;; *) cmd=(Rscript "$f") ;; esac
  if ! "${cmd[@]}" > "$log" 2>&1; then
    echo "    FAILED after $(( $(date +%s) - t ))s — last lines of $log:"; tail -n 25 "$log"; exit 1
  fi
  echo "    ok ($(( $(date +%s) - t ))s)"
}

# 1. short-path copies of raw files (Windows MAX_PATH); copy only if missing/changed, md5-verified
run src/prep/make_short_paths.sh
# 2-3. bulk + multimodal benchmark (RAW/bulk + RAW/mm): PLOTDATA + T/ tables, then integration gain
run src/benchmark_stats/process_benchmark_stats.R
run src/benchmark_stats/integration_gain.R
# 4. cost (execution_trace / parsed_metadata / all_langs-result of RAW/bulk + RAW/mm)
run src/cost/process_cost.R
# 5. bulk biology validation (all_feature_selection_results + data/raw/known_gene_sets)
run src/biology_validation/recall_at_k.R
# 6. single-cell biology (sc_src copies + known_gene_sets + msigdbr Hallmark)
run src/biology_validation/sc_biology.R
# 7-9. simulation (RAW/sim + sim_src copies)
run src/simulated_brief/01_compute_metrics.R
run src/simulated_brief/03_sim_cost.R
run src/simulated_brief/sim_all_metrics.R

echo "=== processing done in $(( $(date +%s) - T0 ))s (logs: $LOG)"
