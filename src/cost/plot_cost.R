# ==============================================================================
# plot_cost.R  (computational complexity / efficiency)
# Renders the cost figures from process_cost.R output (house style: theme_messi).
#   cost_runtime_memory   A per-method training / feature-selection time (log s)
#                         B per-method peak memory (GiB)
#   cost_tradeoff         median training time vs mean ROC-AUC per method
#   cost_scaling          observational runtime scaling exponents (alpha_n, beta_p)
#   cost_scaling_scatter  runtime vs n per method
#   cost_scaling_table    exponent table with LOO R2 and drop-ROSMAP sensitivity
# Final supplementary figure: results/final_figures/supp/FigS_bulk_cost_memory_scaling.{png,pdf}
# The runtime / cost-performance panel for the MAIN figure is built in
# src/benchmark_stats/figure3_bulk.R (it reads the same cost_plot_data.rds).
#
# Usage: Rscript src/cost/plot_cost.R [--input data/processed/cost/cost_plot_data.rds --outdir results/cost]
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(stringr)
  library(tibble); library(here); library(patchwork); library(readr)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))   # labels, theme_messi, save_final_fig

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, d = NULL) { i <- which(args == flag); if (length(i) == 1 && i < length(args)) args[i + 1] else d }
input  <- get_arg("--input",  here::here("data/processed/cost/cost_plot_data.rds"))
outdir <- get_arg("--outdir", here::here("results/cost"))
SUPP   <- here::here("results/final_figures/supp")
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
D <- readRDS(input)

# SELECT_FEATURE stage = full-data feature-selection fit -> label "Feature selection"
# (process_cost.R still writes "Model selection"; relabelled here for display)
STAGE_COL <- setNames(PAIR_COLORS, c("Training", "Feature selection"))
cost <- D$cost %>% mutate(method = method_factor_y(method),
                          stage = recode(stage, "Model selection" = "Feature selection"),
                          stage = factor(stage, levels = names(STAGE_COL)))
n_ds <- n_distinct(cost$dataset)

# ------------------------------------------------------------- A runtime, B memory
cost_box <- function(var, xlab, logx = FALSE) {
  p <- ggplot(cost, aes(.data[[var]], method, colour = stage)) +
    geom_boxplot(outlier.shape = NA, position = position_dodge(width = 0.75), width = 0.65, linewidth = 0.35) +
    # jitter.width = 0: never move points along the value (x) axis
    geom_point(position = position_jitterdodge(jitter.width = 0, jitter.height = 0.08, dodge.width = 0.75, seed = 1),
               size = 0.5, alpha = 0.45) +
    scale_colour_manual(values = STAGE_COL, name = NULL) +
    labs(x = xlab, y = NULL) + theme_messi() +
    theme(axis.text.y = element_text(colour = CLASS_COLORS[method_class(levels(cost$method))]))
  if (logx) p + scale_x_log10() else p
}
pA <- cost_box("time_s", "Time per task (s, log scale)", TRUE) + labs(title = "Execution time")
pB <- cost_box("mem_gib", "Peak RSS (GiB)") + labs(title = "Peak memory") +
  theme(axis.text.y = element_blank())
rt_mem <- (pA | (pB + theme(legend.position = "none"))) +
  plot_annotation(title = sprintf("Computational cost across %d multimodal datasets", n_ds))
save_plot_both(rt_mem, file.path(outdir, "cost_runtime_memory.png"), width = 7, height = 4.2, dpi = 300)

# ------------------------------------------------------------- tradeoff time vs ROC-AUC
# y = dataset-level mean rank of ROC-AUC (from process_benchmark_stats.R), not a mean ROC-AUC
BS <- readRDS(here::here("data/processed/benchmark_stats/benchmark_stats_plot_data.rds"))
mr <- BS$mean_ranks_ds$roc_auc
tr <- D$cost_perf %>% group_by(method, method_class) %>%
  summarise(time_s = median(time_s), .groups = "drop") %>%
  left_join(tibble(method = names(mr), mean_rank = as.numeric(mr)), by = "method")
pT <- ggplot(tr, aes(time_s, mean_rank, colour = method_class)) +
  geom_point(size = 2.4) +
  ggrepel::geom_text_repel(aes(label = method), size = 2.8, show.legend = FALSE, seed = 1) +
  scale_x_log10() + scale_colour_class() +
  labs(title = "Cost–performance trade-off",
       x = "Median training time per fold (s, log)", y = sprintf("Mean rank (ROC-AUC, 1 = best; %d datasets)", n_ds)) +
  scale_y_reverse() +
  theme_messi()
save_plot_both(pT, file.path(outdir, "cost_tradeoff.png"), width = 5, height = 4, dpi = 300)
save_final_fig(pT + labs(caption = "Dataset-level mean rank of ROC-AUC vs median training time (per-fold task -> median over folds -> median over datasets).\nIntegrAO / MOGONET ran on a different node type.") +
                 theme(plot.caption = element_text(size = 6.5, hjust = 0, colour = "grey30")),
               file.path(SUPP, "FigS_bulk_cost_performance"), width = 6, height = 4.5)

# ------------------------------------------------------------- scaling exponents
sc <- D$scaling %>%
  pivot_longer(c(alpha_n, beta_p), names_to = "term", values_to = "exponent") %>%
  mutate(term = recode(term, alpha_n = "subjects (n)", beta_p = "features (p)"),
         term = factor(term, levels = c("subjects (n)", "features (p)")),
         method = method_factor_y(method))
pS <- ggplot(sc, aes(exponent, method, fill = term)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.7) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.4) +
  scale_fill_manual(values = setNames(PAIR_COLORS, levels(sc$term)), name = NULL) +
  labs(title = "Observed scaling exponents",
       x = "Slope of log(training time) on log(n), log(p)", y = NULL) +
  theme_messi() +
  theme(axis.text.y = element_text(colour = CLASS_COLORS[method_class(levels(sc$method))]))
save_plot_both(pS, file.path(outdir, "cost_scaling.png"), width = 5, height = 4, dpi = 300)

# ------------------------------------------------------------- log-log scaling scatter
sc_pts <- D$cost %>% filter(stage == "Training", time_s > 0, n_sub > 0, p_total > 0) %>%
  mutate(method = factor(method, levels = method_levels(unique(method))))
pSS <- ggplot(sc_pts, aes(n_sub, time_s, colour = log10(p_total))) +
  geom_point(size = 1.2, alpha = 0.85) +
  facet_wrap(~ method, ncol = 4, scales = "free_y") +
  scale_x_log10() + scale_y_log10() +
  scale_colour_viridis_c(option = "viridis", name = expression(log[10]~"features")) +
  labs(title = "Training time vs sample size",
       x = "Subjects n (log scale)", y = "Training time per fold (s, log)") +
  theme_messi(8)
save_plot_both(pSS, file.path(outdir, "cost_scaling_scatter.png"), width = 7, height = 5.5, dpi = 300)

# ------------------------------------------------------------- scaling sensitivity table (image)
tbl <- D$scaling %>%
  mutate(o = match(method, method_levels())) %>% arrange(o) %>%
  transmute(Method = method,
            `alpha(n)` = sprintf("%.2f", alpha_n), `beta(p)` = sprintf("%.2f", beta_p),
            `R2` = sprintf("%.2f", r2), `LOO R2` = sprintf("%.2f", loo_r2),
            `alpha(n) -ROSMAP` = sprintf("%.2f", alpha_n_no_rosmap),
            `beta(p) -ROSMAP` = sprintf("%.2f", beta_p_no_rosmap),
            `LOO R2 -ROSMAP` = sprintf("%.2f", loo_r2_no_rosmap))
tt <- ggpubr::ggtexttable(tbl, rows = NULL, theme = ggpubr::ttheme("minimal", base_size = 8)) |>
  ggpubr::tab_add_footnote(
    "Observational exponents, not algorithmic Big-O. LOO R2 = leave-one-dataset-out; -ROSMAP = ROSMAP dropped.",
    size = 7, face = "italic")
save_plot_both(tt, file.path(outdir, "cost_scaling_table.png"), width = 7, height = 3.2, dpi = 300)

# ------------------------------------------------------------- final supplementary figure
# (patchwork 1.3.0 + ggplot2 4.0: `&` and plot_annotation(theme=) are broken -> style per panel)
cap <- paste("Times are per task (one CV fold) from the Nextflow trace; median over folds per dataset.",
             "IntegrAO / MOGONET ran on different node types.",
             "Exponents from log(time) ~ log(n) + log(p): descriptive, not algorithmic Big-O.", sep = "
")
# strip labels: wrap at 11 chars; single long words (caretMultimodal) are split at the camel-case
# boundary so the 7-column facet strips do not clip them.
wrap_strip <- function(x) sub("^caretMultimodal$", "caret\nMultimodal", stringr::str_wrap(x, 11))
pSS2 <- pSS + facet_wrap(~ method, nrow = 2, scales = "free_y", labeller = as_labeller(wrap_strip)) + labs(title = "Training time vs sample size", caption = cap) +
  scale_x_log10(breaks = c(30, 300)) +
  theme(plot.caption = element_text(size = 6.5, hjust = 0, colour = "grey30"),
        legend.position = "right", strip.text = element_text(size = 7), strip.clip = "off",
        axis.text = element_text(size = 6))
top <- (pA | (pB + theme(legend.position = "none")))
supp <- top / (pS + theme(legend.position = "right")) / pSS2 +
  plot_layout(heights = c(1.15, 0.8, 0.85)) + plot_annotation(tag_levels = "A")
save_final_fig(supp, file.path(SUPP, "FigS_bulk_cost_memory_scaling"), width = 7, height = 8.5)
message("[done] cost figures -> ", outdir)
