#!/usr/bin/env bash
# Short-path copies of raw Nextflow outputs.
# Why: several raw paths are > 260 characters, which R on Windows cannot open (MAX_PATH). The
# scripts below therefore read byte-identical copies under data/processed/*_src/:
#   01_compute_metrics.R, 03_sim_cost.R  -> data/processed/sim_src/
#   sc_biology.R                         -> data/processed/sc_src/
#   figure7_survival.R                   -> data/processed/survival_src/
# A file is copied only if the target is missing or its md5 differs from the raw file; every
# pair is md5-checked afterwards (exit 1 on mismatch). Raw data is never modified.
# Usage (from anywhere): bash src/prep/make_short_paths.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

CLS=data/raw/final_classification_results
SIM=$CLS/simulated/copied_results_20261003_124923-job13207577-MESSI_results-simulated_data-samplesheet_simulated_full
COV=$CLS/covid_only/copied_results_20261002_100309-job13187233-MESSI_results-real_data-samplesheet_covid_only
HTX=$CLS/htx_only/copied_results_20261003_131419-job13207607-MESSI_results-real_data-samplesheet_htx_only
SURV=data/raw/final_survival_results/copied_results_20261004_105951-job13221238-MESSI_results-run_survival-samplesheet_momix_full

# raw source | short-path target
PAIRS=(
  "$SIM/all_feature_selection_results.csv|data/processed/sim_src/sim_feat.csv"
  "$SIM/execution_trace.txt|data/processed/sim_src/sim_trace.txt"
  "$COV/all_feature_selection_results.csv|data/processed/sc_src/cov_feat.csv"
  "$HTX/all_feature_selection_results.csv|data/processed/sc_src/htx_feat.csv"
  "$SURV/all_langs-result.csv|data/processed/survival_src/all-result.csv"
  "$SURV/metrics_summary.csv|data/processed/survival_src/metrics_summary.csv"
  "$SURV/parsed_metadata.csv|data/processed/survival_src/parsed_metadata.csv"
)

md5() { md5sum "$1" | cut -d' ' -f1; }
for p in "${PAIRS[@]}"; do
  src=${p%%|*}; dst=${p##*|}
  [ -f "$src" ] || { echo "MISSING raw file: $src" >&2; exit 1; }
  ms=$(md5 "$src")
  if [ -f "$dst" ] && [ "$(md5 "$dst")" = "$ms" ]; then
    echo "  ok      $dst ($ms)"
  else
    mkdir -p "$(dirname "$dst")"
    cp -p "$src" "$dst"
    [ "$(md5 "$dst")" = "$ms" ] || { echo "md5 MISMATCH after copy: $dst" >&2; exit 1; }
    echo "  copied  $dst ($ms)"
  fi
done
