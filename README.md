# MESSI manuscript: analysis and figure code

Code that turns the output of the [MESSI Nextflow pipeline](https://github.com/CompBio-Lab/MESSI-pipeline) into the derived tables and figures of the MESSI manuscript. Manuscript text is not in this repository.

## Requirements

- R 4.3.3. Packages used: ggplot2 4.0.0, patchwork 1.3.0, cowplot 1.1.3, dplyr 1.1.4, tidyr 1.3.1, readr 2.1.5, stringr, tibble, purrr, here 1.0.1, ggrepel 0.9.5, survival 3.8-3, data.table 1.15.4, svglite 2.1.3, png 0.1-8, msigdbr 10.0.1, msigdbdf, AnnotationDbi 1.64.1, org.Hs.eg.db 3.18.0, illuminaHumanv4.db 1.26.0.
- GNU make and bash. The chain was run on Windows with Git Bash.

## Data

Input data are on Zenodo: [10.5281/zenodo.23965904](https://doi.org/10.5281/zenodo.23965904) (version used for the manuscript). The concept DOI [10.5281/zenodo.18842127](https://doi.org/10.5281/zenodo.18842127) resolves to the latest version. Nothing under `data/raw/` or `data/processed/` is tracked.

Unpack the archives so that `data/raw/` has the layout below:

```bash
unzip final_pipeline_classification_results.zip -d data/raw
unzip final_pipeline_survival_results.zip -d data/raw
unzip known_gene_sets.zip      # run from the repository root
```

```
data/raw/
  final_classification_results/{bulk,multimodal,covid_only,htx_only,pca50-all-data,simulated}/copied_results_*/
  final_survival_results/copied_results_*/
  known_gene_sets/
```

**Two gene lists are not redistributed** and must be added to `data/raw/known_gene_sets/` under these exact names. `make process` and `make figures` stop at `recall_at_k.R` without them.

| File | Source | Used here |
|---|---|---|
| `NCG_cancerdrivers_annotation_supporting_evidence.tsv` | Network of Cancer Genes, <http://network-cancer-genes.org/> | NCG 7.1 |
| `sfari_autism.csv` | SFARI Gene, <https://gene.sfari.org/database/human-gene/> | Downloaded October 2026 |

A different release changes the known-gene tables. With the files used for the manuscript, `recall_at_k.R` prints `[gene sets] cancer=556, AD=703, DKD=227, autism=1289`. The Hallmark allograft-rejection set comes from `msigdbr`.

## Run

From the repository root:

```bash
make process   # data/raw -> derived tables (data/processed, results): about 2 minutes
make figures   # derived tables -> figures: about 3 minutes
```

`make figures` ends by sorting the figures:

- `results/manuscript_figures/`: the figures in the manuscript, named by their number in the manuscript (table below).
- `results/other_figures/`: everything else the scripts write, such as single panels and figures not used in the manuscript.

Times are from a Windows laptop. Logs go to `logs/`. Each step stops at the first failing script. Figures and derived tables are not tracked; they are written when you run the chain.

`src/biology_validation/run_fig4_null.R` is not part of `make figures`. It computes the permutation null behind Fig 4C and Supplementary Fig. S5 (about 6 minutes on 16 cores) and writes the two tables tracked under `results/biology_validation/tables/`, which `figure4_biology.R` reads. Set `MESSI_NULL_WORK` to keep its cache and `MESSI_NULL_OUT` to write elsewhere.

## Figures and scripts

Fig 1, Fig 2 and Fig 5A are BioRender artwork and have no script. Fig 5A is `results/sc_new/sc_design_concept.png`.

| Manuscript figure | File in `results/manuscript_figures/` | Script |
|---|---|---|
| Fig 1 | `Fig1_overview` | Artwork: `data_design_figs/Fig1_overview.png` |
| Fig 2 | `Fig2_architecture` | Artwork: `data_design_figs/Fig2_architecture.png` |
| Fig 3 | `Fig3_bulk_benchmark` | `src/benchmark_stats/figure3_bulk.R` |
| Fig 4 | `Fig4_biology_validity` | `src/biology_validation/figure4_biology.R` |
| Fig 5 | `Fig5_single_cell` | `src/benchmark_stats/figure_sc_main.R`, `figure5_single_cell.R` |
| Fig 6 | `Fig6_simulation` | `src/simulated_brief/figure6_simulation.R` |
| Fig 7 | `Fig7_survival` | `src/survival/figure7_survival.R` |
| Supplementary Fig. S1 | `FigS1_datasets_overview` | `src/benchmark_stats/plot_benchmark_overview.R` |
| Supplementary Fig. S2 | `FigS2_CD_diagrams` | `src/benchmark_stats/plot_benchmark_stats.R` |
| Supplementary Fig. S3A | `FigS3A_PCA50_vs_raw` | `src/benchmark_stats/pca50_baseline_comparison.R` |
| Supplementary Fig. S3B, C | `FigS3BC_single_modality` | `src/benchmark_stats/single_modality_baseline.R` |
| Supplementary Fig. S4 | `FigS4_bulk_cost` | `src/cost/plot_cost.R` |
| Supplementary Fig. S5 | `FigS5_known_gene_per_dataset` | `src/biology_validation/figure4_biology.R` |
| Supplementary Fig. S6 | `FigS6_single_cell_variants` | `src/benchmark_stats/figure_sc_main.R`, `figure5_single_cell.R` |
| Supplementary Fig. S7A | `FigS7A_sim_prediction` | `src/simulated_brief/figure6_simulation.R` |
| Supplementary Fig. S7B | `FigS7B_sim_recovery` | `src/simulated_brief/figure6_simulation.R` |
| Supplementary Fig. S8 | `FigS8_survival_per_dataset` | `src/survival/figure7_survival.R` |
| Supplementary Fig. S9 | `FigS9_calibration` | `src/benchmark_stats/plot_benchmark_stats.R` |

## Other folders

- `scripts/`: the build scripts called by the Makefile.
- `src/prep/make_short_paths.sh`: copies raw files with long paths to `data/processed/*_src/`, because R on Windows cannot open paths over 260 characters.
- `simulated_data_gen_code/`: generator of the 45 simulated datasets (`create_data.R`, `simulation.R`; seed 101) and the MAE and MuData converter (`converter_mae_mudata/`).
- `src/cleaning_scripts/`, `src/get_dataset_metadata.R`, `src/table1_dataset_description/`, `src/table2_method_description/`: earlier data preparation and table scripts. They are not part of the chain, and some expect input paths that no longer exist.
