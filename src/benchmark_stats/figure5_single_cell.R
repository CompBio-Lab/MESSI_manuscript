# ==============================================================================
# figure5_single_cell.R — assemble main Figure 5 (single-cell benchmark) + sc supp figures.
# Run AFTER src/benchmark_stats/figure_sc_main.R and src/biology_validation/sc_biology.R.
#   A  study design (pseudobulk construction for the 3 datasets)       — image
#   B  pooled out-of-fold ROC-AUC heatmap, methods x datasets          — figure_sc_pooled_roc_heatmap.rds
#   C  gain over single-view Logistic: bar = vs best view, dot = vs mean view (rows shared with B)
#                                                                      — figure_sc_gain_bars.rds
#   D  rank bump chart across the 3 datasets                           — figure_sc_rank_bump_panel.rds
#   E  single-cell vs bulk mean rank                                   — figure_sc_rank_vs_bulk_panel.rds
# (cost -> supplementary FigS_sc_cost_per_dataset / _per_fold; per-fold ROC/PR -> supp;
#  HTX known-gene panel -> Fig 4.)
# Design image:
#   results/sc_new/sc_design_concept.png (tracked; hand-made, not generated).
# Outputs: results/final_figures/main/Fig5_single_cell.{png,pdf,rds}
#          results/final_figures/panels/Fig5_<letter>_<name>.{pdf,svg}  (no tags, size as placed)
#          results/final_figures/supp/FigS_sc_*.{png,pdf}
# ==============================================================================
suppressPackageStartupMessages({ library(ggplot2); library(patchwork); library(here); library(png); library(grid) })
source(here::here("src/common_helpers/theme_messi.R"))
SC <- here::here("results/sc_new")
FF <- here::here("results/final_figures")
for (d in c("main", "supp", "panels")) dir.create(file.path(FF, d), recursive = TRUE, showWarnings = FALSE)

# ---- design image ---------------------------------------------------------------
md5 <- function(f) unname(tools::md5sum(f))
design_png <- file.path(SC, "sc_design_concept.png")
if (!file.exists(design_png)) stop("single-cell design image not found: results/sc_new/sc_design_concept.png")
dd_bulk <- here::here("data_design_figs/join_bulk_multimodal_design.png")
if (file.exists(dd_bulk) && md5(design_png) == md5(dd_bulk)) stop("design image is the BULK design, not the single-cell one: ", design_png)
message("design image: ", design_png)
img <- png::readPNG(design_png)
# crop the transparent / white margin around the drawing so it can be printed larger (layout only)
local({
  g <- if (length(dim(img)) == 3) rowMeans(img[, , 1:3, drop = FALSE], dims = 2) else img
  ink <- if (length(dim(img)) == 3 && dim(img)[3] == 4) img[, , 4] > 0.1 & g < 0.95 else g < 0.95
  r <- range(which(rowSums(ink) > 0)); c <- range(which(colSums(ink) > 0)); pad <- 20
  r <- c(max(1, r[1] - pad), min(nrow(ink), r[2] + pad)); c <- c(max(1, c[1] - pad), min(ncol(ink), c[2] + pad))
  img <<- img[r[1]:r[2], c[1]:c[2], , drop = FALSE]
})
pA <- wrap_elements(full = rasterGrob(img, interpolate = TRUE)) + theme(plot.margin = margin(2, 2, 2, 2))

pB <- readRDS(file.path(SC, "figure_sc_pooled_roc_heatmap.rds"))
pC <- readRDS(file.path(SC, "figure_sc_gain_bars.rds"))
pD <- readRDS(file.path(SC, "figure_sc_rank_bump_panel.rds"))
pE <- readRDS(file.path(SC, "figure_sc_rank_vs_bulk_panel.rds"))

# ---- layout: 7 in wide, 8.5 in tall --------------------------------------------
W <- MAIN_WIDTH_IN; H <- 8.5
hA <- 2.85; hBC <- 3.45; hDE <- 2.2          # printed row heights (in); rows are wrapped so these are exact
pA_h <- hA; pBC_h <- hBC; pDE_h <- hDE
wB <- 0.42; wD <- 0.5
tt <- theme(plot.tag = element_text(face = "bold", size = 14))
tag <- function(p, t) p + labs(tag = t) + tt
# B + C share ONE legend row directly under them (colourbar + bar/dot key), instead of two
# floating legends. E's x-axis title is freed from D's two-line category labels.
rowBC <- wrap_elements(full = (tag(pB, "B") + tag(pC, "C") +
                               plot_layout(widths = c(wB, 1 - wB), guides = "collect") +
                               plot_annotation(theme = theme(legend.position = "bottom", legend.box = "horizontal",
                                 legend.margin = margin(0, 6, 0, 6), legend.box.spacing = unit(1, "mm")))))
rowDE <- wrap_elements(full = tag(pD, "D") + free(tag(pE, "E"), type = "label", side = "b") +
                         plot_layout(widths = c(wD, 1 - wD)))
fig <- tag(pA, "A") / rowBC / rowDE +
  plot_layout(heights = c(hA, hBC, hDE))
save_main(fig, file.path(FF, "main", "Fig5_single_cell"), height = H, width = W)
message("[done] Fig5 -> ", file.path(FF, "main", "Fig5_single_cell.png"))

# ---- single-panel exports (no tag; size as placed) ----------------------------------
save_panel <- function(p, name, w, h) {
  base <- file.path(FF, "panels", name)
  ggsave(paste0(base, ".pdf"), p, width = w, height = h, bg = "white", device = cairo_pdf)
  ggsave(paste0(base, ".svg"), p, width = w, height = h, bg = "white", device = svglite::svglite)
}
save_panel(pA, "Fig5_A_design", W, pA_h)
save_panel(pB, "Fig5_B_pooled_roc_heatmap", W * wB, pBC_h)
save_panel(pC, "Fig5_C_integration_gain", W * (1 - wB), pBC_h)
save_panel(pD, "Fig5_D_rank_bump", W * wD, pDE_h)
save_panel(pE, "Fig5_E_rank_vs_bulk", W * (1 - wD), pDE_h)

# ---- supplementary figures (copies of the standalone sc_new versions, house style) ---
supp <- c(figure_sc_biology_covid = "FigS_sc_biology_covid",
          figure_sc_biology_full  = "FigS_sc_biology_full",
          figure_sc_perf_detail   = "FigS_sc_performance_detail",
          figure_sc_performance   = "FigS_sc_performance_per_fold",
          figure_sc_cost          = "FigS_sc_cost_per_fold",
          figure_sc_cost_per_dataset = "FigS_sc_cost_per_dataset")
dims <- list(FigS_sc_biology_covid = c(7, 3.6), FigS_sc_biology_full = c(7, 4.8),
             FigS_sc_performance_detail = c(7, 5.6), FigS_sc_performance_per_fold = c(7, 3.9),
             FigS_sc_cost_per_fold = c(7, 3.6), FigS_sc_cost_per_dataset = c(7, 3.6))
for (k in names(supp)) {
  p <- readRDS(file.path(SC, paste0(k, ".rds"))); o <- supp[[k]]; d <- dims[[o]]
  tg <- c(FigS_sc_cost_per_dataset = "B")[o]
  if (!is.na(tg)) p <- p + labs(tag = unname(tg)) + theme(plot.tag = element_text(face = "bold", size = 14))
  ggsave(file.path(FF, "supp", paste0(o, ".png")), p, width = d[1], height = d[2], dpi = 300, bg = "white")
  ggsave(file.path(FF, "supp", paste0(o, ".pdf")), p, width = d[1], height = d[2], bg = "white", device = cairo_pdf)
}
message("[done] sc supplementary figures -> ", file.path(FF, "supp"))
