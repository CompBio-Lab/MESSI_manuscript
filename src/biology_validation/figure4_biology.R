# ==============================================================================
# figure4_biology.R  -- assemble main Figure 4 + biology supplementary figures
#
# Reads the tables written by recall_at_k.R (run that first) and the pooled predictive metrics
# of the bulk benchmark. No model is refit. House style: src/common_helpers/theme_messi.R.
#   A  credibility of known-cancer-gene recovery across cancer datasets (Logistic = only baseline)
#   B  cross-disease: autism (GSE38609) and DKD (imaging_omics) -- ONE dataset each, so per-method
#      per-dataset Mann-Whitney tests, BH-corrected across the methods shown
#   C  prediction vs biology: method-level mean predictive ROC-AUC (pooled CV predictions) vs mean
#      known-gene AUROC on the same cancer datasets
# Supplementary: full credibility + cross-disease incl. RF/XGBoost, per-dataset AUROC heatmap,
# top-100 enrichment (Fisher OR), MOMIX <-> TCGA top-100 concordance.
# Run: Rscript src/biology_validation/figure4_biology.R
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(ggplot2)
  library(patchwork); library(ggrepel); library(here)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/common_helpers/method_labels.R"))
source(here::here("src/common_helpers/theme_messi.R"))   # theme_messi, CLASS_COLORS, SIG_COLORS, sig_label, method_factor_y, save_main

TAB  <- here::here("results/biology_validation/tables")
OUT  <- here::here("results/biology_validation")
MAIN <- here::here("results/final_figures/main"); SUPP <- here::here("results/final_figures/supp")

SPARSE_BASELINES <- c("Random Forest", "XGBoost")   # n_estimators = 10 -> median 98.5% zero importances
BS <- 9                                              # theme_messi base size
TXT <- BS / ggplot2::.pt * 0.85                      # geom_text size matching ~0.85 x base
th <- theme_messi(BS)
# Method names coloured by integration class. theme_messi's scale_y_method()/theme_method_axis() rely on
# ggtext::element_markdown, which does not render with ggplot2 4.0.0 + ggtext 0.1.2 in this R install (raw
# <span> tags are printed). Local workaround: keep the axis text for spacing but make it transparent, and
# draw the names with one geom_text layer per class (fixed colour -> no clash with the panel's colour scale).
# `d` needs columns `method` (label) and `y` (position, factor or numeric) plus any facet columns.
class_axis <- function(d, size = BS * 0.95 / ggplot2::.pt) {
  d$cls <- method_class(as.character(d$label))
  c(lapply(names(CLASS_COLORS), function(cl) {
      dd <- d[d$cls %in% cl, , drop = FALSE]
      if (!nrow(dd)) return(NULL)
      geom_text(data = dd, aes(x = -Inf, y = y, label = paste0(label, "  ")), colour = CLASS_COLORS[[cl]],
                hjust = 1, size = size, inherit.aes = FALSE)
    }),
    list(theme(axis.text.y = element_text(colour = "transparent"))))
}
callout <- function(...) annotate("text", fontface = "bold", colour = "grey25", size = 8 / ggplot2::.pt, lineheight = 0.9, ...)
callout_arrow <- function(..., curvature = 0.2) annotate("curve", colour = "grey35", linewidth = 0.35, curvature = curvature,
                                        arrow = grid::arrow(length = unit(1.4, "mm"), type = "closed"), ...)
sig_scale <- function(aes = c("colour", "fill"), labels = c(significant = "above chance (BH q < 0.05)",
                                                           `not significant` = "not above chance"))
  scale_colour_manual(values = SIG_COLORS, labels = labels, name = NULL, aesthetics = aes, drop = FALSE)

# ------------------------------------------------------------------ inputs
disc <- read_csv(file.path(TAB, "known_gene_discrimination.csv"), show_col_types = FALSE) %>%
  mutate(method = method_label(method))
N_CANCER <- n_distinct(disc$dataset_name[disc$disease == "cancer"])
FAMILY <- function(m) ifelse(m %in% c("Logistic", "XGBoost", "Random Forest"), "Baseline", "Multimodal integration")

# BH across the methods shown in the main figure (RF/XGB are not in that family; they keep the raw p).
main_bh <- function(m, p) { q <- p; i <- !m %in% SPARSE_BASELINES; q[i] <- p.adjust(p[i], "BH"); q }
cred <- disc %>% filter(disease == "cancer") %>% group_by(method) %>%
  summarise(median_auroc = median(auroc), mean_auroc = mean(auroc),
            p_vs_chance = suppressWarnings(wilcox.test(auroc, mu = 0.5, alternative = "greater")$p.value),
            n_above = sum(auroc > 0.5), n = n(), .groups = "drop") %>%
  mutate(q_vs_chance = main_bh(method, p_vs_chance), credible = q_vs_chance < 0.05, sig = sig_label(credible),
         family = factor(FAMILY(method), levels = c("Baseline", "Multimodal integration")),
         lab = ifelse(credible, sprintf("q=%.2g *", q_vs_chance), sprintf("q=%.2g", q_vs_chance)))
write_csv(cred %>% select(-sig), file.path(TAB, "auroc_credibility_cancer.csv"))

# ------------------------------------------------------------------ A: credibility (look of auroc_credibility_main)
plot_credibility <- function(drop = character(0), title) {
  cr <- cred %>% filter(!method %in% drop) %>% mutate(method = method_factor_y(method))
  dcan <- disc %>% filter(disease == "cancer", !method %in% drop) %>%
    left_join(cred %>% dplyr::select(method, sig, family), by = "method") %>%
    mutate(method = method_factor_y(method))
  xmax <- max(dcan$auroc, na.rm = TRUE)
  ggplot(dcan, aes(auroc, method)) +
    geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
    geom_boxplot(aes(colour = sig), outlier.shape = NA, fill = NA, width = 0.62, linewidth = 0.45) +
    geom_point(aes(colour = sig), size = 1, alpha = 0.55,
               position = position_jitter(height = 0.16, width = 0, seed = 1)) +
    stat_summary(aes(fill = sig), fun = median, geom = "point",
                 shape = 21, size = 2.4, colour = "white", stroke = 0.5) +
    # p-values printed just outside the right panel border
    geom_text(data = cr %>% mutate(xlab_pos = xmax + 0.02),
              aes(x = xlab_pos, y = method, label = lab, colour = sig),
              hjust = 0, size = TXT, show.legend = FALSE) +
    # Baseline row(s) separated from integration methods by facet; strip labels blank (too short to read)
    facet_grid(family ~ ., scales = "free_y", space = "free_y") +
    sig_scale() +
    guides(colour = guide_legend(ncol = 1), fill = guide_legend(ncol = 1)) +
    coord_cartesian(xlim = c(min(dcan$auroc, na.rm = TRUE) - 0.01, xmax + 0.01), expand = FALSE, clip = "off") +
    labs(title = title, x = "known-gene AUROC (0.5 = chance)", y = NULL) +
    th + class_axis(distinct(dcan, method, family) %>% mutate(label = as.character(method), y = method)) +
    theme(panel.grid.major.y = element_blank(), strip.text = element_blank(),
               panel.spacing.y = unit(4, "pt"), plot.margin = margin(4, 52, 4, 4))
}
pA <- plot_credibility(SPARSE_BASELINES, title = sprintf("Known cancer genes, %d datasets", N_CANCER))

# ------------------------------------------------------------------ B: cross-disease, honest
DIS_LAB <- c(autism = "Autism (GSE38609; SFARI)", DKD = "DKD (imaging_omics; Open Targets)")
STATUS_FILL <- c(`FDR < 0.05` = SIG_COLORS[["significant"]], `nominal p < 0.05 only` = "white",
                 `not significant` = SIG_COLORS[["not significant"]])
STATUS_COL  <- c(`FDR < 0.05` = SIG_COLORS[["significant"]], `nominal p < 0.05 only` = SIG_COLORS[["significant"]],
                 `not significant` = SIG_COLORS[["not significant"]])
cross_tab <- function(drop) disc %>% filter(disease %in% names(DIS_LAB), !method %in% drop) %>%
  group_by(disease) %>% mutate(fdr = p.adjust(auc_p, "BH")) %>% ungroup() %>%
  mutate(status = case_when(fdr < 0.05 ~ "FDR < 0.05", auc_p < 0.05 ~ "nominal p < 0.05 only", TRUE ~ "not significant"),
         status = factor(status, levels = names(STATUS_FILL)),
         dlab = factor(DIS_LAB[disease], levels = DIS_LAB))
plot_cross <- function(drop, title) {
  xd <- cross_tab(drop) %>% mutate(method = method_factor_y(method),
                                   plab = ifelse(auc_p < 0.001, "p<0.001", sprintf("p=%.2g", auc_p)))
  ggplot(xd, aes(auroc, method)) +
    geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
    geom_segment(aes(x = 0.5, xend = auroc, yend = method), colour = "grey75", linewidth = 0.4) +
    geom_point(aes(fill = status, colour = status), shape = 21, size = 2.3, stroke = 0.8) +
    geom_text(aes(x = pmax(auroc, 0.5) + 0.006, label = plab), hjust = 0, size = TXT * 0.95, colour = "grey30") +
    scale_fill_manual(values = STATUS_FILL, name = NULL, drop = FALSE) +
    scale_colour_manual(values = STATUS_COL, name = NULL, drop = FALSE) +
    scale_x_continuous(expand = expansion(mult = c(0.04, 0.30))) +
    facet_wrap(~dlab, nrow = 1) +
    labs(title = title, x = "known-gene AUROC (0.5 = chance)", y = NULL) +
    th + class_axis(distinct(xd, method, dlab) %>% filter(dlab == levels(dlab)[1]) %>% mutate(label = as.character(method), y = method)) +
    coord_cartesian(clip = "off") + theme(panel.grid.major.y = element_blank())
}
pB <- plot_cross(SPARSE_BASELINES, title = "Other diseases: one dataset each")
pB_full <- plot_cross(character(0), title = "Other diseases, all methods")
save_plot_both(pB_full + labs(caption = paste0(
  "Random Forest / XGBoost give non-zero importance to <1% of genes here; the Random Forest DKD p (~1e-5 at AUROC 0.51)\n",
  "is a tie artefact (Mann-Whitney variance collapses when >99% of scores are tied at 0), not biological signal.")) +
    theme(plot.caption = element_text(hjust = 0, size = 7, colour = "grey30")),
  file.path(OUT, "auroc_cross_disease.png"), width = 7, height = 3.8, dpi = 300)

# ------------------------------------------------------------------ C: prediction vs biology
pm <- read_csv(here::here("data/processed/benchmark_stats/tables/pooled_metrics.csv"), show_col_types = FALSE) %>%
  filter(!str_detect(method_name, "ncomp-1$")) %>%          # DIABLO/RGCCA: ncomp-2 variants (feature files use ncomp 1+2)
  mutate(method = method_label(method_name)) %>% dplyr::select(method, dataset_name = dataset, roc_auc)
stopifnot(!any(duplicated(pm[c("method", "dataset_name")])))
pvb_all <- disc %>% filter(disease == "cancer") %>% inner_join(pm, by = c("method", "dataset_name"))
stopifnot(n_distinct(pvb_all$dataset_name) == N_CANCER, n_distinct(pvb_all$method) == n_distinct(disc$method))
pvb_stats <- function(drop) {
  d <- pvb_all %>% filter(!method %in% drop)
  ms <- d %>% group_by(method) %>%
    summarise(pred_mean = mean(roc_auc), pred_se = sd(roc_auc) / sqrt(n()),
              bio_mean = mean(auroc), bio_se = sd(auroc) / sqrt(n()), n_ds = n(), .groups = "drop") %>%
    left_join(cred %>% dplyr::select(method, credible, p_vs_chance), by = "method") %>%
    mutate(class = method_class(method))
  across_s <- suppressWarnings(cor.test(ms$pred_mean, ms$bio_mean, method = "spearman"))
  across_p <- cor.test(ms$pred_mean, ms$bio_mean, method = "pearson")
  wd <- d %>% group_by(dataset_name) %>%
    summarise(rho = suppressWarnings(cor(roc_auc, auroc, method = "spearman")), .groups = "drop")
  wd_test <- suppressWarnings(wilcox.test(wd$rho, mu = 0))
  wide <- function(v) d %>% dplyr::select(method, dataset_name, all_of(v)) %>%
    pivot_wider(names_from = method, values_from = all_of(v)) %>% dplyr::select(-dataset_name) %>% as.matrix()
  list(ms = ms, wd = wd,
       stats = tibble(set = ifelse(length(drop), "without RF/XGBoost", "all methods"),
                      n_methods = nrow(ms), n_datasets = n_distinct(d$dataset_name),
                      across_spearman = unname(across_s$estimate), across_spearman_p = across_s$p.value,
                      across_pearson = unname(across_p$estimate), across_pearson_p = across_p$p.value,
                      within_median_rho = median(wd$rho, na.rm = TRUE), within_mean_rho = mean(wd$rho, na.rm = TRUE),
                      within_rho_wilcox_p = wd_test$p.value,
                      within_n_pos = sum(wd$rho > 0, na.rm = TRUE), within_n_neg = sum(wd$rho < 0, na.rm = TRUE),
                      friedman_pred_p = friedman.test(wide("roc_auc"))$p.value,
                      friedman_bio_p = friedman.test(wide("auroc"))$p.value,
                      pred_range_of_means = diff(range(ms$pred_mean)), bio_range_of_means = diff(range(ms$bio_mean))))
}
S_main <- pvb_stats(SPARSE_BASELINES); S_full <- pvb_stats(character(0))
write_csv(bind_rows(S_main$ms %>% mutate(set = "without RF/XGBoost"), S_full$ms %>% mutate(set = "all methods")),
          file.path(TAB, "prediction_vs_biology_method_means.csv"))
write_csv(bind_rows(S_main$stats, S_full$stats), file.path(TAB, "prediction_vs_biology_stats.csv"))
write_csv(S_main$wd, file.path(TAB, "prediction_vs_biology_within_dataset_rho.csv"))
print(as.data.frame(bind_rows(S_main$stats, S_full$stats)))

st <- S_main$stats
# explicit panel limits so labels/callout can be kept inside the border
XL <- c(0.525, 0.680); YL <- c(0.460, 0.578)
FIXED_LAB <- tibble(method = c("Logistic", "Multiview"), hjust = c(0, 1), dx = c(0.004, -0.005), dy = c(0.0035, -0.0025)) %>%
  left_join(S_main$ms %>% dplyr::select(method, pred_mean, bio_mean), by = "method")
pC <- ggplot(S_main$ms, aes(pred_mean, bio_mean)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_errorbar(aes(ymin = bio_mean - bio_se, ymax = bio_mean + bio_se, colour = class), width = 0, linewidth = 0.3, alpha = 0.5) +
  geom_errorbar(aes(xmin = pred_mean - pred_se, xmax = pred_mean + pred_se, colour = class), width = 0,
                orientation = "y", linewidth = 0.3, alpha = 0.5) +
  geom_point(aes(colour = class, shape = sig_label(credible)), size = 2.5, stroke = 0.9, fill = "white") +
  geom_text(data = FIXED_LAB, aes(x = pred_mean + dx, y = bio_mean + dy, label = method, hjust = hjust), size = TXT) +
  geom_text_repel(aes(label = ifelse(method %in% FIXED_LAB$method, "", method)), size = TXT, min.segment.length = 0, seed = 3, segment.size = 0.3, segment.colour = "grey40",
                  box.padding = 0.3, point.padding = 0.15, force = 2, max.overlaps = Inf, xlim = XL + c(0.002, -0.002), ylim = YL + c(0.002, -0.004)) +
  annotate("text", x = -Inf, y = Inf, hjust = -0.04, vjust = 1.25, size = 7.5 / .pt,
           label = sprintf("Spearman \u03c1 = %.2f (p = %.2f)\nwithin-dataset median \u03c1 = %.2f",
                           st$across_spearman, st$across_spearman_p, st$within_median_rho)) +
  scale_colour_manual(values = CLASS_COLORS, name = "Integration") +
  scale_shape_manual(values = c(significant = 16, `not significant` = 21),
                     labels = c(significant = "above chance (panel A)", `not significant` = "not above chance"),
                     name = NULL, drop = FALSE) +
  scale_y_continuous(limits = YL, expand = c(0, 0)) +
  scale_x_continuous(limits = XL, expand = c(0, 0), breaks = c(0.55, 0.60, 0.65)) +
  labs(title = "Prediction vs biology",
       x = "predictive ROC-AUC (mean)", y = "known-gene AUROC (mean)") +
  th + guides(colour = guide_legend(order = 1, nrow = 1, title.position = "left"),
              shape = guide_legend(order = 2, nrow = 1)) +
  theme(legend.box = "vertical", legend.spacing.y = unit(0, "cm"), legend.margin = margin(0, 0, 0, 0))

# ------------------------------------------------------------------ C: method x disease heatmap
# Cancer = median AUROC over the cancer datasets, * = BH-adjusted Wilcoxon q < 0.05 (as in A).
# Other columns are one dataset each: * = permutation-null FDR < 0.05, + = nominal p < 0.05 only.
sc <- read_csv(here::here("results/sc_new/sc_known_gene_discrimination.csv"), show_col_types = FALSE) %>%
  mutate(method = method_label(method)) %>% dplyr::select(method, dataset_name, auroc, p)
stopifnot(all(sc$method %in% METHOD_LABELS$label))
COLS <- c(cancer = "Cancer (COSMIC)", GSE38609 = "Autism (SFARI)", imaging_omics = "DKD (OT)",
          htx_cell_views = "Heart transplant (MSigDB)", covid_multiomics = "COVID multiomics (OT)", covid_organ = "COVID organ (OT)")
# Significance from the feature-permutation null (run_fig4_null.R): weights permuted
# within each view, 10,000 draws, BH across the methods in each column. Tables copied to TAB.
null_res <- read_csv(file.path(TAB, "fig4_null_results.csv"), show_col_types = FALSE) %>% mutate(method = method_label(method))
null_can <- read_csv(file.path(TAB, "fig4_null_cancer_summary.csv"), show_col_types = FALSE) %>% mutate(method = method_label(method))
heat_tab <- function(drop) {
  canc <- cred %>% filter(!method %in% drop) %>% left_join(null_can %>% dplyr::select(method, null_mean = mean_null_auroc_over_datasets), by = "method") %>%
    transmute(method, col = "cancer", auroc = median_auroc, null_mean, mark = ifelse(q_vs_chance < 0.05, "*", ""))
  one <- null_res %>% filter(in_main_family, disease != "cancer", !method %in% drop) %>%
    transmute(method, col = dataset, auroc, p = emp_p, fdr = emp_fdr, null_mean,
              mark = case_when(emp_fdr < 0.05 ~ "*", emp_p < 0.05 ~ "+", TRUE ~ ""))
  # complete the grid: MOGONET was not run on the COVID datasets (needs >= 3 views; they have 2) -> "NA" tile
  bind_rows(canc, one) %>% tidyr::complete(method, col) %>%
    mutate(col = factor(COLS[col], levels = COLS),
           lab = ifelse(is.na(auroc), "NA", paste0(sub("^0", "", sprintf("%.2f", auroc)), mark, "\n(", sub("^0", "", sprintf("%.2f", null_mean)), ")")))
}
plot_heat <- function(drop, title) {
  ht <- heat_tab(drop) %>% mutate(method = method_factor_y(method))
  ggplot(ht, aes(col, method, fill = auroc)) +
    geom_tile(colour = "white", linewidth = 0.6) +
    geom_text(aes(label = lab, colour = ifelse(is.na(auroc), "na", ifelse(abs(auroc - 0.5) > 0.12, "light", "dark"))),
              size = TXT * 0.8, lineheight = 0.8, show.legend = FALSE) +
    scale_colour_manual(values = c(light = "white", dark = "black", na = "grey40"), guide = "none") +
    scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B", midpoint = 0.5,
                         limits = c(0.35, 0.65), oob = scales::squish, breaks = c(0.4, 0.5, 0.65),
                         labels = c("0.4", "0.5", "≥ 0.65"), name = "AUROC", na.value = "grey88") +
    scale_x_discrete(position = "top") +
    coord_cartesian(clip = "off") +
    labs(title = title, x = NULL, y = NULL, caption = "* BH-adjusted p < 0.05   + nominal only\n(brackets) mean AUROC under the null\nNA: MOGONET needs ≥ 3 views") +
    th + class_axis(distinct(ht, method) %>% mutate(label = as.character(method), y = method)) +
    theme(panel.grid = element_blank(), axis.text.x.top = element_text(size = BS * 0.8, lineheight = 0.85, angle = 40, hjust = 0, vjust = 0),
          plot.caption = element_text(hjust = 0, size = 7, colour = "grey30"),
          legend.key.width = unit(6, "mm"), legend.key.height = unit(2.5, "mm"),
          legend.title = element_text(vjust = 0.85), plot.margin = margin(4, 34, 4, 4))
}
pC_heat <- plot_heat(SPARSE_BASELINES, "Known genes across diseases")
write_csv(heat_tab(SPARSE_BASELINES) %>% mutate(col = gsub("\n", " ", col)), file.path(TAB, "method_by_disease_heatmap.csv"))

# ------------------------------------------------------------------ barcode of known-gene ranks (SUPPLEMENTARY illustration)
# Representative dataset = the cancer dataset where the four shown methods' AUROCs are closest to their
# own medians across the 21 cancer datasets (RMS deviation) -> the "typical" case, not a cherry-pick.
BAR_M <- c("Logistic", "DIABLO-F", "MOFA+", "Multiview")
med_m <- disc %>% filter(disease == "cancer") %>% group_by(method) %>% summarise(m = median(auroc), .groups = "drop")
rep_tab <- disc %>% filter(disease == "cancer", method %in% BAR_M) %>% left_join(med_m, by = "method") %>%
  group_by(dataset_name) %>% summarise(rms_dev = sqrt(mean((auroc - m)^2)), R = first(R), N = first(N), .groups = "drop") %>%
  arrange(rms_dev)
write_csv(rep_tab, file.path(TAB, "barcode_representative_dataset.csv"))
BAR_DS <- rep_tab$dataset_name[1]
message("[barcode] representative dataset: ", BAR_DS, " (RMS deviation from method medians ", round(rep_tab$rms_dev[1], 3), ")")
rk <- readRDS(file.path(TAB, "ranked_genes.rds")) %>% mutate(method = method_label(method)) %>%
  filter(dataset_name == BAR_DS, method %in% BAR_M) %>% group_by(method) %>%
  mutate(pct = (rank(-abscoef, ties.method = "average") - 1) / (n() - 1)) %>% ungroup()
bar_auc <- disc %>% filter(dataset_name == BAR_DS, method %in% BAR_M) %>%
  left_join(cred %>% dplyr::select(method, sig), by = "method") %>% mutate(method = method_factor_y(method))
kn <- rk %>% filter(known) %>% left_join(cred %>% dplyr::select(method, sig), by = "method") %>%
  mutate(method = method_factor_y(method), y = as.integer(method))
# per row: rug of known-gene ranks (bottom) + density of those ranks (top); dotted = uniform (chance);
# shaded band = top 10% of the ranking. Right: AUROC and share of known genes in the top 10% (chance 10%).
dens <- kn %>% group_by(method, y, sig) %>%
  reframe({ d <- density(pct, from = 0, to = 1, bw = 0.05, n = 200); tibble(x = d$x, dn = d$y) }) %>%
  mutate(base = y - 0.12, ymax = base + 0.26 * dn)
top10 <- kn %>% group_by(method, y) %>% summarise(top10 = mean(pct <= 0.1), .groups = "drop") %>%
  left_join(bar_auc %>% dplyr::select(method, auroc), by = "method")
write_csv(top10 %>% mutate(dataset = BAR_DS), file.path(TAB, "barcode_top10_share.csv"))
pBar <- ggplot() +
  annotate("rect", xmin = 0, xmax = 0.1, ymin = -Inf, ymax = Inf, fill = "grey88") +
  geom_ribbon(data = dens, aes(x = x, ymin = base, ymax = ymax, group = method, fill = sig), alpha = 0.45) +
  geom_segment(data = distinct(dens, method, y, base), aes(x = 0, xend = 1, y = base + 0.26, yend = base + 0.26),
               linetype = "dotted", colour = "grey30", linewidth = 0.3) +
  geom_segment(data = kn, aes(x = pct, xend = pct, y = y - 0.42, yend = y - 0.16, colour = sig), linewidth = 0.2, alpha = 0.7) +
  geom_text(data = top10, aes(x = 1.05, y = y, label = sprintf("AUROC %.2f\ntop 10%%: %.0f%%", auroc, 100 * top10)),
            hjust = 0, size = TXT * 0.85, lineheight = 0.85) +
  callout(x = 0.12, y = length(BAR_M) + 0.66, hjust = 0, label = "typical dataset:\nmodest shift") +
  scale_colour_manual(values = SIG_COLORS, guide = "none") + scale_fill_manual(values = SIG_COLORS, guide = "none") +
  scale_y_continuous(breaks = seq_along(levels(kn$method)), labels = levels(kn$method),
                     expand = expansion(add = c(0.08, 0.62))) +
  scale_x_continuous(breaks = c(0, 0.5, 1), labels = c("top", "50%", "bottom"),
                     expand = expansion(mult = c(0.01, 0.01))) +
  coord_cartesian(xlim = c(0, 1), clip = "off") +
  labs(title = sprintf("Known-gene ranks, %s", BAR_DS),
       x = sprintf("|coef| rank of %d COSMIC genes (of %s)", bar_auc$R[1], format(bar_auc$N[1], big.mark = ",")), y = NULL) +
  th + class_axis(tibble(label = levels(kn$method), y = seq_along(levels(kn$method)))) +
  theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        plot.margin = margin(4, 70, 4, 4))

# ------------------------------------------------------------------ D: top-10% enrichment ratio, all cancer datasets
# Per method x cancer dataset: (fraction of known genes ranked in the top 10% of |coef|) / 0.10; 1 = chance.
# Ranks with ties.method = "average" (dense methods have no meaningful ties; RF/XGB omitted in main).
er <- readRDS(file.path(TAB, "ranked_genes.rds")) %>% mutate(method = method_label(method)) %>%
  filter(dataset_name %in% unique(disc$dataset_name[disc$disease == "cancer"])) %>%
  group_by(method, dataset_name) %>%
  mutate(pct = (rank(-abscoef, ties.method = "average") - 1) / (n() - 1)) %>%
  summarise(n_known = sum(known), top10_share = mean(pct[known] <= 0.1), .groups = "drop") %>%
  mutate(enrichment_ratio = top10_share / 0.10)
er_s <- er %>% group_by(method) %>%
  summarise(median_er = median(enrichment_ratio), mean_er = mean(enrichment_ratio),
            n_above1 = sum(enrichment_ratio > 1), n = n(),
            p_vs_1 = suppressWarnings(wilcox.test(enrichment_ratio, mu = 1, alternative = "greater")$p.value), .groups = "drop") %>%
  # D's OWN test (not panel A's): one-sided one-sample Wilcoxon of the 21 ratios vs 1
  mutate(q_vs_1 = main_bh(method, p_vs_1), sig = sig_label(q_vs_1 < 0.05),
         lab = ifelse(q_vs_1 < 0.05, sprintf("%.2f  q=%.2g *", median_er, q_vs_1), sprintf("%.2f  q=%.2g", median_er, q_vs_1))) %>%
  left_join(cred %>% dplyr::select(method, family), by = "method")
write_csv(er, file.path(TAB, "top10_enrichment_ratio_per_dataset.csv"))
write_csv(er_s %>% dplyr::select(-sig, -lab), file.path(TAB, "top10_enrichment_ratio_summary.csv"))
print(as.data.frame(er_s %>% dplyr::select(method, median_er, mean_er, n_above1, p_vs_1)))
plot_er <- function(drop) {
  d <- er %>% filter(!method %in% drop) %>% left_join(er_s %>% dplyr::select(method, sig, family), by = "method") %>%
    mutate(method = method_factor_y(method))
  es <- er_s %>% filter(!method %in% drop) %>% mutate(method = method_factor_y(method))
  xmax <- max(d$enrichment_ratio)
  ggplot(d, aes(enrichment_ratio, method)) +
    geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
    geom_boxplot(aes(colour = sig), outlier.shape = NA, fill = NA, width = 0.62, linewidth = 0.45) +
    geom_point(aes(colour = sig), size = 1, alpha = 0.55, position = position_jitter(height = 0.16, width = 0, seed = 1)) +
    stat_summary(aes(fill = sig), fun = median, geom = "point", shape = 21, size = 2.4, colour = "white", stroke = 0.5) +
    geom_text(data = es, aes(x = xmax * 1.04 + 0.05, y = method, label = lab, colour = sig),
              hjust = 0, size = TXT, show.legend = FALSE) +
    facet_grid(family ~ ., scales = "free_y", space = "free_y") +
    sig_scale() + guides(colour = "none", fill = "none") +
    scale_x_continuous(breaks = 0:3) +                       # 0.5-steps crowd the narrow panel
    coord_cartesian(xlim = c(-0.1, xmax * 1.02), expand = FALSE, clip = "off") +
    labs(title = "Top-10% enrichment", x = "known-gene share in top 10% / 10%", y = NULL) +
    th + class_axis(distinct(d, method, family) %>% mutate(label = as.character(method), y = method)) +
    theme(panel.grid.major.y = element_blank(), strip.text = element_blank(),
          panel.spacing.y = unit(4, "pt"), plot.margin = margin(4, 78, 4, 4))
}
pD <- plot_er(SPARSE_BASELINES)

# ------------------------------------------------------------------ assemble main Fig 4 (2 x 2)
# A credibility | B prediction vs biology / C method x disease heatmap | D top-10% enrichment ratio (all datasets).
FIG_W <- 7; FIG_H <- 8.3; ROW_H <- c(1.15, 1); COL_W <- c(1.1, 1)
COL_W_BOT <- c(1, 2.2)    # C = panel area (6 heatmap columns); D = whole wrapped plot incl. its labels
pB_pred <- pC
# wrap_elements(): D is not aligned to C's tall rotated column header, so D's panel fills its own cell (no empty band).
fig4 <- (((pA + labs(tag = "A")) | (pB_pred + labs(tag = "B"))) + plot_layout(widths = c(0.62, 1))) /
        (((pC_heat + labs(tag = "C")) | wrap_elements(full = pD + labs(tag = "D"))) + plot_layout(widths = COL_W_BOT)) + plot_layout(heights = ROW_H)
save_main(fig4, file.path(MAIN, "Fig4_biology_validity"), width = FIG_W, height = FIG_H)
save_plot_both(pB_pred, file.path(OUT, "prediction_vs_biology.png"), width = 3.6, height = 3.8, dpi = 300)
# single-panel exports at the size each panel occupies in the assembled figure (no tags)
PANELS <- here::here("results/final_figures/panels"); dir.create(PANELS, recursive = TRUE, showWarnings = FALSE)
top_h <- FIG_H * ROW_H[1] / sum(ROW_H); bot_h <- FIG_H * ROW_H[2] / sum(ROW_H)
wl <- FIG_W * COL_W[1] / sum(COL_W); wr <- FIG_W * COL_W[2] / sum(COL_W)
save_panel <- function(p, name, w, h) for (ext in c("pdf", "svg"))
  ggsave(file.path(PANELS, paste0(name, ".", ext)), p, width = w, height = h, bg = "white",
         device = if (ext == "pdf") cairo_pdf else "svg")
save_panel(pA,      "Fig4_A_known_gene_credibility", wl, top_h)
save_panel(pB_pred, "Fig4_B_prediction_vs_biology",  wr, top_h)
# bottom row: measured from the assembled PNG (C incl. its labels ~3.25 in, wrapped D ~3.75 in)
save_panel(pC_heat, "Fig4_C_method_by_disease",      3.25, bot_h)
save_panel(pD,      "Fig4_D_top10_enrichment_ratio", 3.75, bot_h)
# barcode illustration -> supplementary (S8 biology detail)
save_main(pBar, file.path(SUPP, "FigS_biology_barcode_example"), width = 4.6, height = 3.8)

# ------------------------------------------------------------------ supplementary
supp_cap <- function(x) theme(plot.caption = element_text(hjust = 0, size = 7, colour = "grey30"))
# S1: full credibility + cross-disease incl. RF/XGB
pA_full <- plot_credibility(character(0), title = sprintf("Known cancer genes, all methods (%d datasets)", N_CANCER))
s1 <- pA_full / (pB_full + labs(caption = paste0(
    "Random Forest and XGBoost (n_estimators = 10) assign zero importance to 88-99.9% of genes (median 98.5%);\ntheir AUROC is pinned near 0.5 by ties and is not interpretable as absence of biological signal.\nThe Random Forest DKD p-value (~1e-5 at AUROC 0.51) ",
    "is likewise a tie artefact.")) + supp_cap()) + plot_layout(heights = c(1.3, 0.85))
save_main(s1, file.path(SUPP, "FigS_biology_credibility_full"), width = 7, height = 7.8)

# S2: per-dataset AUROC heatmap (all diseases), * = BH < 0.05 within dataset across methods
hm <- disc %>% filter(disease %in% c("cancer", "autism", "DKD")) %>%
  left_join(null_res %>% dplyr::select(method, dataset_name = dataset, emp_fdr12), by = c("method", "dataset_name")) %>%
  mutate(star = ifelse(emp_fdr12 < 0.05, "*", ""),
         dgroup = factor(ifelse(disease == "cancer", "Cancer (COSMIC CGC)", "Other"), levels = c("Cancer (COSMIC CGC)", "Other")),
         dataset_lab = case_when(dataset_name == "GSE38609" ~ "GSE38609 (autism)",
                                 dataset_name == "imaging_omics" ~ "imaging_omics (DKD)", TRUE ~ dataset_name))
ds_ord <- hm %>% group_by(dataset_lab) %>% summarise(m = mean(auroc), .groups = "drop") %>% arrange(desc(m)) %>% pull(dataset_lab)
pS2 <- hm %>% mutate(method = method_factor_y(method), dataset_lab = factor(dataset_lab, levels = ds_ord)) %>%
  ggplot(aes(dataset_lab, method, fill = auroc)) +
  geom_tile(colour = "white") + geom_text(aes(label = star), size = 3.4, vjust = 0.78) +
  facet_grid(. ~ dgroup, scales = "free_x", space = "free_x") +
  scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B", midpoint = 0.5, name = "AUROC") +
  labs(title = "Known-gene AUROC per dataset", x = NULL, y = NULL,
       caption = paste0("* = permutation-null FDR < 0.05 (BH across methods within dataset).\n",
                        "Random Forest / XGBoost stars can arise from ties (most importances are exactly 0).")) +
  coord_cartesian(clip = "off") +
  th + supp_cap() + class_axis(tibble(label = unique(hm$method), y = label,
                                      dgroup = factor(levels(hm$dgroup)[1], levels = levels(hm$dgroup)))) +
  theme(axis.text.x = element_text(angle = 50, hjust = 1, size = 7), panel.grid = element_blank(),
                          legend.position = "right")
save_main(pS2, file.path(SUPP, "FigS_biology_auroc_heatmap"), width = 7, height = 4.4)

# S3: top-100 enrichment (Fisher OR) summary over cancer datasets
enr <- disc %>% filter(disease == "cancer") %>%
  mutate(expected = 100 * R / N, hits_est = NA_real_, log2_or = log2(pmax(odds_ratio, 1 / 16)))
enr_s <- enr %>% group_by(method) %>%
  summarise(median_or = median(odds_ratio), mean_or = mean(odds_ratio),
            frac_fisher_sig = mean(fisher_p < 0.05), n_fisher_sig = sum(fisher_p < 0.05), n = n(), .groups = "drop") %>%
  mutate(tie_artefact = method %in% SPARSE_BASELINES)
write_csv(enr_s, file.path(TAB, "top100_enrichment_summary.csv"))
pS3 <- enr %>% mutate(method = method_factor_y(method),
                      rank_type = factor(ifelse(as.character(method) %in% SPARSE_BASELINES, "top-100 set by ties (RF/XGBoost)", "dense ranking"),
                                         levels = c("dense ranking", "top-100 set by ties (RF/XGBoost)")),
                      fsig = sig_label(fisher_p < 0.05)) %>%
  ggplot(aes(log2_or, method)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_boxplot(aes(linetype = rank_type), outlier.shape = NA, fill = NA, colour = "grey35", width = 0.6, linewidth = 0.4) +
  geom_point(aes(colour = fsig), size = 1.3, alpha = 0.8, position = position_jitter(height = 0.16, width = 0, seed = 1)) +
  geom_text(data = enr_s %>% mutate(method = method_factor_y(method)),
            aes(x = max(enr$log2_or) + 0.3, y = method, label = sprintf("OR %.2f; %d/%d sig.", median_or, n_fisher_sig, n)),
            hjust = 0, size = TXT, colour = "grey20") +
  scale_colour_manual(values = SIG_COLORS, labels = c(significant = "Fisher p < 0.05", `not significant` = "n.s."), name = NULL, drop = FALSE) +
  scale_linetype_manual(values = c(`dense ranking` = "solid", `top-100 set by ties (RF/XGBoost)` = "dotted"), name = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0.03, 0.30))) +
  labs(title = sprintf("Top-100 enrichment, %d cancer datasets", N_CANCER),
       x = "log2 odds ratio, known genes in top-100 |coef| (0 = none)", y = NULL,
       caption = "One-sided Fisher test per dataset; label = median OR and number of datasets with p < 0.05.
Points at the left edge = OR 0 (no known gene in top-100).") +
  coord_cartesian(clip = "off") +
  th + supp_cap() + class_axis(tibble(label = unique(enr$method), y = label)) +
  theme(panel.grid.major.y = element_blank(), legend.box = "vertical")
save_main(pS3, file.path(SUPP, "FigS_biology_top100_enrichment"), width = 7, height = 4.4)

# S4: MOMIX <-> TCGA concordance (top-k defined only for methods with >= 100 non-zero genes)
conc <- read_csv(file.path(TAB, "same_cancer_concordance.csv"), show_col_types = FALSE) %>%
  mutate(method = method_label(method))
conc_ok <- conc %>% filter(topk_defined)
pS4 <- conc_ok %>% mutate(method = method_factor_y(method),
                          pair = recode(pair, breast = "breast (BRCA)", kidney = "kidney (KIRC)", melanoma = "melanoma (SKCM)")) %>%
  ggplot(aes(jaccard, method)) +
  geom_vline(xintercept = mean(conc$expected_jaccard), linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_point(aes(shape = pair), size = 2.2, colour = "grey20", position = position_dodge(width = 0.5)) +
  scale_shape_manual(values = c(16, 17, 15), name = NULL) +
  labs(title = "Same-cancer reproducibility (MOMIX vs TCGA)", x = "top-100 |coef| Jaccard", y = NULL,
       caption = sprintf(paste0("Dashed = chance (%.3f). MOMIX is reprocessed TCGA, so this is a stability check, not independent replication.\n",
                                "Random Forest / XGBoost omitted: fewer than 100 non-zero importances, so their top-100 is set by tie order."),
                         mean(conc$expected_jaccard))) +
  coord_cartesian(clip = "off") +
  th + supp_cap() + class_axis(tibble(label = unique(conc_ok$method), y = label)) +
  theme(panel.grid.major.y = element_blank())
save_main(pS4, file.path(SUPP, "FigS_biology_momix_tcga_concordance"), width = 7, height = 3.8)

message("[done] Figure 4 + biology supplementary figures")
