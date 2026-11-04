# ==============================================================================
# plot_benchmark_stats.R
# Plot step for the benchmark statistics. Reads the plot_data_list
# produced by process_benchmark_stats.R and renders, in the house ggplot style:
#   - Nemenyi critical-difference diagrams (ROC-AUC, PR-AUC, MCC, balanced acc)
#   - mean-rank heatmap across metrics
#   - per-dataset metric plots (pooled dot + fold range) with no-signal flags
#   - reliability / calibration curves
#
# Usage:
#   Rscript src/benchmark_stats/plot_benchmark_stats.R \
#     --input data/processed/benchmark_stats/benchmark_stats_plot_data.rds \
#     --outdir results/benchmark_stats
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(stringr)
  library(tibble); library(here); library(cowplot)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))
library(patchwork)

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag); if (length(i) == 1 && i < length(args)) args[i + 1] else default
}
input  <- get_arg("--input",  here::here("data/processed/benchmark_stats/benchmark_stats_plot_data.rds"))
outdir <- get_arg("--outdir", here::here("results/benchmark_stats"))
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
D <- readRDS(input)

theme_bench <- function(base = 9) theme_messi(base)
METRIC_LAB <- c(roc_auc = "ROC-AUC", pr_auc = "PR-AUC",
                matthews_corrcoef = "MCC", balanced_accuracy = "Balanced accuracy",
                f1_score = "F1")

SUPP <- here::here("results/final_figures/supp")
n_ds <- length(D$mm_datasets)
fr_tab <- D$friedman
fr_sub <- function(metric, scope) {
  r <- fr_tab %>% filter(metric == !!metric, scope == !!scope)
  sprintf("%d %s; Friedman p = %.1e, Kendall's W = %.2f", r$n_blocks,
          ifelse(scope == "dataset_level", "datasets", "dataset x fold blocks"), r$p, r$kendall_w)
}

# ------------------------------------------------------------- CD diagrams
# dataset-level (main text: ROC-AUC in Fig 3; others supp) + fold-level (supp)
cd_plots_ds <- list(); cd_plots_fold <- list()
for (m in c("roc_auc", "pr_auc", "matthews_corrcoef", "balanced_accuracy")) {
  cd_plots_ds[[m]] <- plot_cd_ggplot(D$mean_ranks_ds[[m]], D$cd_ds[[m]],
                                     sprintf("%s: dataset-level ranks", METRIC_LAB[m]),
                                     fr_sub(m, "dataset_level"))
  cd_plots_fold[[m]] <- plot_cd_ggplot(D$mean_ranks[[m]], D$cd_fold[[m]],
                                       sprintf("%s: fold-level ranks", METRIC_LAB[m]),
                                       fr_sub(m, "fold_level"))
  save_plot_both(cd_plots_ds[[m]], file.path(outdir, paste0("cd_", m, "_dataset_level.png")),
                 width = 7, height = 2.6, dpi = 300)
  save_plot_both(cd_plots_fold[[m]], file.path(outdir, paste0("cd_", m, ".png")),
                 width = 7, height = 2.6, dpi = 300)
}
cd_note <- theme(plot.caption = element_text(size = 7, hjust = 0, color = "grey30"))
s_fold <- patchwork::wrap_plots(cd_plots_fold, ncol = 1) +   # no in-image tags: legend letters belong to the S-figure; sub-panels named by metric title
  patchwork::plot_annotation(
    caption = "Fold-level blocks (dataset x outer fold) are not independent, so this CD is optimistic;
the main-text CD (Fig. 3) uses dataset-level ranks.",
    theme = cd_note)
save_final_fig(s_fold, file.path(SUPP, "FigS_bulk_cd_fold_level"), width = 7, height = 10)
s_oth <- patchwork::wrap_plots(cd_plots_ds[c("pr_auc", "matthews_corrcoef", "balanced_accuracy")], ncol = 1) +
  patchwork::plot_annotation(tag_levels = "A",
    caption = sprintf("Nemenyi critical difference on per-dataset mean ranks (%d datasets, 11 methods, alpha = 0.05).
Bars join methods that are not significantly different.", n_ds),
    theme = cd_note)
save_final_fig(s_oth, file.path(SUPP, "FigS_bulk_cd_other_metrics"), width = 7, height = 7.6)

# ------------------------------------------------------------- mean-rank heatmap (dataset- and fold-level)
mr_heat <- bind_rows(
  bind_rows(lapply(names(D$mean_ranks_ds), function(m) tibble(metric = m, scope = "Dataset-level ranks",
    method = names(D$mean_ranks_ds[[m]]), mean_rank = as.numeric(D$mean_ranks_ds[[m]])))),
  bind_rows(lapply(names(D$mean_ranks), function(m) tibble(metric = m, scope = "Fold-level ranks",
    method = names(D$mean_ranks[[m]]), mean_rank = as.numeric(D$mean_ranks[[m]])))))
ord <- method_levels(unique(mr_heat$method))   # fixed house order
mr_heat <- mr_heat %>%
  mutate(method = factor(method, levels = rev(ord)),
         metric = factor(METRIC_LAB[metric], levels = unname(METRIC_LAB[names(D$mean_ranks)])))
p_heat <- ggplot(mr_heat, aes(metric, method, fill = mean_rank)) +
  geom_tile(color = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.1f", mean_rank)), size = 2.6) +
  facet_wrap(~ scope) +
  scale_fill_gradientn(colors = c("#1A9850", "#FFFFBF", "#D73027"), name = "Mean rank
(1 = best)") +
  labs(title = sprintf("Mean rank across %d datasets (11 methods)", n_ds), x = NULL, y = NULL) +
  theme_bench(9) + theme(panel.grid = element_blank(), strip.text = element_text(face = "bold"),
                         axis.text.x = element_text(angle = 30, hjust = 1),
                         axis.text.y = element_text(color = BENCH_CLASS_COLORS[method_class(rev(ord))]))
save_plot_both(p_heat, file.path(outdir, "mean_rank_heatmap.png"), width = 7, height = 4.2, dpi = 300)
save_final_fig(p_heat, file.path(SUPP, "FigS_bulk_mean_rank_heatmap"), width = 7, height = 4.2)

# ------------------------------------------------------------- per-dataset metric
plot_per_dataset <- function(metric) {
  pooled <- D$pooled7 %>% mutate(method_name = as.character(method_name))
  fold   <- D$fold7   %>% mutate(method_name = as.character(method_name))
  ds_order <- pooled %>% group_by(dataset) %>% summarise(x = max(.data[[metric]], na.rm = TRUE)) %>%
    arrange(desc(x)) %>% pull(dataset)
  frange <- fold %>% group_by(method_name, dataset) %>%
    summarise(lo = min(.data[[metric]], na.rm = TRUE),
              hi = max(.data[[metric]], na.rm = TRUE), .groups = "drop")
  dat <- pooled %>% select(method_name, dataset, val = all_of(metric)) %>%
    left_join(frange, by = c("method_name", "dataset")) %>%
    mutate(dataset = factor(dataset, levels = rev(ds_order)),
           method_name = factor(method_name, levels = method_levels(unique(method_name))))
  ns_df <- tibble(dataset = factor(D$no_signal, levels = rev(ds_order)))
  ggplot(dat, aes(val, dataset, color = method_name)) +
    geom_linerange(aes(xmin = lo, xmax = hi), orientation = "y",
                   position = position_dodge(width = 0.75), linewidth = 0.3, alpha = 0.45) +
    geom_point(position = position_dodge(width = 0.75), size = 0.9) +
    { if (nrow(ns_df) > 0) geom_text(data = ns_df, aes(x = Inf, y = dataset),
        label = "no signal", inherit.aes = FALSE, hjust = 1.02, size = 2.6,
        color = "grey50", fontface = "italic") } +
    geom_vline(xintercept = 0.5, linetype = "dashed", color = "grey60", linewidth = 0.4) +
    scale_color_viridis_d(option = "turbo", name = NULL) +
    labs(title = sprintf("%s per dataset (dot = pooled, line = fold range)", METRIC_LAB[metric]),
         x = METRIC_LAB[metric], y = NULL) +
    guides(color = guide_legend(nrow = 3, override.aes = list(size = 2))) +
    theme_bench(9) + theme(legend.position = "bottom", legend.text = element_text(size = 7),
                           legend.key.height = unit(8, "pt"), legend.key.width = unit(10, "pt"))
}
for (m in c("roc_auc", "pr_auc", "f1_score")) {
  save_plot_both(plot_per_dataset(m),
                 file.path(outdir, paste0("per_dataset_", m, ".png")),
                 width = 8, height = 8, dpi = 300)
}
save_final_fig(plot_per_dataset("roc_auc") +
                 labs(title = sprintf("ROC-AUC per dataset (%d datasets)", n_ds),
                      subtitle = "dot = pooled out-of-fold ROC-AUC; line = range over the outer CV folds",
                      caption = sprintf("'no signal' = no method reaches pooled ROC-AUC 0.6 (%d datasets).", length(D$no_signal))),
               file.path(SUPP, "FigS_bulk_per_dataset_roc_auc"), width = 7, height = 9)

# ------------------------------------------------------------- calibration
# Pooled reliability curve per method (bins aggregated across datasets). Scores are clipped
# to [0, 1] before binning (DIABLO / RGCCA emit decision scores slightly outside).
cal_curve <- D$calibration$curve %>%
  group_by(method_name, bin) %>%
  summarise(p_mean = weighted.mean(p_mean, n), y_rate = weighted.mean(y_rate, n),
            n = sum(n), .groups = "drop") %>%
  mutate(class = method_class(as.character(method_name)),
         method_name = factor(method_name, levels = method_levels(unique(method_name))))
p_cal <- ggplot(cal_curve, aes(p_mean, y_rate)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
  geom_line(aes(color = class), linewidth = 0.5) + geom_point(aes(size = n, color = class), alpha = 0.7) +
  facet_wrap(~ method_name, ncol = 4) +
  scale_color_manual(values = BENCH_CLASS_COLORS, name = NULL) +
  scale_size_continuous(range = c(0.3, 2.2), guide = "none") +
  scale_x_continuous(breaks = c(0, .5, 1)) + scale_y_continuous(breaks = c(0, .5, 1)) +
  coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
  labs(title = "Reliability (pooled across datasets)",
       x = "Mean predicted probability", y = "Observed event rate") +
  theme_bench(8) + theme(legend.position = "bottom", strip.text = element_text(face = "bold", size = 7),
                         panel.grid.major.x = element_line(color = "grey92"))
save_plot_both(p_cal, file.path(outdir, "calibration_reliability.png"), width = 7, height = 6, dpi = 300)

cal_summ <- D$calibration$summary %>%
  group_by(method_name) %>%
  summarise(brier = median(brier, na.rm = TRUE), ece = median(ece, na.rm = TRUE), .groups = "drop") %>%
  pivot_longer(c(brier, ece)) %>%
  mutate(class = method_class(method_name),
         method_name = method_factor_y(method_name),
         name = recode(name, brier = "Brier score (lower = better)", ece = "ECE (lower = better)"))
p_be <- ggplot(cal_summ, aes(value, method_name, fill = class)) +
  geom_col(width = 0.7) +
  facet_wrap(~name, scales = "free_x") +
  scale_fill_manual(values = BENCH_CLASS_COLORS, guide = "none") +
  labs(title = sprintf("Calibration error (median across %d datasets)", n_ds), x = NULL, y = NULL) +
  theme_bench(8) + theme(strip.text = element_text(face = "bold"))
save_plot_both(p_be, file.path(outdir, "calibration_brier_ece.png"), width = 7, height = 3, dpi = 300)
s_cal <- (p_cal + labs(tag = "A") + theme(plot.tag = element_text(face = "bold", size = 14))) /
  (p_be + labs(tag = "B") + theme(plot.tag = element_text(face = "bold", size = 14))) + plot_layout(heights = c(2.4, 1)) +
  plot_annotation(
    caption = "Scores clipped to [0, 1] before calibration. ECE with 10 equal-width bins.",
    theme = theme(plot.caption = element_text(size = 7, hjust = 0, color = "grey30")))
save_final_fig(s_cal, file.path(SUPP, "FigS_bulk_calibration"), width = 7, height = 9)


# ------------------------------------------------------------- classic dataset-level CD (all 4 metrics)
s_ds <- patchwork::wrap_plots(cd_plots_ds, ncol = 1) +
  patchwork::plot_annotation(tag_levels = "A", theme = theme(plot.tag = element_text(face = "bold", size = 14)))
save_final_fig(s_ds, file.path(SUPP, "FigS_bulk_cd_dataset_level"), width = 7, height = 10)

# ------------------------------------------------------------- cohort sensitivity (ROC-AUC mean rank within cohorts)
# Rank the 11 methods within each dataset (pooled ROC-AUC), then average within cohort.
# NOTE: MOMIX datasets are reprocessed TCGA cohorts, so TCGA and MOMIX are not independent.
coh_of <- function(d) dplyr::case_when(str_starts(d, "tcga") ~ "TCGA", str_starts(d, "momix") ~ "MOMIX",
                                       TRUE ~ "Other (GEO, ROSMAP, clinical/electrical/imaging)")
rk <- rank_table(D$pooled7 %>% mutate(method_name = as.character(method_name)), "roc_auc")
rk_long <- as_tibble(rk, rownames = "dataset") %>%
  pivot_longer(-dataset, names_to = "method", values_to = "rank") %>%
  mutate(cohort = coh_of(dataset))
coh <- rk_long %>% group_by(cohort, method) %>%
  summarise(mean_rank = mean(rank), n_datasets = n_distinct(dataset), .groups = "drop")
coh_w <- coh %>% select(cohort, method, mean_rank) %>% pivot_wider(names_from = cohort, values_from = mean_rank)
cn <- setdiff(names(coh_w), "method")
tau <- bind_rows(combn(cn, 2, simplify = FALSE) |> lapply(function(pr) {
  ct <- suppressWarnings(cor.test(coh_w[[pr[1]]], coh_w[[pr[2]]], method = "kendall", exact = FALSE))
  tibble(cohort_a = pr[1], cohort_b = pr[2], kendall_tau = unname(ct$estimate), p = ct$p.value)
}))
tbl_dir <- here::here("data/processed/benchmark_stats/tables")
write_csv(coh, file.path(tbl_dir, "cohort_mean_ranks_roc_auc.csv"))
write_csv(tau, file.path(tbl_dir, "cohort_rank_kendall_tau.csv"))
print(as.data.frame(tau))
ncoh <- coh %>% distinct(cohort, n_datasets) %>% mutate(lab = sprintf("%s (n = %d)", cohort, n_datasets))
coh_p <- coh %>% left_join(ncoh %>% select(cohort, lab), by = "cohort") %>%
  mutate(method = method_factor_y(method),
         lab = factor(lab, levels = ncoh$lab[order(match(ncoh$cohort, c("TCGA", "MOMIX", "Other (GEO, ROSMAP, clinical/electrical/imaging)")))]))
COH_SHAPE <- setNames(c(16, 17, 15), levels(coh_p$lab))
tau_txt <- paste(sprintf("%s vs %s: tau = %.2f (p = %.2g)", sub(" [(].*", "", tau$cohort_a),
                         sub(" [(].*", "", tau$cohort_b), tau$kendall_tau, tau$p), collapse = "
")
p_coh <- ggplot(coh_p, aes(mean_rank, method)) +
  geom_line(aes(group = method), colour = "grey80") +
  geom_point(aes(shape = lab, colour = lab), size = 2.2) +
  scale_colour_manual(values = c("#333333", "#888888", "#BBBBBB"), name = NULL) +
  scale_shape_manual(values = COH_SHAPE, name = NULL) +
  scale_x_continuous(limits = c(1, 11), breaks = 1:11) +
  labs(title = "Method ranking within cohorts (ROC-AUC)", x = "Mean rank within cohort (1 = best)", y = NULL,
       caption = paste0("Kendall's tau between cohort rankings (11 methods):
", tau_txt,
                        ".\nMOMIX datasets are reprocessed TCGA cohorts, so TCGA and MOMIX are not independent.")) +
  guides(colour = guide_legend(nrow = 1), shape = guide_legend(nrow = 1)) +
  theme_bench(9) + theme(axis.text.y = element_text(colour = CLASS_COLORS[method_class(levels(coh_p$method))]),
                         plot.caption = element_text(size = 6.5, hjust = 0, colour = "grey30"))
save_final_fig(p_coh, file.path(SUPP, "FigS_bulk_cohort_sensitivity"), width = 7, height = 5)

message("[done] wrote figures to ", outdir)
