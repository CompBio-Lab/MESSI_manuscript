# ==============================================================================
# integration_gain.R  -- SINGLE SOURCE OF TRUTH
# "How much of the improvement is due to the integration?"
#
# For every multimodal dataset, each multimodal method is compared against a
# single-modality baseline = logistic regression (sklearn-Logit, default settings)
# fitted on ONE view at a time (the pipeline's per-view child datasets, e.g.
# momix-aml -> momix-aml-{exp,methy,mirna}). Two references per dataset x metric:
#   *_singlemod_best = max over views   ("best single modality", stringent: picked post hoc)
#   *_singlemod_mean = mean over views  ("average single modality")
# gain      = metric(multimodal) - best single modality
# gain_mean = metric(multimodal) - mean single modality
# Metrics are POOLED out-of-fold metrics (same as process_benchmark_stats.R).
#
# This file is the ONLY place the integration deltas are computed.
# `single_modality_baseline.R` reads integration_gain.csv and only plots.
#
# Also computes the exploratory "gain vs view spread" analysis (Fig. 3):
#   spread = best single-view ROC-AUC - mean single-view ROC-AUC (per dataset).
#   NOTE: gain_vs_best = gain_vs_mean - spread exactly, so a negative correlation of
#   gain_vs_best with spread is partly arithmetic; the informative test is gain_vs_mean.
#
# Outputs (data/processed/benchmark_stats/tables/):
#   integration_gain.csv          per method (all variants) x dataset, ROC/PR/F1, both refs
#   integration_gain_tests.csv    one-sample Wilcoxon of gain vs 0 per method, Holm
#   integration_gain_summary.csv  median gain + win rate per method
#   integration_singlemod_ref.csv per dataset: n views, best/mean/min single view, spread
#   integration_gain_vs_spread.csv  Spearman rho tables (exploratory)
# Figures: results/benchmark_stats/integration_gain_{roc_auc,pr_auc}.png (dual reference)
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(tibble); library(ggplot2); library(here)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, d = NULL) { i <- which(args == flag); if (length(i) == 1 && i < length(args)) args[i + 1] else d }
pred_path   <- get_arg("--pred", NULL)   # optional single-file override; default = all runs
outdir_proc <- get_arg("--outdir_proc", here::here("data/processed/benchmark_stats"))
outdir_fig  <- get_arg("--outdir_fig",  here::here("results/benchmark_stats"))
TBL <- file.path(outdir_proc, "tables")
dir.create(TBL, recursive = TRUE, showWarnings = FALSE)
dir.create(outdir_fig, recursive = TRUE, showWarnings = FALSE)

is_sklearn <- function(m) str_detect(m, "^sklearn")
GAIN_METRICS <- c("roc_auc", "pr_auc", "f1_score")
SINGLE_MOD_METHOD <- "sklearn-Logit-empty"
# main-text method set = representatives (process_benchmark_stats.R) + all others
REPRESENTATIVE <- c("diablo-null_ncomp-2", "rgcca-full_ncomp-2")

# ------------------------------------------------------------------ load + pooled metrics (all datasets)
pred <- if (is.null(pred_path))
  read_runs("all_langs-result.csv") %>% distinct(sample_name, y, phat, method_name, dataset, fold) else
  read_csv(pred_path, show_col_types = FALSE)
pooled_all <- compute_pooled_metrics(pred)

mm <- pred %>% group_by(dataset) %>%
  summarise(n_int = sum(!is_sklearn(unique(method_name))), .groups = "drop") %>%
  filter(n_int > 0) %>% pull(dataset)
if (is.null(pred_path)) stopifnot("expected 26 multimodal datasets" = length(mm) == 26)
children_of <- function(D) {
  cand <- setdiff(unique(pooled_all$dataset), mm)
  cand[str_starts(cand, paste0(D, "-"))]
}
child_map <- setNames(lapply(mm, children_of), mm)
message(sprintf("[integration gain] %d multimodal datasets; %d with >=1 single-modality child",
                length(mm), sum(lengths(child_map) > 0)))

# ------------------------------------------------------------------ single-modality reference
single_view <- bind_rows(lapply(mm, function(D) {
  ch <- child_map[[D]]; if (length(ch) == 0) return(NULL)
  pooled_all %>% filter(dataset %in% ch, method_name == SINGLE_MOD_METHOD) %>%
    transmute(parent = D, view = str_remove(dataset, paste0("^", D, "-")),
              across(all_of(GAIN_METRICS)))
}))
singlemod_ref <- single_view %>% group_by(dataset = parent) %>%
  summarise(n_views = n(),
            across(all_of(GAIN_METRICS),
                   list(best = ~ max(.x, na.rm = TRUE), mean = ~ mean(.x, na.rm = TRUE),
                        min = ~ min(.x, na.rm = TRUE)),
                   .names = "{.col}_singlemod_{.fn}"),
            best_view_roc = view[which.max(roc_auc)], .groups = "drop") %>%
  mutate(roc_auc_spread = roc_auc_singlemod_best - roc_auc_singlemod_mean,
         pr_auc_spread  = pr_auc_singlemod_best - pr_auc_singlemod_mean)
write_csv(singlemod_ref, file.path(TBL, "integration_singlemod_ref.csv"))
write_csv(single_view, file.path(TBL, "integration_single_view_scores.csv"))

# ------------------------------------------------------------------ gain per multimodal method
gain <- pooled_all %>% filter(dataset %in% singlemod_ref$dataset) %>%
  select(method_raw = method_name, dataset, all_of(GAIN_METRICS)) %>%
  inner_join(singlemod_ref %>% select(dataset, n_views, ends_with("_best"), ends_with("_mean"),
                                      roc_auc_spread),
             by = "dataset") %>%
  mutate(method_name = bench_label(method_raw, collapse = FALSE),
         method_class = bench_class(method_raw),
         main_text = !(method_raw %in% unlist(BENCH_FAMILIES)) | method_raw %in% REPRESENTATIVE,
         .before = 1)
gain$method_name[gain$main_text] <- bench_label(gain$method_raw[gain$main_text], collapse = TRUE)
for (m in GAIN_METRICS) {
  gain[[paste0(m, "_gain")]]      <- gain[[m]] - gain[[paste0(m, "_singlemod_best")]]
  gain[[paste0(m, "_gain_mean")]] <- gain[[m]] - gain[[paste0(m, "_singlemod_mean")]]
}
write_csv(gain, file.path(TBL, "integration_gain.csv"))

# ------------------------------------------------------------------ significance (one-sample Wilcoxon vs 0, Holm)
# Holm family = the 11 main-text methods within each metric x reference.
gain_long <- gain %>% filter(main_text) %>%
  select(method_name, method_class, dataset, ends_with("_gain"), ends_with("_gain_mean")) %>%
  pivot_longer(-c(method_name, method_class, dataset), names_to = "key", values_to = "gain") %>%
  mutate(metric = str_extract(key, paste(GAIN_METRICS, collapse = "|")),
         reference = if_else(str_detect(key, "_mean$"), "vs mean modality", "vs best modality"))
gain_tests <- gain_long %>%
  group_by(method_name, method_class, metric, reference) %>%
  summarise(n = sum(!is.na(gain)),
            median_gain = median(gain, na.rm = TRUE),
            mean_gain = mean(gain, na.rm = TRUE),
            q25 = quantile(gain, 0.25, na.rm = TRUE), q75 = quantile(gain, 0.75, na.rm = TRUE),
            wins = sum(gain > 0, na.rm = TRUE),
            win_rate = mean(gain > 0, na.rm = TRUE),
            p = tryCatch(suppressWarnings(wilcox.test(gain, mu = 0)$p.value),
                         error = function(e) NA_real_),
            .groups = "drop") %>%
  group_by(metric, reference) %>%
  mutate(p_holm = p.adjust(p, method = "holm")) %>%
  ungroup() %>% arrange(metric, reference, desc(median_gain))
write_csv(gain_tests, file.path(TBL, "integration_gain_tests.csv"))
message("[integration gain] ROC-AUC, Holm < 0.05:")
print(as.data.frame(gain_tests %>% filter(metric == "roc_auc") %>%
  select(method_name, reference, median_gain, wins, n, p_holm)))

gain_summary <- gain %>% group_by(method_name, main_text) %>%
  summarise(across(c(ends_with("_gain"), ends_with("_gain_mean")),
                   list(median = ~ median(.x, na.rm = TRUE),
                        frac_pos = ~ mean(.x > 0, na.rm = TRUE)), .names = "{.col}_{.fn}"),
            n = n(), .groups = "drop") %>%
  arrange(desc(roc_auc_gain_median))
write_csv(gain_summary, file.path(TBL, "integration_gain_summary.csv"))

# ------------------------------------------------------------------ exploratory: gain vs view spread
# Integrators = non-sklearn main-text methods. "best integrator" = per-dataset max over
# them (post-hoc selection -> optimistic; reported only as a sensitivity).
integ <- gain %>% filter(main_text, method_class != "Early")
best_int <- integ %>% group_by(dataset) %>% slice_max(roc_auc, n = 1, with_ties = FALSE) %>%
  ungroup() %>% mutate(method_name = "Best integrator (per dataset)")
spread_df <- bind_rows(integ, best_int, gain %>% filter(method_raw == "sklearn-Logit-empty"))
rho_tbl <- spread_df %>% group_by(method_name) %>%
  group_modify(~ {
    f <- function(x, y) {
      ct <- suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE))
      c(rho = unname(ct$estimate), p = ct$p.value)
    }
    bind_rows(
      tibble(x = "spread", y = "gain vs best",  !!!as.list(f(.x$roc_auc_spread, .x$roc_auc_gain))),
      tibble(x = "spread", y = "gain vs mean",  !!!as.list(f(.x$roc_auc_spread, .x$roc_auc_gain_mean))),
      tibble(x = "best single view", y = "gain vs best", !!!as.list(f(.x$roc_auc_singlemod_best, .x$roc_auc_gain))),
      tibble(x = "best single view", y = "gain vs mean", !!!as.list(f(.x$roc_auc_singlemod_best, .x$roc_auc_gain_mean))),
      tibble(x = "n views", y = "gain vs best", !!!as.list(f(.x$n_views, .x$roc_auc_gain))))
  }) %>% ungroup() %>% mutate(n = length(unique(gain$dataset)))
# Arithmetic null for rho(spread, gain vs best): permute gain_vs_mean across datasets
# (breaks any real link with spread), rebuild gain_vs_best = gain_vs_mean - spread, and
# recompute rho. If the observed rho sits inside this null, the vs-best correlation is
# explained by the identity alone.
set.seed(1)
null_tbl <- spread_df %>% group_by(method_name) %>%
  summarise(rho_obs = cor(roc_auc_spread, roc_auc_gain, method = "spearman"),
            rho_null = list(replicate(5000, {
              gm <- sample(roc_auc_gain_mean)
              cor(roc_auc_spread, gm - roc_auc_spread, method = "spearman")
            })), .groups = "drop") %>%
  mutate(rho_null_median = sapply(rho_null, median),
         rho_null_lo = sapply(rho_null, quantile, 0.025),
         rho_null_hi = sapply(rho_null, quantile, 0.975),
         p_vs_null = mapply(function(o, nl) mean(abs(nl - median(nl)) >= abs(o - median(nl))),
                            rho_obs, rho_null)) %>%
  select(-rho_null)
rho_tbl <- rho_tbl %>% left_join(null_tbl %>% mutate(x = "spread", y = "gain vs best"),
                                 by = c("method_name", "x", "y"))
write_csv(rho_tbl, file.path(TBL, "integration_gain_vs_spread.csv"))
message("[gain vs spread] Spearman rho (ROC-AUC):")
print(as.data.frame(rho_tbl %>% filter(x == "spread") %>% mutate(across(c(rho, p), ~ signif(.x, 2)))))

# ------------------------------------------------------------------ figure (dual reference)
plot_gain <- function(metric) {
  ml <- c(roc_auc = "ROC-AUC", pr_auc = "PR-AUC", f1_score = "F1")[metric]
  d <- gain_long %>% filter(metric == !!metric) %>%
    mutate(reference = factor(reference, levels = c("vs mean modality", "vs best modality")))
  ord <- d %>% filter(reference == "vs mean modality") %>% group_by(method_name) %>%
    summarise(m = median(gain, na.rm = TRUE)) %>% arrange(m) %>% pull(method_name)
  d <- d %>% mutate(method_name = factor(method_name, levels = ord))
  st <- gain_tests %>% filter(metric == !!metric) %>%
    mutate(method_name = factor(method_name, levels = ord),
           reference = factor(reference, levels = levels(d$reference)),
           lab = sprintf("%d/%d%s", wins, n, ifelse(p_holm < 0.05, "*", "")))
  ggplot(d, aes(gain, method_name)) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
    geom_jitter(aes(color = method_class), height = 0.18, width = 0, alpha = 0.45, size = 1.1) +
    geom_point(data = st, aes(x = median_gain), shape = 18, size = 3, color = "black") +
    geom_text(data = st, aes(x = Inf, label = lab), hjust = 1.05, size = 2.6) +
    facet_wrap(~ reference) +
    scale_color_manual(values = BENCH_CLASS_COLORS, name = NULL) +
    labs(title = sprintf("Integration gain (%s) over single-modality logistic regression", ml),
         subtitle = sprintf("%d datasets; diamond = median; label = wins/datasets (* Holm p < 0.05, Wilcoxon vs 0)",
                            length(unique(d$dataset))),
         x = sprintf("Δ %s (multimodal − single modality)", ml), y = NULL) +
    theme_minimal(base_size = 10) +
    theme(panel.grid.minor = element_blank(), legend.position = "bottom",
          plot.title = element_text(face = "bold"), axis.text = element_text(color = "black"),
          strip.text = element_text(face = "bold"))
}
for (m in c("roc_auc", "pr_auc"))
  save_plot_both(plot_gain(m), file.path(outdir_fig, paste0("integration_gain_", m, ".png")),
                 width = 8, height = 5, dpi = 300)
message("[done] integration gain tables + figures written")
