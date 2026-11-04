#!/usr/bin/env bash
# Sort the output of replot_figures.sh (called by `make figures`):
#   results/manuscript_figures/  figures in the manuscript, named by their number there
#   results/other_figures/       everything else the scripts write
# results/final_figures/ is the scripts' working folder and is emptied by this step.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=results/final_figures
OUT=results/manuscript_figures
OTHER=results/other_figures

# manuscript file name : output of the figure scripts
FIGURES=(
  "Fig3_bulk_benchmark:main/Fig3_bulk_benchmark"
  "Fig4_biology_validity:main/Fig4_biology_validity"
  "Fig5_single_cell:main/Fig5_single_cell"
  "Fig6_simulation:main/Fig6_simulation"
  "Fig7_survival:main/Fig7_survival"
  "FigS1_datasets_overview:supp/FigS_bulk_overview"
  "FigS2_CD_diagrams:supp/FigS_bulk_cd_dataset_level"
  "FigS3A_PCA50_vs_raw:supp/FigS_bulk_pca50_vs_raw"
  "FigS3BC_single_modality:supp/FigS_bulk_single_modality_detail"
  "FigS4_bulk_cost:supp/FigS_bulk_cost_memory_scaling"
  "FigS5_known_gene_per_dataset:supp/FigS_biology_auroc_heatmap"
  "FigS6_single_cell_variants:supp/FigS_sc_performance_detail"
  "FigS7A_sim_prediction:supp/FigS_sim_prediction_by_rho"
  "FigS7B_sim_recovery:supp/FigS_sim_recovery_by_rho"
  "FigS8_survival_per_dataset:supp/FigS_survival_per_dataset"
  "FigS9_calibration:supp/FigS_bulk_calibration"
)

# Check everything first, so a partial run leaves the existing folders untouched.
for entry in "${FIGURES[@]}"; do
  from="${entry#*:}"
  for ext in png pdf; do
    if [ ! -f "$SRC/$from.$ext" ]; then
      echo "Missing $SRC/$from.$ext. Run 'make figures' first." >&2
      exit 1
    fi
  done
done

rm -rf "$OUT" "$OTHER"
mkdir -p "$OUT" "$OTHER"

cp data_design_figs/Fig1_overview.png "$OUT/Fig1_overview.png"
cp data_design_figs/Fig2_architecture.png "$OUT/Fig2_architecture.png"

for entry in "${FIGURES[@]}"; do
  name="${entry%%:*}"
  from="${entry#*:}"
  for ext in png pdf; do
    mv "$SRC/$from.$ext" "$OUT/$name.$ext"
  done
done

for sub in main supp panels; do
  if [ -d "$SRC/$sub" ]; then
    mkdir -p "$OTHER/$sub"
    find "$SRC/$sub" -mindepth 1 -maxdepth 1 -exec mv {} "$OTHER/$sub/" \;
  fi
done
rm -rf "$SRC"

echo "=== $(find "$OUT" -type f | wc -l) files in $OUT, $(find "$OTHER" -type f | wc -l) files in $OTHER"
