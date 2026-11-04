# ==============================================================================
# single_modality_baseline.R  (value of integration) -- PLOTS ONLY
#
# The integration deltas are computed in ONE place:
#   src/benchmark_stats/integration_gain.R -> data/processed/benchmark_stats/tables/integration_gain.csv
# (pooled out-of-fold metrics; single-modality reference = logistic regression on each view;
#  "vs mean modality" = mean over views, "vs best modality" = max over views).
#
# Run AFTER integration_gain.R:
#   Rscript src/benchmark_stats/integration_gain.R
#   Rscript single_modality_baseline.R
# Figures -> results/single_modality_baseline/ (+ final supp copies in results/final_figures/supp/)
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(ggplot2); library(tidyr); library(stringr)
  library(patchwork); library(here); library(readr)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))   # method labels, class colours, save_final_fig

OUT_DIR <- here::here("results/single_modality_baseline")
SUPP    <- here::here("results/final_figures/supp")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

METRICS    <- c("roc_auc", "pr_auc", "f1_score")
METRIC_LAB <- c(roc_auc = "ROC-AUC", pr_auc = "PR-AUC", f1_score = "F1")
REF_LABELS <- c(gain_mean = "vs mean modality", gain = "vs best modality")

gain <- read_csv(here::here("data/processed/benchmark_stats/tables/integration_gain.csv"),
                 show_col_types = FALSE) %>% filter(main_text)
n_ds <- n_distinct(gain$dataset)

dd <- bind_rows(lapply(METRICS, function(m) {
  gain %>% transmute(method = method_name, method_class, dataset, metric = m,
                     value = .data[[m]],
                     gain_mean = .data[[paste0(m, "_gain_mean")]],
                     gain = .data[[paste0(m, "_gain")]])
})) %>%
  pivot_longer(c(gain_mean, gain), names_to = "ref_type", values_to = "delta") %>%
  mutate(ref_type = factor(REF_LABELS[ref_type], levels = unname(REF_LABELS)),
         method_class = factor(method_class, levels = c("Early", "Intermediate", "Late")))
write_csv(dd, file.path(OUT_DIR, "method_delta_long.csv"))
message(sprintf("[single-modality baseline] %d datasets, %d methods (from integration_gain.csv)",
                n_ds, n_distinct(dd$method)))

th <- function(b = 9) theme_messi(b)
REF_COL <- setNames(PAIR_COLORS, unname(REF_LABELS))
ytxt <- function(lv) element_text(colour = CLASS_COLORS[method_class(lv)])

# ---- delta heatmap: dataset x method, facet by reference ---------------------
plot_delta_heatmap <- function(metric) {
  d <- dd %>% filter(metric == !!metric)
  ord <- d %>% group_by(dataset) %>% summarise(v = mean(value), .groups = "drop") %>%
    arrange(v) %>% pull(dataset)
  mord <- method_levels(unique(d$method))
  lim <- max(abs(d$delta), na.rm = TRUE)
  d %>% mutate(dataset = factor(dataset, levels = ord), method = factor(method, levels = mord)) %>%
    ggplot(aes(method, dataset, fill = delta)) +
    geom_tile(color = "white", linewidth = 0.3) +
    facet_wrap(~ ref_type) +
    scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B", midpoint = 0,
                         limits = c(-lim, lim)) +
    labs(x = NULL, y = NULL, fill = bquote(Delta ~ .(METRIC_LAB[[metric]])),
         title = sprintf("%s: multimodal − single-modality logistic regression (%d datasets)",
                         METRIC_LAB[[metric]], n_ds),
         subtitle = "red = multimodal method better than the reference; datasets ordered by mean score") +
    th(8) + theme(axis.text.x = element_text(angle = 45, hjust = 1, colour = CLASS_COLORS[method_class(mord)]),
                  legend.position = "right")
}

# ---- win rate per reference ----------------------------------------------------
plot_winrate <- function(metric) {
  d <- dd %>% filter(metric == !!metric)
  win <- d %>% group_by(method, method_class, ref_type) %>%
    summarise(wins = sum(delta > 0), n = n(), win_rate = wins / n, .groups = "drop")
  win <- win %>% mutate(method = method_factor_y(method))
  ggplot(win, aes(win_rate, method)) +
    geom_vline(xintercept = 0.5, linetype = "dashed", color = "grey50") +
    geom_line(aes(group = method), color = "grey80") +
    geom_point(aes(colour = ref_type), size = 2.4) +
    geom_text(aes(label = sprintf("%d/%d", wins, n), colour = ref_type,
                  hjust = ifelse(ref_type == "vs mean modality", -0.35, 1.35)), size = 2.3, show.legend = FALSE) +
    scale_colour_manual(values = REF_COL, name = NULL) +
    scale_x_continuous(limits = c(-0.12, 1.12), breaks = seq(0, 1, 0.25)) +
    labs(x = sprintf("Fraction of datasets where the method beats the reference (%s)", METRIC_LAB[[metric]]),
         y = NULL, title = sprintf("%s: win rate vs single modality", METRIC_LAB[[metric]])) +
    th() + theme(axis.text.y = ytxt(levels(win$method)))
}

# ---- mean delta per method ------------------------------------------------------
plot_avg_delta <- function(metric) {
  s <- dd %>% filter(metric == !!metric) %>% group_by(method, method_class, ref_type) %>%
    summarise(med = median(delta), lo = quantile(delta, .25), hi = quantile(delta, .75), .groups = "drop")
  s %>% mutate(method = method_factor_y(method)) %>%
    ggplot(aes(med, method, colour = ref_type)) +
    geom_vline(xintercept = 0, color = "grey50", linetype = "dashed") +
    geom_errorbar(aes(xmin = lo, xmax = hi), width = 0, orientation = "y",
                  position = position_dodge(width = 0.5)) +
    geom_point(size = 2, position = position_dodge(width = 0.5)) +
    scale_colour_manual(values = REF_COL, name = NULL) +
    labs(x = sprintf("Median Δ %s (bar = IQR over datasets)", METRIC_LAB[[metric]]), y = NULL,
         title = sprintf("%s: integration gain", METRIC_LAB[[metric]])) +
    th() + theme(axis.text.y = ytxt(rev(method_levels(unique(s$method)))))
}

for (m in METRICS) {
  save_plot_both(plot_delta_heatmap(m), file.path(OUT_DIR, sprintf("delta_heatmap_%s.png", m)), width = 9, height = 6.5)
  save_plot_both(plot_winrate(m),       file.path(OUT_DIR, sprintf("winrate_rank_%s.png", m)), width = 7, height = 4.5)
  save_plot_both(plot_avg_delta(m),     file.path(OUT_DIR, sprintf("avg_delta_bar_%s.png", m)), width = 7, height = 4.5)
}

# ---- final supplementary figure: single-modality detail (ROC-AUC) -------------
supp <- cowplot::plot_grid(plot_winrate("roc_auc") + labs(title = "Win rate vs single modality (ROC-AUC)"),
                           plot_delta_heatmap("roc_auc"), ncol = 1, rel_heights = c(1, 1.9),
                           labels = c("B", "C"), label_size = 14, label_fontface = "bold") +
  theme(plot.background = element_rect(fill = "white", colour = NA))
save_final_fig(supp, file.path(SUPP, "FigS_bulk_single_modality_detail"), width = 7, height = 9.5)
message("[done] single-modality baseline figures -> ", OUT_DIR)
