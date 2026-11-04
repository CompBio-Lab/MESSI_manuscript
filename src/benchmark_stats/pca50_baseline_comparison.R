# ==============================================================================
# pca50_baseline_comparison.R   (is the raw-concat baseline overfitting?)
# The PCA50 run provides BOTH early-integration variants per sklearn classifier:
#   *-empty  = raw concatenation of all features (p >> n)
#   *-pca50  = each modality reduced to 50 PCs (PCA fitted on the training fold), then concatenated
# Paired comparison per classifier over the bulk multimodal datasets (Wilcoxon signed-rank).
# Metric = pipeline metrics.csv ROC-AUC (pooled out-of-fold; identical to pooled_metrics.csv to 5e-4).
# Outputs: results/benchmark_stats/pca50_comparison{.png,_summary.csv,_perdataset.csv}
#          results/final_figures/supp/FigS_bulk_pca50_vs_raw.{png,pdf}
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(ggplot2); library(here)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))
OUT  <- here::here("results/benchmark_stats"); dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
SUPP <- here::here("results/final_figures/supp")

RUN <- Sys.glob(here::here("data/raw/final_classification_results/pca50-all-data/copied_results_*/metrics.csv"))[1]
m <- read_csv(RUN, show_col_types = FALSE)

# bulk multimodal datasets only (the 3 single-cell sets are in the same run)
SC <- c("covid_multiomics", "covid_organ", "htx_cell_views")
d <- m %>% filter(!dataset %in% SC) %>%
  mutate(classifier = method_label(str_replace(method_name, "-pca50$", "-empty")),
         variant = ifelse(str_detect(method_name, "pca50"), "PCA50", "Raw concatenation")) %>%
  group_by(classifier, variant, dataset) %>%
  summarise(roc_auc = mean(roc_auc, na.rm = TRUE), .groups = "drop")

wide <- d %>% pivot_wider(names_from = variant, values_from = roc_auc) %>%
  filter(!is.na(`Raw concatenation`), !is.na(PCA50)) %>%
  mutate(delta = `Raw concatenation` - PCA50)
n_ds <- n_distinct(wide$dataset)

summ <- wide %>% group_by(classifier) %>%
  summarise(median_raw = round(median(`Raw concatenation`), 3), median_pca50 = round(median(PCA50), 3),
            median_delta = round(median(delta), 3),
            mean_raw = round(mean(`Raw concatenation`), 3), mean_pca50 = round(mean(PCA50), 3),
            mean_delta = round(mean(delta), 3),
            p = signif(suppressWarnings(wilcox.test(`Raw concatenation`, PCA50, paired = TRUE)$p.value), 2),
            n = n(), .groups = "drop") %>%
  mutate(p_holm = signif(p.adjust(p, "holm"), 2))
write_csv(summ, file.path(OUT, "pca50_comparison_summary.csv"))
write_csv(wide, file.path(OUT, "pca50_comparison_perdataset.csv"))
message(sprintf("[PCA50] raw-concat vs PCA50 per classifier (ROC-AUC, %d datasets):", n_ds))
print(as.data.frame(summ))

VAR_COL <- setNames(PAIR_COLORS, c("Raw concatenation", "PCA50"))
long <- wide %>% select(classifier, dataset, `Raw concatenation`, PCA50) %>%
  pivot_longer(c(`Raw concatenation`, PCA50), names_to = "variant", values_to = "roc_auc") %>%
  mutate(variant = factor(variant, levels = names(VAR_COL)),
         classifier = factor(classifier, levels = method_levels(unique(classifier))))
lab <- summ %>% mutate(classifier = factor(classifier, levels = levels(long$classifier)),
                       txt = sprintf("median Δ = %+.3f\np = %.2g", median_delta, p))
p1 <- ggplot(long, aes(variant, roc_auc)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_line(aes(group = dataset), colour = "grey80", linewidth = 0.3) +
  geom_boxplot(aes(colour = variant), fill = NA, outlier.shape = NA, width = 0.45, linewidth = 0.45) +
  geom_point(aes(colour = variant), size = 0.9, alpha = 0.8) +
  geom_text(data = lab, aes(x = 1.5, y = 1.06, label = txt), size = 2.5, lineheight = 0.9, inherit.aes = FALSE) +
  facet_wrap(~ classifier, nrow = 1) +
  scale_colour_manual(values = VAR_COL, name = NULL) +
  scale_x_discrete(labels = c("Raw", "PCA50")) +
  scale_y_continuous(limits = c(0.3, 1.12), breaks = seq(0.3, 1, 0.1)) +
  labs(title = "Early-integration baselines: raw concatenation vs PCA50",
       x = NULL, y = sprintf("Pooled ROC-AUC (%d datasets)", n_ds),
       caption = "Lines join the same dataset. Δ = median over datasets of (raw − PCA50); p = paired Wilcoxon signed-rank (unadjusted).") +
  theme_messi() + theme(legend.position = "none",
                        plot.caption = element_text(size = 6.5, hjust = 0, colour = "grey30"))
save_plot_both(p1, file.path(OUT, "pca50_comparison.png"), width = 7, height = 3.6, dpi = 300)
save_final_fig(p1 + labs(tag = "A") + theme(plot.tag = element_text(face = "bold", size = 14)), file.path(SUPP, "FigS_bulk_pca50_vs_raw"), width = 7, height = 3.6)
message("[done] -> ", OUT, "/pca50_comparison.png")
