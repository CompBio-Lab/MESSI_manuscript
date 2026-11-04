# figure6_simulation.R - main Figure 6 (simulation) + its supplementary figures.
# Reads ONLY the derived tables written by 01_compute_metrics.R and 03_sim_cost.R (same
# computation for every panel), house style from src/common_helpers/theme_messi.R.
#   Rscript src/simulated_brief/01_compute_metrics.R   # prediction + recovery tables
#   Rscript src/simulated_brief/03_sim_cost.R          # cost tables
#   Rscript src/simulated_brief/figure6_simulation.R   # figures
# Outputs:
#   results/final_figures/main/Fig6_simulation.{png,pdf,rds}
#   results/final_figures/supp/FigS_sim_prediction_by_rho.{png,pdf,rds}
#   results/final_figures/supp/FigS_sim_recovery_by_rho.{png,pdf,rds}
#   results/final_figures/supp/FigS_sim_recovery_by_view.{png,pdf,rds}
#   results/final_figures/supp/FigS_sim_cost.{png,pdf,rds}
#   + copies of the plot data in results/simulated_brief/data_derived/fig6_*.csv
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(ggplot2); library(patchwork); library(here)
})
source(here::here("src/common_helpers/method_labels.R"))
source(here::here("src/common_helpers/theme_messi.R"))
source(here::here("src/simulated_brief/theme_simulation.R"))   # SCEN_LABS, scen_lab
CLASS_COLORS <- c(Early = "#2B6A9F", Intermediate = "#D68A2A", Late = "#3C8C63")  # = theme_messi

DER  <- here::here("results/simulated_brief/data_derived")
MAIN <- here::here("results/final_figures/main")
SUPP <- here::here("results/final_figures/supp")
dir.create(MAIN, recursive = TRUE, showWarnings = FALSE); dir.create(SUPP, recursive = TRUE, showWarnings = FALSE)

perf <- read_csv(file.path(DER, "prediction_metrics_by_rho.csv"), show_col_types = FALSE)
rec  <- read_csv(file.path(DER, "recovery_by_rho.csv"), show_col_types = FALSE)
recV <- read_csv(file.path(DER, "recovery_by_view.csv"), show_col_types = FALSE)
summ <- read_csv(file.path(DER, "metrics_rho_summary.csv"), show_col_types = FALSE)
cost <- read_csv(file.path(DER, "cost_by_configuration.csv"), show_col_types = FALSE)
covc <- read_csv(file.path(DER, "coverage_checks.csv"), show_col_types = FALSE)
n_phys <- as.integer(covc$value[covc$check == "n_physical_datasets"])
n_cell <- as.integer(covc$value[covc$check == "n_logical_cells"])

# ---- shared encodings: colour = integration class (one meaning), shape = method -------------
LV <- method_levels(unique(perf$method))
MCOL <- setNames(CLASS_COLORS[method_class(LV)], LV)
MSHP <- setNames(c(16, 17, 15, 18, 16, 1, 17, 2, 15, 18, 3, 16, 17)[seq_along(LV)], LV)
fac_m <- function(d) mutate(d, method = factor(method, levels = LV))
fac_s <- function(d) mutate(d, scenario = factor(scen_lab(scenario), levels = unname(SCEN_LABS)))
ref05 <- geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.4)
scale_m <- list(scale_colour_manual(values = MCOL, name = NULL, drop = FALSE),
                scale_shape_manual(values = MSHP, name = NULL, drop = FALSE))
legend_m <- guides(colour = guide_legend(nrow = 3, byrow = TRUE, override.aes = list(size = 2.2, linewidth = 0.6)),
                   shape = guide_legend(nrow = 3, byrow = TRUE))

line_panel <- function(d, y, ylab, xbreaks = 0:3) {
  ggplot(fac_s(fac_m(d)), aes(dt, .data[[y]], colour = method, shape = method, group = method)) +
    ref05 +
    geom_line(linewidth = 0.45, alpha = 0.85, na.rm = TRUE) +
    geom_point(size = 1.5, na.rm = TRUE) +
    scale_m + legend_m +
    scale_x_continuous(breaks = xbreaks, expand = expansion(add = 0.25)) +
    scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, .25)) +
    labs(x = expression("Class shift " * delta), y = ylab) +
    theme_messi()
}

# ============================ MAIN FIGURE 6 (heatmaps) ============
# Rows = methods (method_levels order, labels coloured by class); columns = delta nested in scenario.
# Same diverging scale centred at 0.5 in both panels. Values = metric computed per rho, then
# averaged over rho (equal weights). S1/delta=0 is the S0/delta=0 dataset (generator reuse).
hm_data <- function(d, y) d %>%
  transmute(method = method_factor_y(method), dt = factor(dt),
            scenario = factor(scen_lab(scenario), levels = unname(SCEN_LABS)),
            value = .data[[y]],
            lab = ifelse(is.na(value), "NA", sub("^(-?)0[.]", "\\1.",sprintf("%.2f", value))))
heat_panel <- function(d, title, tag) {
  ggplot(d, aes(dt, method, fill = value)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    geom_text(aes(label = lab, colour = !is.na(value) & abs(value - 0.5) > 0.3), size = 6.5 / .pt,   # 6.5 pt floor for dense heatmap cells
              show.legend = FALSE) +
    scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "black"), guide = "none") +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0.5,
                         limits = c(0, 1), na.value = "grey80", name = "AUC (0.5 = chance)",
                         guide = guide_colourbar(barwidth = unit(45, "mm"), barheight = unit(2.4, "mm"),
                                                 title.position = "left", title.vjust = 0.9)) +
    facet_grid(. ~ scenario, scales = "free_x", space = "free_x") +
    scale_x_discrete(expand = c(0, 0)) + scale_y_discrete(expand = c(0, 0)) +
    labs(x = expression("Class shift " * delta), y = NULL, title = title, tag = tag) +
    theme_messi() +
    theme(panel.grid = element_blank(), panel.spacing.x = unit(1.5, "mm"),
          axis.text.y = element_text(colour = CLASS_COLORS[method_class(levels(d$method))]))
}
hA <- hm_data(summ, "roc_auc")
hB <- hm_data(filter(summ, dt > 0), "recovery_auroc")
write_csv(hA, file.path(DER, "fig6_panelA_prediction_heatmap.csv"))
write_csv(hB, file.path(DER, "fig6_panelB_recovery_heatmap.csv"))
# ---- takeaway callouts: thin dark outlines on the cells + one bold line per panel ----
CALL_COL <- "grey15"
cell_box <- function(d, methods, dts, scen, x_offset) {
  lv <- levels(d$method)
  expand.grid(method = methods, dt = dts, stringsAsFactors = FALSE) %>%
    mutate(y = match(method, lv), x = dt - x_offset,
           scenario = factor(scen_lab(scen), levels = unname(SCEN_LABS)))
}
box_layer <- function(b, contiguous = FALSE) {
  if (contiguous) b <- b %>% group_by(scenario) %>%
      summarise(xmin = min(x) - .5, xmax = max(x) + .5, ymin = min(y) - .5, ymax = max(y) + .5, .groups = "drop")
  else b <- b %>% mutate(xmin = x - .5, xmax = x + .5, ymin = y - .5, ymax = y + .5)
  geom_rect(data = b, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), inherit.aes = FALSE,
            fill = NA, colour = CALL_COL, linewidth = 0.75)
}
bA1 <- cell_box(hA, c("IntegrAO", "MLP", "XGBoost"), 3, "S1_nonlinear", -1)            # dt 0..3 -> x 1..4
bA2 <- cell_box(hA, c("DIABLO-F", "DIABLO-N", "RGCCA-F"), 1:3, "S2_batch", -1)
bB1 <- cell_box(hB, c("MOFA+", "DIABLO-F", "RGCCA-F"), 3, "S1_nonlinear", 0)           # dt 1..3 -> x 1..3
pA <- heat_panel(hA, "Prediction (pooled out-of-fold ROC-AUC)", "A") +
  box_layer(bA1) + box_layer(bA2, contiguous = TRUE)
pB <- heat_panel(hB, "Feature recovery (within-view AUROC)", "B") +
  box_layer(bB1)
H6 <- c(A = 4.0, B = 3.95, legend = 0.4)
stopifnot(sum(H6) <= 8.5)
leg6 <- wrap_elements(full = cowplot::get_plot_component(
  pA + theme(legend.position = "bottom"), "guide-box-bottom", return_all = TRUE))
noleg <- theme(legend.position = "none")
fig6 <- (pA + noleg) / (pB + noleg) / leg6 + plot_layout(heights = H6)
save_main(fig6, file.path(MAIN, "Fig6_simulation"), height = sum(H6))
# ---- single-panel exports (no tag) at their in-figure size ----
PAN <- here::here("results/final_figures/panels")
dir.create(PAN, recursive = TRUE, showWarnings = FALSE)
save_panel <- function(p, name, h, w = 7) for (ext in c("pdf", "svg"))
  ggsave(file.path(PAN, paste0(name, ".", ext)), p, width = w, height = h, bg = "white",
         device = if (ext == "svg") svglite::svglite else cairo_pdf)
save_panel(pA + noleg + labs(tag = NULL), "Fig6_A_prediction_heatmap", H6[["A"]])
save_panel(pB + noleg + labs(tag = NULL), "Fig6_B_recovery_heatmap", H6[["B"]])
save_panel(leg6, "Fig6_legend", H6[["legend"]])

# ---- SUPP: the former line plots (mean over rho), one per metric ----
lA <- line_panel(summ, "roc_auc", "ROC-AUC (pooled OOF)") + facet_wrap(~scenario, nrow = 1) +
  labs(title = "Prediction vs signal strength (mean over \u03C1)")
lB <- line_panel(filter(summ, dt > 0), "recovery_auroc", "Recovery AUROC", xbreaks = 1:3) +
  scale_x_continuous(breaks = 1:3, limits = c(0.75, 3.25)) + facet_wrap(~scenario, nrow = 1) +
  labs(title = "Feature recovery vs signal strength (mean over \u03C1)")
for (x in list(list(lA, "FigS_sim_prediction_lines"), list(lB, "FigS_sim_recovery_lines"))) {
  ggsave(file.path(SUPP, paste0(x[[2]], ".png")), x[[1]], width = 7, height = 4.2, dpi = 300, bg = "white")
  ggsave(file.path(SUPP, paste0(x[[2]], ".pdf")), x[[1]], width = 7, height = 4.2, bg = "white", device = cairo_pdf)
  saveRDS(x[[1]], file.path(SUPP, paste0(x[[2]], ".rds")))
}
write_csv(summ, file.path(DER, "fig6_panelAB_rho_mean.csv"))

# ============================ SUPP: per-rho expanded ============================
RHO_LAB <- label_bquote(rows = rho == .(rho))
sA <- line_panel(perf, "roc_auc", "ROC-AUC (pooled OOF)") +
  facet_grid(rho ~ scenario, labeller = RHO_LAB) +
  labs(title = bquote(bold("Prediction per " * rho * " (" * .(n_phys) * " datasets, " * .(n_cell) * " scenario cells)")))
save_main(sA + labs(tag = "A") + theme(plot.tag = element_text(face = "bold", size = 14)) + theme(legend.position = "bottom"), file.path(SUPP, "FigS_sim_prediction_by_rho"), height = 7)
sB <- line_panel(filter(rec, dt > 0), "recovery_auroc", "Recovery AUROC", xbreaks = 1:3) +
  scale_x_continuous(breaks = 1:3, limits = c(0.75, 3.25)) +
  facet_grid(rho ~ scenario, labeller = RHO_LAB) +
  labs(title = expression(bold("Feature recovery per " * rho * " (mean of 3 views)")))
save_main(sB + labs(tag = "B") + theme(plot.tag = element_text(face = "bold", size = 14)) + theme(legend.position = "bottom"), file.path(SUPP, "FigS_sim_recovery_by_rho"), height = 7)

# ---- SUPP: recovery per view at delta = 3 (mean over rho) - shows S3 noisy omic3 + the
#      single-component methods (MOFA+, RGCCA-N) loading on the background block
rv <- recV %>% filter(dt == 3) %>% group_by(method, scenario, view) %>%
  summarise(value = mean(recovery_auroc), .groups = "drop") %>%
  mutate(scenario = factor(scen_lab(scenario), levels = unname(SCEN_LABS)),
         method = method_factor_y(method), lab = sprintf("%.2f", value))
write_csv(rv, file.path(DER, "figS_recovery_by_view_dt3.csv"))
sC <- ggplot(rv, aes(view, method, fill = value)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = lab, colour = abs(value - 0.5) > 0.32), size = 2.3, show.legend = FALSE) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "black"), guide = "none") +
  scale_fill_gradient2(low = "#2166AC", mid = "grey97", high = "#B2182B", midpoint = 0.5,
                       limits = c(0, 1), name = "Recovery AUROC",
                       guide = guide_colourbar(barwidth = unit(35, "mm"), barheight = unit(2.5, "mm"),
                                               title.position = "top", title.hjust = 0.5)) +
  facet_wrap(~scenario, nrow = 1) +
  labs(x = NULL, y = NULL, title = expression(bold("Recovery per view (" * delta * " = 3, mean over " * rho * ")"))) +
  theme_messi() + theme(panel.grid = element_blank(),
                        axis.text.y = element_text(colour = CLASS_COLORS[method_class(levels(rv$method))]))
save_main(sC, file.path(SUPP, "FigS_sim_recovery_by_view"), height = 4)

# ============================ SUPP: simulation cost ============================
cs <- cost %>% mutate(method = method_factor_y(method),
                      stage = factor(stage, levels = c("Training", "Feature selection")))
cost_panel <- function(var, xlab, logx) {
  g <- ggplot(cs, aes(.data[[var]], method, colour = stage)) +
    geom_boxplot(aes(fill = stage), outlier.size = 0.4, linewidth = 0.3, alpha = 0.25,
                 position = position_dodge(width = 0.75), width = 0.65) +
    scale_colour_manual(values = setNames(PAIR_COLORS, levels(cs$stage)), name = NULL) +
    scale_fill_manual(values = setNames(PAIR_COLORS, levels(cs$stage)), name = NULL) +
    labs(x = xlab, y = NULL) + theme_messi() +
    theme(axis.text.y = element_text(colour = CLASS_COLORS[method_class(levels(cs$method))]))
  if (logx) g + scale_x_log10() else g
}
cA <- cost_panel("time_s", "Task wall time (s, log scale)", TRUE) + labs(title = "Runtime")
cB <- cost_panel("mem_gib", "Peak RSS (GiB)", FALSE) + labs(title = "Memory") +
  theme(axis.text.y = element_blank())
cB <- cB + guides(colour = "none", fill = "none")
figC <- (cA | cB) +
  plot_annotation(tag_levels = "A")
save_main(figC, file.path(SUPP, "FigS_sim_cost"), height = 4.6)
message("[done] Fig 6 + supplementary simulation figures")
