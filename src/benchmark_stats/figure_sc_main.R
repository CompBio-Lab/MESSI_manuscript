# ==============================================================================
# figure_sc_main.R — single-cell benchmark panels (Fig 5 B and D + supplementary detail)
# Three single-cell (pseudobulk) multimodal datasets from two runs: covid_only
# (covid_multiomics, covid_organ; no MOGONET) and htx_only (htx_cell_views, with MOGONET).
# Fold-level metrics are recomputed from all_langs-result.csv with the SAME validated
# functions as the bulk pipeline (compute_fold_metrics), so sc and bulk are on one footing.
# Only 3 datasets with 8-15 test samples per fold -> per-fold distributions, no CD diagram.
# Hyperparameters are the pipeline DEFAULTS (no inner-CV tuning was run).
# Outputs (results/sc_new/):
#   figure_sc_pooled_roc_panel.rds Fig 5B pooled ROC-AUC per method x dataset (+ per-fold range)
#   figure_sc_perf_panel.rds   SUPP  ROC-AUC + PR-AUC per fold (colour = dataset)
#   figure_sc_cost_panel.rds   Fig 5C  per-fold training time + peak memory (colour = dataset)
#   figure_sc_performance.png  standalone version of 5B
#   figure_sc_cost.png         standalone version of 5D
#   figure_sc_perf_detail.png  SUPP: mean ROC/PR-AUC of every variant + single-view Logistic
#   sc_fold_metrics.csv, sc_fold_metrics_all_variants.csv, sc_cost_per_fold.csv,
#   sc_dataset_facts.csv (Table 2 facts derivable locally)
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(ggplot2)
  library(here); library(patchwork)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))
source(here::here("src/common_helpers/theme_messi.R"))
source(here::here("src/common_helpers/computational_resources_utils.R"))
# Method names coloured by integration class. theme_messi's scale_y_method()/theme_method_axis()
# (ggtext markdown) print raw <span> tags with ggplot2 4.0.0 + ggtext 0.1.2, so colour the
# y-axis text directly (vectorised element_text colour; levels = bottom -> top).
class_axis_y <- function(lv) theme(axis.text.y = element_text(colour = unname(
  ifelse(is.na(method_class(lv)), "black", CLASS_COLORS[method_class(lv)]))))
OUT <- here::here("results/sc_new"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- locate the two single-cell runs ------------------------------------------
SC_RUNS <- c(
  Sys.glob(here::here("data/raw/final_classification_results/covid_only/copied_results_*")),
  Sys.glob(here::here("data/raw/final_classification_results/htx_only/copied_results_*")))
stopifnot(length(SC_RUNS) == 2)

SC_DATASETS <- c("covid_multiomics", "covid_organ", "htx_cell_views")
SC_LABELS   <- c(covid_multiomics = "COVID multiomics", covid_organ = "COVID organ",
                 htx_cell_views   = "Heart transplant")
# ONE dataset palette for every single-cell panel (Okabe-Ito)
SC_DS_COLORS <- c("COVID multiomics" = "#0072B2", "COVID organ" = "#009E73", "Heart transplant" = "#D55E00")
# representative variants = same as the bulk main text (DIABLO-N, RGCCA-F, 2 components)
KEEP <- c("diablo-null_ncomp-2", "rgcca-full_ncomp-2", "caret_multimodal",
          "cooperative_learning", "integrao", "mofa", "mogonet",
          "sklearn-Logit-empty", "sklearn-MLP-empty",
          "sklearn-Random_Forest-empty", "sklearn-XGBoost-empty")

# ---- load predictions, compute fold metrics -----------------------------------
pred_all <- read_runs("all_langs-result.csv", runs = SC_RUNS)
fold_all <- compute_fold_metrics(pred_all) %>%
  mutate(base_ds = str_extract(dataset, paste0("^(", paste(SC_DATASETS, collapse = "|"), ")")),
         view = ifelse(dataset == base_ds, NA_character_, str_remove(dataset, paste0("^", base_ds, "-"))))
write_csv(fold_all, file.path(OUT, "sc_fold_metrics_all_variants.csv"))

fold <- fold_all %>% filter(dataset %in% SC_DATASETS, method_name %in% KEEP) %>%
  mutate(label = bench_label(method_name, collapse = TRUE),
         ds = factor(SC_LABELS[dataset], levels = SC_LABELS))
write_csv(fold, file.path(OUT, "sc_fold_metrics.csv"))
n_ds <- n_distinct(fold$dataset)

prev <- fold %>% group_by(ds) %>% summarise(prev = sum(n_pos) / sum(n), .groups = "drop")

# ---- Fig 5B: ROC-AUC and PR-AUC per fold ---------------------------------------
METRIC_LAB <- c(roc_auc = "ROC-AUC", pr_auc = "PR-AUC")
perf_long <- fold %>% select(label, ds, fold, roc_auc, pr_auc) %>%
  pivot_longer(c(roc_auc, pr_auc), names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(METRIC_LAB[metric], levels = METRIC_LAB), method = method_factor_y(label))
means <- perf_long %>% group_by(method, metric) %>% summarise(value = mean(value, na.rm = TRUE), .groups = "drop")
refs <- bind_rows(
  tibble(metric = factor("ROC-AUC", levels = METRIC_LAB), x = 0.5, ds = NA),
  prev %>% transmute(metric = factor("PR-AUC", levels = METRIC_LAB), x = prev, ds))

set.seed(1)
pB <- ggplot(perf_long, aes(value, method)) +
  geom_vline(data = refs %>% filter(is.na(ds)), aes(xintercept = x),
             linetype = REF_LINE$linetype, colour = REF_LINE$colour, linewidth = REF_LINE$linewidth) +
  geom_vline(data = refs %>% filter(!is.na(ds)), aes(xintercept = x, colour = ds),
             linetype = "dashed", linewidth = 0.4, show.legend = FALSE) +
  geom_point(aes(colour = ds), position = position_jitter(height = 0.18, width = 0, seed = 1),
             size = 1.3, alpha = 0.8) +
  geom_point(data = means, shape = 124, size = 4.2, colour = "black") +
  facet_wrap(~metric, nrow = 1, scales = "free_x") +
  scale_colour_manual(values = SC_DS_COLORS, name = NULL) +
  labs(x = "Per-fold score (| = mean over all folds)", y = NULL) +
  theme_messi(9) + class_axis_y(levels(perf_long$method))
saveRDS(pB, file.path(OUT, "figure_sc_perf_panel.rds"))
save_plot_both(pB + labs(title = sprintf("Single-cell classification performance (%d datasets, 5-fold CV)", n_ds),
                         caption = paste0("One point per test fold (8-15 samples; COVID multiomics folds hold only 1-2 controls). ",
                                          "Dashed coloured lines in PR-AUC = positive-class prevalence\nper dataset. ",
                                          "Default hyperparameters. MOGONET only on heart transplant. Rankings are indicative only.")) +
                 theme(plot.caption = element_text(hjust = 0, size = 7.5, colour = "grey30"), plot.caption.position = "plot"),
               file.path(OUT, "figure_sc_performance.png"), width = 7, height = 3.9, dpi = 300)

cat("\n=== single-cell mean ROC-AUC / PR-AUC by method x dataset ===\n")
summ <- fold %>% group_by(label, ds) %>%
  summarise(roc = mean(roc_auc), roc_sd = sd(roc_auc), pr = mean(pr_auc), .groups = "drop")
summ %>% select(label, ds, roc) %>% mutate(roc = round(roc, 3)) %>%
  pivot_wider(names_from = ds, values_from = roc) %>% as.data.frame() %>% print()
summ %>% select(label, ds, pr) %>% mutate(pr = round(pr, 3)) %>%
  pivot_wider(names_from = ds, values_from = pr) %>% as.data.frame() %>% print()
write_csv(summ, file.path(OUT, "sc_method_dataset_means.csv"))

# ---- Fig 5B: pooled out-of-fold ROC-AUC per method x dataset ----
# One point = ROC-AUC of all test-fold predictions pooled (same definition as the bulk
# 'Pooled ROC-AUC', compute_pooled_metrics); thin line = min-max of the 5 per-fold ROC-AUCs.
pooled <- compute_pooled_metrics(pred_all %>% filter(dataset %in% SC_DATASETS, method_name %in% KEEP)) %>%
  mutate(label = bench_label(method_name), class = method_class(method_name))
rng <- fold %>% group_by(method_name, dataset) %>%
  summarise(fold_min = min(roc_auc, na.rm = TRUE), fold_max = max(roc_auc, na.rm = TRUE),
            fold_mean = mean(roc_auc, na.rm = TRUE), .groups = "drop")
pooled <- pooled %>% left_join(rng, by = c("method_name", "dataset"))
write_csv(pooled %>% select(label, class, dataset, n, n_pos, pooled_roc_auc = roc_auc, pooled_pr_auc = pr_auc,
                            fold_mean, fold_min, fold_max, everything()),
          file.path(OUT, "sc_pooled_metrics.csv"))
hdr <- pooled %>% distinct(dataset, n, n_pos) %>%
  mutate(head = sprintf("%s\n%d (%d pos.)",
                        c(covid_multiomics = "COVID\nmultiomics", covid_organ = "COVID\norgan",
                          htx_cell_views = "Heart\ntransplant")[dataset], n, n_pos))
pooled <- pooled %>% mutate(ds_head = factor(hdr$head[match(dataset, hdr$dataset)],
                                             levels = hdr$head[match(SC_DATASETS, hdr$dataset)]),
                            method = method_factor_y(label))
cat("\n=== pooled out-of-fold ROC-AUC ===\n")
pooled %>% select(label, dataset, roc_auc) %>% mutate(roc_auc = round(roc_auc, 3)) %>%
  pivot_wider(names_from = dataset, values_from = roc_auc) %>% as.data.frame() %>% print()
pB2 <- ggplot(pooled, aes(y = method)) +
  geom_vline(xintercept = 0.5, linetype = REF_LINE$linetype, colour = REF_LINE$colour, linewidth = REF_LINE$linewidth) +
  geom_segment(aes(x = fold_min, xend = fold_max, yend = method), colour = "grey75", linewidth = 0.6) +
  geom_point(aes(x = roc_auc, colour = class), size = 2.4) +
  facet_wrap(~ds_head, nrow = 1) +
  scale_colour_class() +
  scale_x_continuous(limits = c(0, 1), breaks = c(0, 0.5, 1), labels = c("0", "0.5", "1")) +
  labs(x = "Pooled out-of-fold ROC-AUC", y = NULL) +
  theme_messi(9) + class_axis_y(levels(pooled$method)) +
  theme(legend.position = "bottom", legend.title = element_text(size = 8), legend.text = element_text(size = 8),
        strip.text = element_text(size = 8, face = "bold"))
saveRDS(pB2, file.path(OUT, "figure_sc_pooled_roc_panel.rds"))

# ---- SUPP: every variant + single-view Logistic, mean over folds -----------------
multi <- fold_all %>% filter(dataset %in% SC_DATASETS) %>%
  mutate(row = bench_label(method_name, collapse = FALSE))
single <- fold_all %>% filter(!is.na(view), method_name == "sklearn-Logit-empty") %>%
  group_by(base_ds, view) %>% summarise(roc_auc = mean(roc_auc), pr_auc = mean(pr_auc), .groups = "drop") %>%
  group_by(base_ds) %>%
  summarise(`Logistic, best single view (post hoc)` = list(c(max(roc_auc), max(pr_auc))),
            `Logistic, median single view` = list(c(median(roc_auc), median(pr_auc))), .groups = "drop") %>%
  pivot_longer(-base_ds, names_to = "row") %>%
  mutate(roc_auc = sapply(value, `[`, 1), pr_auc = sapply(value, `[`, 2)) %>% select(-value) %>%
  rename(dataset = base_ds)
det <- bind_rows(
  multi %>% group_by(row, dataset) %>% summarise(roc_auc = mean(roc_auc), pr_auc = mean(pr_auc), .groups = "drop"),
  single) %>%
  pivot_longer(c(roc_auc, pr_auc), names_to = "metric") %>%
  mutate(metric = factor(METRIC_LAB[metric], levels = METRIC_LAB),
         ds = factor(SC_LABELS[dataset], levels = SC_LABELS))
row_lv <- c(rev(sort(unique(single$row))),
            unique(multi$row)[order(method_order(unique(multi$method_name)), unique(multi$row))])
row_lv <- rev(unique(row_lv))
det <- det %>% mutate(row = factor(row, levels = row_lv))
write_csv(det, file.path(OUT, "sc_perf_detail_table.csv"))
pDet <- ggplot(det %>% mutate(ds = factor(sub(" ", "
", as.character(ds)), levels = sub(" ", "
", SC_LABELS))), aes(ds, row, fill = value)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", value)), size = 2.6) +
  facet_wrap(~metric, nrow = 1) +
  scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0.5,
                       limits = c(0, 1), name = "Mean over 5 folds", guide = guide_colourbar(barwidth = unit(45, "mm"))) +
  labs(x = NULL, y = NULL, title = "Single-cell performance, all method variants",
       caption = paste0("Mean over the 5 test folds. Top two rows: Logistic regression on one view at a time; ",
                        "'best single view' is chosen post hoc on the test folds\n(optimistic). ",
                        "Heart transplant has 10 cell-type views; the COVID datasets have 2 views.")) +
  theme_messi(8.5) + theme(panel.grid = element_blank(), 
                           plot.caption = element_text(hjust = 0, size = 7, colour = "grey30"),
                           plot.caption.position = "plot")
save_plot_both(pDet, file.path(OUT, "figure_sc_perf_detail.png"), width = 7, height = 5.6, dpi = 300)

# ---- Fig 5D: computational cost per fold (training stage) ------------------------
tr <- bind_rows(lapply(SC_RUNS, function(d) {
  f <- file.path(d, "execution_trace.txt")
  if (file.exists(f)) suppressWarnings(as_tibble(data.table::fread(f))) else NULL
}))
cost <- tr %>%
  filter(str_detect(process, "CROSS_VALIDATION"), str_detect(process, "_TRAIN$")) %>%
  mutate(raw = str_match(process, "CV_(?:R|PYTHON):([A-Z_]+):")[, 2],
         m = str_match(tag, "^(.+?)-fold_(\\d+)(?:-(.*))?$"),
         dataset = m[, 2], fold = paste0("fold_", m[, 3]), rest = m[, 4]) %>%
  filter(dataset %in% SC_DATASETS) %>%
  mutate(method_name = case_when(
    raw == "DIABLO" ~ str_replace(rest, "^design_(full|null)-ncomp_(\\d)$", "diablo-\\1_ncomp-\\2"),
    raw == "RGCCA"  ~ str_replace(rest, "^rgcca-design_(full|null)-ncomp_(\\d)$", "rgcca-\\1_ncomp-\\2"),
    raw == "SKLEARN" ~ paste0("sklearn-", rest),
    TRUE ~ tolower(raw))) %>%
  filter(method_name %in% KEEP) %>%
  mutate(label = bench_label(method_name), ds = factor(SC_LABELS[dataset], levels = SC_LABELS),
         time_s = convert_to_seconds(realtime), mem_gib = convert_to_mb(peak_rss) / 1024) %>%
  select(label, method_name, dataset, ds, fold, time_s, mem_gib)
write_csv(cost, file.path(OUT, "sc_cost_per_fold.csv"))
stopifnot(all(KEEP %in% cost$method_name))
cat("\n=== single-cell cost: median per-fold training time (s) / peak memory (GiB) ===\n")
cost %>% group_by(label, ds) %>% summarise(t = round(median(time_s), 1), mem = round(median(mem_gib), 2), .groups = "drop") %>%
  pivot_wider(names_from = ds, values_from = c(t, mem)) %>% as.data.frame() %>% print()

COST_LAB <- c(time_s = "Time per fold (s)", mem_gib = "Memory (GiB)")
cost_long <- cost %>% pivot_longer(c(time_s, mem_gib), names_to = "metric") %>%
  mutate(metric = factor(COST_LAB[metric], levels = COST_LAB), method = method_factor_y(label))
cost_med <- cost_long %>% group_by(method, metric) %>% summarise(value = median(value), .groups = "drop")
pD <- ggplot(cost_long, aes(value, method)) +
  geom_point(aes(colour = ds), position = position_jitter(height = 0.18, width = 0, seed = 1), size = 1.2, alpha = 0.8) +
  geom_point(data = cost_med, shape = 124, size = 4.2, colour = "black") +
  facet_wrap(~metric, nrow = 1, scales = "free_x") +
  scale_x_log10(labels = function(x) format(x, drop0trailing = TRUE, scientific = FALSE, trim = TRUE)) +
  scale_colour_manual(values = SC_DS_COLORS, name = NULL) +
  labs(x = "Per fold (log scale)", y = NULL) +
  theme_messi(9) + class_axis_y(levels(cost_long$method))
saveRDS(pD, file.path(OUT, "figure_sc_cost_panel.rds"))
save_plot_both(pD + labs(title = "Single-cell computational cost (training one CV fold)",
                         caption = "Wall time and peak resident memory of the training task for each fold (Nextflow trace); a relative comparison, not end-to-end runtime.") +
                 theme(plot.caption = element_text(hjust = 0, size = 7.5, colour = "grey30"), plot.caption.position = "plot"),
               file.path(OUT, "figure_sc_cost.png"), width = 7, height = 3.6, dpi = 300)

# ---- Table 2 facts derivable locally --------------------------------------------
meta <- bind_rows(lapply(SC_RUNS, function(d) read_csv(file.path(d, "parsed_metadata.csv"), col_types = cols(.default = "c"))))
facts <- meta %>% mutate(dataset = str_remove(dataset_name, "_processed$")) %>%
  filter(dataset %in% SC_DATASETS) %>%
  left_join(pred_all %>% filter(dataset %in% SC_DATASETS, method_name == "sklearn-Logit-empty") %>%
              group_by(dataset) %>% summarise(n_samples = n_distinct(sample_name), n_pos = sum(y == 1),
                                              n_neg = sum(y == 0), .groups = "drop"), by = "dataset") %>%
  left_join(fold %>% filter(method_name == "sklearn-Logit-empty") %>% group_by(dataset) %>%
              summarise(test_n_range = paste(range(n), collapse = "-"),
                        test_minority_range = paste(range(pmin(n_pos, n - n_pos)), collapse = "-"), .groups = "drop"),
            by = "dataset")

# ============================================================================ #
# Fig 5 panels: C integration gain, D sc-vs-bulk rank, E rank bump,
# F cost (one point per method x dataset). Pooled out-of-fold ROC-AUC throughout.
# ============================================================================ #
DS_SHORT <- c(covid_multiomics = "COVID\nmultiomics", covid_organ = "COVID\norgan", htx_cell_views = "Heart\ntransplant")

# ---- C: integration gain vs single-view Logistic (same definition as bulk integration_gain.R) ----
sv <- compute_pooled_metrics(pred_all %>% filter(method_name == "sklearn-Logit-empty", !dataset %in% SC_DATASETS)) %>%
  mutate(parent = str_extract(dataset, paste0("^(", paste(SC_DATASETS, collapse = "|"), ")")),
         view = str_remove(dataset, paste0("^", parent, "-"))) %>% filter(!is.na(parent))
sv_ref <- sv %>% group_by(dataset = parent) %>%
  summarise(n_views = n(), roc_best = max(roc_auc), roc_mean = mean(roc_auc),
            best_view = view[which.max(roc_auc)], .groups = "drop")
gain <- pooled %>% select(label, class, method_name, dataset, roc_auc) %>%
  left_join(sv_ref, by = "dataset") %>%
  mutate(gain_mean = roc_auc - roc_mean, gain_best = roc_auc - roc_best)
write_csv(gain, file.path(OUT, "sc_integration_gain.csv"))
write_csv(sv %>% select(parent, view, roc_auc, pr_auc), file.path(OUT, "sc_single_view_scores.csv"))
cat("\n=== sc single-view Logistic reference ===\n"); print(as.data.frame(sv_ref))
gain_long <- gain %>% pivot_longer(c(gain_mean, gain_best), names_to = "ref", values_to = "gain") %>%
  mutate(ref = factor(ifelse(ref == "gain_mean", "vs mean view", "vs best view"),
                      levels = c("vs mean view", "vs best view")),
         method = method_factor_y(label), dsl = factor(DS_SHORT[dataset], levels = DS_SHORT))
pC_gain <- ggplot(gain_long, aes(gain, method)) +
  geom_vline(xintercept = 0, linetype = REF_LINE$linetype, colour = REF_LINE$colour, linewidth = REF_LINE$linewidth) +
  geom_line(aes(group = method), colour = "grey80", linewidth = 0.5) +
  geom_point(aes(colour = ref), size = 1.9) +
  facet_wrap(~dsl, nrow = 1) +
  scale_colour_manual(values = setNames(PAIR_COLORS, levels(gain_long$ref)), name = "Gain") +
  guides(colour = guide_legend(nrow = 2)) +
  scale_x_continuous(breaks = c(-0.5, 0, 0.3), labels = c("-0.5", "0", "0.3")) +
  labs(x = "ROC-AUC gain", y = NULL) +
  theme_messi(9) + class_axis_y(levels(gain_long$method)) +
  theme(legend.position = "bottom", legend.title = element_text(size = 8), legend.text = element_text(size = 8),
        strip.text = element_text(size = 7, face = "bold"))
saveRDS(pC_gain, file.path(OUT, "figure_sc_gain_panel.rds"))

# ---- ranks per sc dataset (1 = best pooled ROC-AUC) ----------------------------
rk <- pooled %>% group_by(dataset) %>% mutate(rank = rank(-roc_auc, ties.method = "average")) %>% ungroup()
sc_rank <- rk %>% group_by(label, class) %>% summarise(sc_rank = mean(rank), n_ds = n(), .groups = "drop")
bulk_rank <- read_csv(here::here("data/processed/benchmark_stats/tables/mean_ranks_roc_auc_dataset_level.csv"),
                      show_col_types = FALSE) %>% rename(label = method_name, bulk_rank = mean_rank)
rk_cmp <- sc_rank %>% inner_join(bulk_rank, by = "label")
stopifnot(nrow(rk_cmp) == nrow(sc_rank))
rho <- cor(rk_cmp$sc_rank, rk_cmp$bulk_rank, method = "spearman")
rho_noMOG <- with(filter(rk_cmp, label != "MOGONET"), cor(sc_rank, bulk_rank, method = "spearman"))
write_csv(rk %>% select(label, class, dataset, roc_auc, rank), file.path(OUT, "sc_ranks_per_dataset.csv"))
write_csv(rk_cmp %>% mutate(spearman_rho = rho, spearman_rho_without_MOGONET = rho_noMOG),
          file.path(OUT, "sc_vs_bulk_rank.csv"))
cat(sprintf("\nSpearman rho sc vs bulk mean rank: %.2f (without MOGONET %.2f)\n", rho, rho_noMOG))

# ---- D: sc vs bulk rank scatter ---------------------------------------------------
n_bulk <- 26L   # bulk dataset-level ranks come from the bulk table (26 datasets)
pD_rank <- ggplot(rk_cmp, aes(bulk_rank, sc_rank)) +
  geom_abline(slope = 1, intercept = 0, linetype = REF_LINE$linetype, colour = REF_LINE$colour, linewidth = REF_LINE$linewidth) +
  geom_point(aes(colour = class), size = 2) +
  ggrepel::geom_text_repel(aes(label = ifelse(label == "MOGONET", "MOGONET*", label), colour = class),
                           size = 2.6, max.overlaps = Inf, box.padding = 0.3, point.padding = 0.2, force = 6,
                           min.segment.length = 0.2, segment.size = 0.25, seed = 2, show.legend = FALSE) +
  annotate("text", x = 10.4, y = 1, hjust = 0, vjust = 1, size = 2.9,
           label = sprintf("Spearman ρ = %.2f", rho)) +
  scale_colour_class(guide = "none") +
  scale_y_reverse(limits = c(11, 1), breaks = c(2, 4, 6, 8, 10)) +
  scale_x_reverse(limits = c(10.5, 1), breaks = c(2, 4, 6, 8, 10)) +
  labs(x = "Bulk mean rank (26 datasets)", y = "Single-cell mean rank") +
  theme_messi(9) + theme(plot.tag.location = "margin")
saveRDS(pD_rank, file.path(OUT, "figure_sc_rank_vs_bulk_panel.rds"))

# ---- E: bump chart of ranks across the 3 sc datasets ---------------------------------
HL <- c("Logistic", "DIABLO-N", "Random Forest", "XGBoost")
HL_COL <- c(Logistic = "#2B6A9F", `DIABLO-N` = "#D68A2A", `Random Forest` = "#08306B", XGBoost = "#6BAED6")
bump <- rk %>% mutate(x = match(dataset, SC_DATASETS), hl = label %in% HL,
                      grp = ifelse(hl, label, "other"))
pE_bump <- ggplot(bump, aes(x, rank, group = label)) +
  geom_line(data = filter(bump, !hl), colour = "grey85", linewidth = 0.5) +
  geom_point(data = filter(bump, !hl), colour = "grey80", size = 1.2) +
  geom_line(data = filter(bump, hl), aes(colour = label), linewidth = 0.9) +
  geom_point(data = filter(bump, hl), aes(colour = label), size = 1.9) +
  ggrepel::geom_text_repel(data = filter(bump, hl, x == 3), aes(label = label, colour = label), hjust = 0,
                           nudge_x = 0.12, direction = "y", size = 2.6, segment.size = 0.2, min.segment.length = 0.3,
                           box.padding = 0.08, seed = 1) +
  scale_colour_manual(values = HL_COL, guide = "none") +
  scale_y_reverse(breaks = c(1, 3, 5, 7, 9, 11), expand = expansion(add = 0.7)) +
  coord_cartesian(clip = "off") +
  scale_x_continuous(breaks = 1:3, labels = unname(DS_SHORT),
                     expand = expansion(add = c(0.15, 1.25))) +
  labs(x = NULL, y = "Rank (1 = best)", subtitle = "RF/XGBoost: top 2 on COVID organ → last 2 on HTX") +
  theme_messi(9) + theme(panel.grid.minor = element_blank(), plot.tag.location = "margin",
                         plot.subtitle = element_text(size = 8, face = "bold", colour = "grey20"))   # callout style (8 pt bold grey20)
saveRDS(pE_bump, file.path(OUT, "figure_sc_rank_bump_panel.rds"))

# ---- F: cost, one point per method x dataset (median over the 5 folds) ----------
cost_md <- cost %>% group_by(label, dataset, ds) %>%
  summarise(time_s = median(time_s), mem_gib = median(mem_gib), .groups = "drop")
write_csv(cost_md, file.path(OUT, "sc_cost_median_per_dataset.csv"))
cost_md_long <- cost_md %>% pivot_longer(c(time_s, mem_gib), names_to = "metric") %>%
  mutate(metric = factor(COST_LAB[metric], levels = COST_LAB), method = method_factor_y(label))
pF_cost <- ggplot(cost_md_long, aes(value, method)) +
  geom_line(aes(group = method), colour = "grey85", linewidth = 0.5) +
  geom_point(aes(colour = ds), size = 1.8) +
  facet_wrap(~metric, nrow = 1, scales = "free_x") +
  scale_x_log10(labels = function(x) format(x, drop0trailing = TRUE, scientific = FALSE, trim = TRUE)) +
  scale_colour_manual(values = SC_DS_COLORS, name = NULL) +
  labs(x = "Median per fold (log scale)", y = NULL) +
  theme_messi(9) + class_axis_y(levels(cost_md_long$method)) +
  theme(legend.position = "right", legend.text = element_text(size = 8), legend.key.size = unit(3, "mm"))
saveRDS(pF_cost, file.path(OUT, "figure_sc_cost_median_panel.rds"))
message("[done] Fig 5 v3 panels -> ", OUT)

# ============================================================================ #
# Fig 5 panels: B pooled ROC-AUC heatmap, C gain diverging bars.
# (D bump chart and E sc-vs-bulk scatter are built above; cost -> supplementary.)
# ============================================================================ #
AUC_LOW <- "#2166AC"; AUC_MID <- "#F7F7F7"; AUC_HIGH <- "#B2182B"   # same as Fig 4/6/8 AUC heatmaps
hdr_lab <- setNames(sprintf("%s\n%d / %d pos", DS_SHORT[hdr$dataset], hdr$n, hdr$n_pos), hdr$dataset)
lv_m <- levels(pooled$method)
heat <- tidyr::expand_grid(method = factor(lv_m, levels = lv_m), dataset = SC_DATASETS) %>%
  left_join(pooled %>% transmute(method = factor(as.character(method), levels = lv_m), dataset, roc_auc),
            by = c("method", "dataset")) %>%
  mutate(col = factor(hdr_lab[dataset], levels = hdr_lab[SC_DATASETS]),
         lab = ifelse(is.na(roc_auc), "NA", sprintf("%.2f", roc_auc)),
         txt_col = ifelse(!is.na(roc_auc) & abs(roc_auc - 0.5) > 0.3, "white", "black"))
pB_heat <- ggplot(heat, aes(col, method)) +
  geom_tile(aes(fill = roc_auc), colour = "white", linewidth = 0.6) +
  geom_text(aes(label = lab, colour = txt_col), size = 2.9) +
  scale_colour_identity() +
  scale_fill_gradient2(low = AUC_LOW, mid = AUC_MID, high = AUC_HIGH, midpoint = 0.5, limits = c(0, 1),
                       breaks = c(0, 0.5, 1), na.value = "grey92", name = "Pooled ROC-AUC",
                       guide = guide_colourbar(barwidth = unit(30, "mm"), barheight = unit(2.4, "mm"), title.vjust = 0.9,
                                               title.position = "left")) +
  scale_x_discrete(position = "top", expand = c(0, 0)) + scale_y_discrete(expand = c(0, 0)) +
  labs(x = NULL, y = NULL) +
  theme_messi(9) + class_axis_y(lv_m) +
  theme(panel.grid = element_blank(), axis.ticks = element_blank(),
        axis.text.x.top = element_text(size = 8, lineheight = 0.9, face = "bold"),
        legend.position = "bottom")
saveRDS(pB_heat, file.path(OUT, "figure_sc_pooled_roc_heatmap.rds"))

# C: diverging bars = gain vs BEST single view; dot = gain vs MEAN single view
REF_LAB <- c(best = "vs best single view (bar)", mean = "vs mean single view (dot)")
gC <- gain %>% mutate(method = factor(label, levels = lv_m),
                      dsl = factor(DS_SHORT[dataset], levels = DS_SHORT))
pC_bar <- ggplot(gC, aes(y = method)) +
  geom_col(aes(x = gain_best, fill = "best"), width = 0.7) +
  geom_vline(xintercept = 0, linetype = REF_LINE$linetype, colour = REF_LINE$colour, linewidth = REF_LINE$linewidth) +
  geom_point(aes(x = gain_mean, colour = "mean"), size = 1.7) +
  facet_wrap(~dsl, nrow = 1) +
  scale_fill_manual(values = c(best = PAIR_COLORS[2]), labels = REF_LAB["best"], name = NULL) +
  scale_colour_manual(values = c(mean = PAIR_COLORS[1]), labels = REF_LAB["mean"], name = NULL) +
  scale_x_continuous(limits = c(-0.68, 0.3), breaks = c(-0.5, -0.25, 0, 0.25), labels = c("-0.5", "", "0", "")) +
  scale_y_discrete(drop = FALSE) +
  labs(x = "ROC-AUC gain over single-view Logistic", y = NULL) +
  theme_messi(9) +
  theme(axis.text.y = element_blank(), axis.ticks.y = element_blank(), panel.grid.major.y = element_blank(),
        strip.text = element_text(size = 8, face = "bold", lineheight = 0.9),
        legend.position = "bottom", legend.box = "horizontal",
        legend.margin = margin(0, 0, 0, 0), legend.spacing.x = unit(1, "mm"))
saveRDS(pC_bar, file.path(OUT, "figure_sc_gain_bars.rds"))

# Cost (supplementary): per-dataset medians, standalone
save_plot_both(pF_cost + labs(title = "Single-cell computational cost per dataset",
                              caption = "Median over the 5 folds of the training task's wall time and peak memory (Nextflow trace).") +
                 theme(plot.caption = element_text(hjust = 0, size = 7.5, colour = "grey30"), plot.caption.position = "plot",
                       legend.position = "bottom"),
               file.path(OUT, "figure_sc_cost_per_dataset.png"), width = 7, height = 3.6, dpi = 300)
message("[done] Fig 5 v4 panels -> ", OUT)
write_csv(facts, file.path(OUT, "sc_dataset_facts.csv"))
print(as.data.frame(facts))
message("[done] single-cell panels -> ", OUT)
