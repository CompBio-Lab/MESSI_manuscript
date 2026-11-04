# ==============================================================================
# plot_benchmark_overview.R  (imbalance-aware presentation; dataset landscape)
# Reads the plot_data_list from process_benchmark_stats.R. House style: theme_messi,
# fixed method order (method_levels), integration-class colours.
#
#   benchmark_overview   A dataset landscape (subjects x positive proportion, by cohort)
#                        B per-method PR-AUC minus prevalence (chance-corrected PR-AUC)
#   imbalance            A F1 vs prevalence with the always-positive reference F1 = 2p/(1+p)
#                        B balanced accuracy vs ROC-AUC
# Final supplementary figures:
#   results/final_figures/supp/FigS_bulk_overview.{png,pdf}
#   results/final_figures/supp/FigS_bulk_imbalance.{png,pdf}
# (The per-method ROC-AUC distribution and dataset-level CD are in main Fig 3.)
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(stringr)
  library(tibble); library(here); library(readr)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, d = NULL) { i <- which(args == flag); if (length(i) == 1 && i < length(args)) args[i + 1] else d }
input  <- get_arg("--input",  here::here("data/processed/benchmark_stats/benchmark_stats_plot_data.rds"))
outdir <- get_arg("--outdir", here::here("results/benchmark_stats"))
SUPP   <- here::here("results/final_figures/supp")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
D <- readRDS(input)

COHORT_COL <- c(GEO = "#0072B2", ROSMAP = "#009E73", MOMIX = "#D55E00", TCGA = "#CC79A7", Multimodal = "#555555")
cohort_of <- function(d) dplyr::case_when(
  str_starts(d, "GSE") ~ "GEO", d == "rosmap" ~ "ROSMAP", str_starts(d, "momix") ~ "MOMIX",
  str_starts(d, "tcga") ~ "TCGA", TRUE ~ "Multimodal")  # clinical_omics (prostate), electrical_omics (heart failure), imaging_omics (DKD)

pooled <- D$pooled7 %>% mutate(method_name = as.character(method_name))
meta <- pooled %>% group_by(dataset) %>%
  summarise(n_subjects = max(n), positive_prop = max(n_pos) / max(n), .groups = "drop") %>%
  mutate(source = factor(cohort_of(dataset), levels = names(COHORT_COL)))
write_csv(meta, here::here("data/processed/benchmark_stats/tables/dataset_landscape.csv"))
n_ds <- nrow(meta)
pooled <- pooled %>% left_join(meta %>% select(dataset, positive_prop, source), by = "dataset") %>%
  mutate(pr_gain = pr_auc - positive_prop,
         class = method_class(method_name),
         method_y = method_factor_y(method_name),
         method_f = factor(method_name, levels = method_levels(unique(method_name))))
MLV <- levels(pooled$method_y)

# ----------------------------------------------------- A dataset landscape
pA <- ggplot(meta, aes(n_subjects, positive_prop, colour = source)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_point(size = 2.2, alpha = 0.9) +
  scale_x_log10() + scale_colour_manual(values = COHORT_COL, name = NULL) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(title = sprintf("%d datasets", n_ds), x = "Subjects (log scale)", y = "Positive proportion") +
  guides(colour = guide_legend(nrow = 2)) + theme_messi()

# ----------------------------------------------------- B PR-AUC minus prevalence
pB <- ggplot(pooled, aes(pr_gain, method_y)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_boxplot(aes(fill = class), outlier.shape = NA, width = 0.65, alpha = 0.35, colour = "grey30", linewidth = 0.35) +
  geom_point(aes(colour = class), position = position_jitter(height = 0.15, width = 0, seed = 1), size = 0.6, alpha = 0.7) +
  scale_fill_class() + scale_colour_class() +
  labs(title = "PR-AUC above prevalence", x = "PR-AUC − positive proportion", y = NULL) +
  theme_messi() + theme(axis.text.y = element_text(colour = CLASS_COLORS[method_class(MLV)]),
                        legend.position = "none")
ov <- cowplot::plot_grid(pA, pB, ncol = 2, rel_widths = c(1, 1.2), labels = c("A", "B"),
                         label_size = 14, label_fontface = "bold", hjust = 0, label_x = 0.005) +
  theme(plot.background = element_rect(fill = "white", colour = NA))
save_plot_both(ov, file.path(outdir, "benchmark_overview.png"), width = 7, height = 3.6, dpi = 300)
save_final_fig(ov, file.path(SUPP, "FigS_bulk_overview"), width = 7, height = 3.6)

# ----------------------------------------------------- imbalance diagnostics
ref_curve <- tibble(positive_prop = seq(0, 1, 0.01)) %>% mutate(f1 = 2 * positive_prop / (1 + positive_prop))
pF1 <- ggplot(pooled, aes(positive_prop, f1_score)) +
  geom_line(data = ref_curve, aes(positive_prop, f1), linetype = "dashed", colour = "grey50") +
  geom_point(aes(colour = class), size = 0.9, alpha = 0.8) +
  facet_wrap(~ method_f, ncol = 6) +
  scale_colour_class() + scale_x_continuous(breaks = c(0, 0.5, 1), labels = c("0", "0.5", "1")) +
  labs(title = "F1 vs class balance", x = "Positive proportion", y = "Pooled F1") +
  theme_messi(8) + theme(legend.position = "none", strip.text = element_text(size = 6.5))
pBA <- ggplot(pooled, aes(roc_auc, balanced_accuracy)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey50") +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey50") +
  geom_point(aes(colour = class), size = 0.9, alpha = 0.8) +
  facet_wrap(~ method_f, ncol = 6) +
  scale_colour_class() + scale_x_continuous(breaks = c(0.5, 0.75, 1), labels = c("0.5", ".75", "1")) +
  labs(title = "Balanced accuracy vs ROC-AUC", x = "Pooled ROC-AUC", y = "Balanced accuracy",
       caption = "Dashed curve in the F1 panels: always-positive classifier, F1 = 2p / (1 + p). Threshold 0.5 for F1 and balanced accuracy.") +
  theme_messi(8) + theme(legend.position = "bottom", strip.text = element_text(size = 6.5),
                         plot.caption = element_text(size = 6.5, hjust = 0, colour = "grey30"))
save_plot_both(pF1, file.path(outdir, "imbalance_f1_vs_prevalence.png"), width = 7, height = 3.6, dpi = 300)
save_plot_both(pBA, file.path(outdir, "imbalance_balacc_vs_roc.png"), width = 7, height = 3.6, dpi = 300)
imb <- cowplot::plot_grid(pF1, pBA, ncol = 1, rel_heights = c(1, 1.15)) +   # no in-image tags (S4 legend letters)
  theme(plot.background = element_rect(fill = "white", colour = NA))
save_final_fig(imb, file.path(SUPP, "FigS_bulk_imbalance"), width = 7, height = 7.5)
message("[done] overview + imbalance figures")
