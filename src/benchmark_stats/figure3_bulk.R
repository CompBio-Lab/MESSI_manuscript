# ==============================================================================
# figure3_bulk.R — MAIN Figure 3.
# Bulk multimodal benchmark: 26 datasets x 11 methods, DEFAULT hyperparameters. 7 in wide, <= 8.5 in.
#
#   Row 1: A pooled ROC-AUC per method (box + points, class colours, fixed method order)
#          B rank-by-metric heatmap (dataset-level mean rank; ROC, PR, MCC, BA, F1)
#   Row 2: C Demsar critical-difference diagram on dataset-level ROC-AUC ranks (span-rule cliques, CD = 2.96)
#   Row 3: D integration gain vs mean / best single modality (median, IQR; filled = Holm p < 0.05)
#          E cost vs performance (median training time per fold vs mean ROC-AUC)
# Dataset landscape -> FigS_bulk_overview (plot_benchmark_overview.R).
#
#
# Inputs (run first): process_benchmark_stats.R, integration_gain.R, src/cost/process_cost.R
# Outputs: results/final_figures/main/Fig3_bulk_benchmark.{png,pdf,rds}
#          results/final_figures/panels/Fig3_<letter>_<name>.{pdf,svg}  (each panel alone, no tag)
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(stringr); library(tibble)
  library(here); library(readr); library(cowplot)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))   # theme_messi, labels, plot_cd_ggplot

MAIN  <- here::here("results/final_figures/main")
PANEL <- here::here("results/final_figures/panels")
dir.create(MAIN, recursive = TRUE, showWarnings = FALSE); dir.create(PANEL, recursive = TRUE, showWarnings = FALSE)
TBL <- here::here("data/processed/benchmark_stats/tables")

D    <- readRDS(here::here("data/processed/benchmark_stats/benchmark_stats_plot_data.rds"))
gtst <- read_csv(file.path(TBL, "integration_gain_tests.csv"), show_col_types = FALSE)
COST <- readRDS(here::here("data/processed/cost/cost_plot_data.rds"))
n_ds <- length(D$mm_datasets)

REF_COL <- setNames(PAIR_COLORS, c("vs mean modality", "vs best modality"))
MLV  <- rev(method_levels(unique(as.character(D$pooled7$method_name))))   # first method on top
ymet <- function(x) factor(x, levels = MLV)
cls  <- method_class(MLV)
SEP  <- which(cls[-1] != cls[-length(cls)]) + 0.5                          # between class groups
sep_layer <- geom_hline(yintercept = SEP, colour = "grey60", linewidth = 0.3)
ylab_col  <- element_text(colour = CLASS_COLORS[cls], size = 8)
CALL <- list(colour = "grey20", fontface = "bold", size = 8 / .pt)   # callouts: 8 pt bold grey20 (all main figs)
TAGM <- theme(plot.margin = margin(16, 6, 3, 6))

# ---------------------------------------------------------------- A  ROC-AUC per method
pooled <- D$pooled7 %>% mutate(method = ymet(as.character(method_name)),
                               class = method_class(as.character(method_name)))
pA <- ggplot(pooled, aes(roc_auc, method)) +
  sep_layer +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_boxplot(aes(fill = class), outlier.shape = NA, width = 0.65, alpha = 0.35, linewidth = 0.3,
               colour = "grey30") +
  geom_point(aes(colour = class), position = position_jitter(height = 0.14, width = 0, seed = 1),
             size = 0.6, alpha = 0.7) +
  scale_fill_class() + scale_colour_class() +
  scale_x_continuous(limits = c(0.3, 1), breaks = seq(0.3, 1, 0.1)) +
  labs(title = "Discrimination", x = sprintf("Pooled ROC-AUC (%d datasets)", n_ds), y = NULL) +
  theme_messi() + theme(axis.text.y = ylab_col, legend.position = "none") + TAGM

# ---------------------------------------------------------------- B  rank by metric
cal <- D$calibration$summary %>% transmute(method_name, dataset, neg_brier = -brier)
pm <- D$pooled7 %>% mutate(method_name = as.character(method_name)) %>%
  left_join(cal, by = c("method_name", "dataset"))
HM_MET <- c(roc_auc = "ROC", pr_auc = "PR", matthews_corrcoef = "MCC",
            balanced_accuracy = "BA", f1_score = "F1", neg_brier = "Brier")
hm <- bind_rows(lapply(names(HM_MET), function(m) {
  r <- colMeans(rank_table(pm, m), na.rm = TRUE)
  tibble(method = names(r), metric = HM_MET[[m]], mean_rank = as.numeric(r))
}))
write_csv(hm %>% pivot_wider(names_from = metric, values_from = mean_rank),
          file.path(TBL, "mean_ranks_by_metric_dataset_level.csv"))
# Brier stays in the table above but is not drawn in panel B.
hm <- hm %>% filter(metric != "Brier") %>%
  mutate(method = ymet(method), metric = factor(metric, levels = setdiff(unname(HM_MET), "Brier")))
pB <- ggplot(hm, aes(metric, method, fill = mean_rank)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = sprintf("%.1f", mean_rank), colour = mean_rank < 4.5), size = 2.4) +
  geom_hline(yintercept = SEP, colour = "grey60", linewidth = 0.3) +
  scale_fill_gradient(low = "#B2182B", high = "white", limits = c(1, 11), breaks = c(1, 4, 7, 10),
                      name = "Mean rank\n(1 = best)") +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "black"), guide = "none") +
  scale_x_discrete(expand = c(0, 0)) + scale_y_discrete(expand = c(0, 0)) +
  labs(title = "Rank by metric", x = NULL, y = NULL) +
  theme_messi() +
  theme(axis.text.y = element_blank(), axis.ticks = element_blank(), panel.grid = element_blank(),
        legend.position = "right",
        legend.key.height = unit(9, "mm"), legend.key.width = unit(2.5, "mm")) +
  theme(plot.margin = margin(16, 6, 3, 16))

# ---------------------------------------------------------------- C  CD diagram (dataset level)
fr <- D$friedman %>% filter(metric == "roc_auc", scope == "dataset_level")
mr_ds <- D$mean_ranks_ds$roc_auc; cd <- D$cd_ds$roc_auc
pC <- plot_cd_ggplot(mr_ds, cd, title = "Method ranking (ROC-AUC, 26 datasets)",
                     subtitle = NULL, base = 9, lab_size = 2.8, margin_lr = c(4, 4)) +
  theme(panel.border = element_blank(), plot.margin = margin(16, 110, 2, 110),
        plot.title = element_text(face = "bold", size = 9 * 1.05),          # = theme_messi panel title
        axis.text.x.top = element_text(size = 9 * 0.95), axis.title.x.top = element_text(size = 9))

# ---------------------------------------------------------------- D  integration gain
gD <- gtst %>% filter(metric == "roc_auc") %>%
  mutate(method = ymet(method_name),
         reference = factor(reference, levels = names(REF_COL)),
         sig = factor(ifelse(p_holm < 0.05, "Holm p < 0.05", "n.s."), levels = c("Holm p < 0.05", "n.s.")))
pD <- ggplot(gD, aes(median_gain, method, colour = reference)) +
  sep_layer +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_errorbar(aes(xmin = q25, xmax = q75, group = reference), width = 0, orientation = "y", linewidth = 0.45,
                position = position_dodge(width = 0.6)) +
  geom_point(aes(shape = sig, group = reference), size = 1.7, fill = "white", stroke = 0.6, position = position_dodge(width = 0.6)) +
  annotate("text", x = -Inf, y = length(MLV) + 1.1, hjust = -0.03, vjust = 0.5,
           label = "No method beats the best single view",
           colour = CALL$colour, fontface = CALL$fontface, size = CALL$size) +
  scale_colour_manual(values = REF_COL, name = NULL, labels = c("vs mean single view", "vs best single view")) +
  scale_shape_manual(values = c("Holm p < 0.05" = 16, "n.s." = 21), name = NULL) +
  scale_y_discrete(expand = expansion(add = c(0.6, 1.4))) +
  labs(title = "Gain over single modality", x = "Δ ROC-AUC (median, IQR)", y = NULL) +
  guides(colour = guide_legend(nrow = 2, order = 1), shape = guide_legend(nrow = 2, order = 2)) +
  theme_messi() + theme(axis.text.y = ylab_col, legend.position = "bottom",
                        legend.margin = margin(0, 0, 0, 0), legend.box.margin = margin(-4, 0, 0, 0)) + TAGM

# ---------------------------------------------------------------- E  cost vs performance
# y = dataset-level mean rank of ROC-AUC (same numbers as panel C); a cross-dataset mean
# ROC-AUC is not used because datasets differ widely in difficulty.
# x = per-fold TRAIN task time (Nextflow trace) -> median over the 5 folds per dataset
#     -> median over the 26 datasets (feature-selection full-data fit excluded).
tr <- COST$cost_perf %>% group_by(method, method_class) %>%
  summarise(time_s = median(time_s), .groups = "drop") %>%
  left_join(tibble(method = names(mr_ds), mean_rank = as.numeric(mr_ds)), by = "method")
pE <- ggplot(tr, aes(time_s, mean_rank, colour = method_class)) +
  geom_point(size = 2.2) +
  ggrepel::geom_text_repel(aes(label = method), size = 2.6, show.legend = FALSE, seed = 11,
                           box.padding = 0.45, min.segment.length = 0.2, max.overlaps = Inf) +
  scale_x_log10(breaks = c(3, 10, 30, 100, 300, 1000), limits = c(4, 1300)) +
  scale_colour_class() +
  scale_y_reverse(breaks = 3:9, limits = c(9, 3)) +
  labs(title = "Cost vs performance", x = "Median training time per fold (s, log)",
       y = "Mean rank (ROC-AUC, 1 = best)") +
  theme_messi() + theme(legend.position = "bottom", legend.margin = margin(0, 0, 0, 0),
                        legend.box.margin = margin(-4, 0, 0, 0)) + TAGM

# ---------------------------------------------------------------- assemble
W <- 7; H <- 8.5
LAB <- list(label_size = 14, label_fontface = "bold", hjust = 0, label_x = 0.005, label_y = 1)
W1 <- c(1.25, 1); W3 <- c(1.05, 1)
row1 <- do.call(plot_grid, c(list(pA, pB, ncol = 2, rel_widths = W1, align = "h", axis = "tb",
                                  labels = c("A", "B")), LAB))
row2 <- do.call(plot_grid, c(list(pC, labels = "C"), LAB))
row3 <- do.call(plot_grid, c(list(pD, pE, ncol = 2, rel_widths = W3, align = "h", axis = "tb",
                                  labels = c("D", "E")), LAB))
HGT <- c(3.1, 1.95, 3.45)
fig <- plot_grid(row1, row2, row3, ncol = 1, rel_heights = HGT) +
  theme(plot.background = element_rect(fill = "white", colour = NA))
save_main(fig, file.path(MAIN, "Fig3_bulk_benchmark"), height = H, width = W)
message("[done] Fig 3 v2 -> ", MAIN)

# ---------------------------------------------------------------- single-panel exports (exact size, no tag)
hs <- HGT / sum(HGT) * H
panels <- list(
  list(p = pA, l = "A", n = "roc_auc_per_method", w = W * W1[1] / sum(W1), h = hs[1]),
  list(p = pB, l = "B", n = "rank_by_metric",     w = W * W1[2] / sum(W1), h = hs[1]),
  list(p = pC, l = "C", n = "cd_dataset_level",   w = W,                   h = hs[2]),
  list(p = pD, l = "D", n = "integration_gain",   w = W * W3[1] / sum(W3), h = hs[3]),
  list(p = pE, l = "E", n = "cost_performance",   w = W * W3[2] / sum(W3), h = hs[3]))
for (x in panels) {
  f <- file.path(PANEL, sprintf("Fig3_%s_%s", x$l, x$n))
  ggsave(paste0(f, ".pdf"), x$p, width = x$w, height = x$h, bg = "white", device = cairo_pdf)
  ggsave(paste0(f, ".svg"), x$p, width = x$w, height = x$h, bg = "white", device = svglite::svglite)
}
message("[done] Fig 3 single panels -> ", PANEL)
