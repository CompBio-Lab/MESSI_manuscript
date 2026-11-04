# ==============================================================================
# process_benchmark_stats.R
# Compute step for the benchmark statistics. Reads sample-level
# out-of-fold predictions + pipeline metrics, filters to the multimodal datasets,
# computes fold/pooled metrics and all statistical comparisons, cross-checks the
# pooled metrics against the pipeline metrics.csv, and writes tidy CSV tables plus
# a single plot_data_list.rds consumed by plot_benchmark_stats.R.
#
# Usage:
#   Rscript src/benchmark_stats/process_benchmark_stats.R \
#     --pred  data/raw/<run>/all_langs-result.csv \
#     --metrics data/raw/<run>/metrics.csv \
#     --outdir data/processed/benchmark_stats
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(tibble); library(here)
})
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))

# ------------------------------------------------------------------ args
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  i <- which(args == flag)
  if (length(i) == 1 && i < length(args)) args[i + 1] else default
}
pred_path    <- get_arg("--pred",    NULL)   # optional single-file overrides
metrics_path <- get_arg("--metrics", NULL)
outdir       <- get_arg("--outdir",  here::here("data/processed/benchmark_stats"))
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
tbl_dir <- file.path(outdir, "tables"); dir.create(tbl_dir, showWarnings = FALSE)

# Display labels are shared with the plotting + gain scripts (benchmark_stats_utils.R).
label_of <- function(m) bench_label(m, collapse = TRUE)
is_sklearn <- function(m) str_detect(m, "^sklearn")

# ------------------------------------------------------------------ load + filter
# Load across all pipeline runs (bulk + multimodal + any future samplesheet),
# unless a single file is forced via --pred / --metrics.
if (is.null(pred_path)) {
  pred_all <- read_runs("all_langs-result.csv") %>% distinct(sample_name, y, phat, method_name, dataset, fold)
  met_all  <- read_runs("metrics.csv") %>% distinct(method_name, dataset, .keep_all = TRUE)
  message(sprintf("[runs] loaded %d run(s): %s", length(messi_runs()),
                  paste(basename(messi_runs()), collapse = ", ")))
} else {
  pred_all <- read_csv(pred_path, show_col_types = FALSE)
  met_all  <- read_csv(metrics_path, show_col_types = FALSE)
}

# Multimodal datasets = those with >=1 non-sklearn (integration) method.
mm_datasets <- pred_all %>% group_by(dataset) %>%
  summarise(n_int = sum(!is_sklearn(unique(method_name))), .groups = "drop") %>%
  filter(n_int > 0) %>% pull(dataset)
if (is.null(pred_path)) stopifnot("expected 26 multimodal datasets" = length(mm_datasets) == 26)
pred <- pred_all %>% filter(dataset %in% mm_datasets)
met  <- met_all  %>% filter(dataset %in% mm_datasets)
message(sprintf("[filter] %d multimodal datasets, %d methods, %d prediction rows",
                length(mm_datasets), dplyr::n_distinct(pred$method_name), nrow(pred)))

# ------------------------------------------------------------------ 1. metrics
# Fold labels are canonicalised first: the fold-level rank tables below use dataset x fold as paired blocks.
fold_m <- compute_fold_metrics(canonicalise_folds(pred))
pooled <- compute_pooled_metrics(pred)
write_csv(fold_m, file.path(tbl_dir, "fold_level_metrics.csv"))
write_csv(pooled, file.path(tbl_dir, "pooled_metrics.csv"))

# cross-check pooled ROC-AUC (and the other shared metrics) vs pipeline metrics.csv
cc <- pooled %>% select(method_name, dataset, roc_auc, pr_auc, f1_score,
                        matthews_corrcoef, balanced_accuracy) %>%
  inner_join(met %>% select(method_name, dataset, roc_auc, pr_auc, f1_score,
                            matthews_corrcoef, balanced_accuracy),
             by = c("method_name", "dataset"), suffix = c("_r", "_pipe"))
cc_diff <- sapply(c("roc_auc", "pr_auc", "f1_score", "matthews_corrcoef", "balanced_accuracy"),
                  function(m) max(abs(cc[[paste0(m, "_r")]] - cc[[paste0(m, "_pipe")]]), na.rm = TRUE))
message("[cross-check] max |R - pipeline| per metric:")
print(round(cc_diff, 5))
write_csv(tibble(metric = names(cc_diff), max_abs_diff = cc_diff),
          file.path(tbl_dir, "crosscheck_vs_pipeline.csv"))

# ------------------------------------------------------------------ 2. representatives -> main method set
sel <- select_representatives(pooled)
write_csv(sel$detail, file.path(tbl_dir, "representative_selection.csv"))
message("[representatives] ", paste(names(sel$reps), unlist(sel$reps), sep = "=", collapse = ", "))

family_variants <- unlist(BENCH_FAMILIES, use.names = FALSE)
keep_raw <- c(unlist(sel$reps, use.names = FALSE),
              setdiff(unique(pred$method_name), family_variants))
# order best-first by dataset-level (pooled) roc_auc mean rank (matches reference)
pooled_rank_roc <- colMeans(rank_table(pooled, "roc_auc"), na.rm = TRUE)
keep_raw <- keep_raw[order(pooled_rank_roc[keep_raw])]
labels <- unname(label_of(keep_raw))

relabel <- function(df) df %>% filter(method_name %in% keep_raw) %>%
  mutate(method_name = factor(label_of(method_name), levels = labels))
pooled7 <- relabel(pooled); fold7 <- relabel(fold_m); pred7 <- relabel(pred)
write_csv(fold7, file.path(tbl_dir, "fold_level_metrics_7methods.csv"))
message("[main methods] ", paste(labels, collapse = ", "))

# ------------------------------------------------------------------ 3. Friedman + Nemenyi
stat_metrics <- c("roc_auc", "pr_auc", "matthews_corrcoef", "balanced_accuracy")
# Two levels (Demsar 2006):
#   dataset_level = blocks are the 26 datasets (pooled OOF metric) -> MAIN-TEXT CD (CD ~ 2.96)
#   fold_level    = blocks are dataset x fold (130)                -> supplementary CD (CD ~ 1.32);
#                   folds of one dataset are not independent, so this CD is optimistic.
fn_rows <- list(); mean_ranks_list <- list(); cd_fold <- list()
mean_ranks_ds <- list(); cd_ds <- list()
for (metric in stat_metrics) {
  for (scope in c("fold_level", "dataset_level")) {
    df <- if (scope == "fold_level") fold7 else pooled7
    fr <- friedman_nemenyi(rank_table(df, metric))
    fn_rows[[length(fn_rows) + 1]] <- tibble(
      metric = metric, scope = scope, chi2 = fr$chi2, p = fr$p,
      kendall_w = fr$kendall_w, cd = fr$cd, n_blocks = fr$n_blocks, k_methods = fr$k)
    mr <- tibble(method_name = names(fr$mean_ranks), mean_rank = as.numeric(fr$mean_ranks))
    if (scope == "fold_level") {
      write_csv(mr, file.path(tbl_dir, paste0("mean_ranks_", metric, ".csv")))
      mean_ranks_list[[metric]] <- fr$mean_ranks
      cd_fold[[metric]] <- fr$cd
    } else {
      write_csv(mr, file.path(tbl_dir, paste0("mean_ranks_", metric, "_dataset_level.csv")))
      mean_ranks_ds[[metric]] <- fr$mean_ranks
      cd_ds[[metric]] <- fr$cd
    }
  }
}
write_csv(bind_rows(fn_rows), file.path(tbl_dir, "friedman_nemenyi.csv"))

# ------------------------------------------------------------------ 4. DeLong (per dataset vs best)
dl <- delong_all_datasets(pred7 %>% mutate(method_name = as.character(method_name)), labels)
write_csv(dl, file.path(tbl_dir, "delong_vs_dataset_best.csv"))
message(sprintf("[DeLong] %d tests, %d significant (BH-FDR < 0.05)", nrow(dl), sum(dl$p_fdr < 0.05)))

# ------------------------------------------------------------------ 5. Wilcoxon + win/tie/loss + bootstrap
wil <- bind_rows(lapply(stat_metrics, function(m) pairwise_wilcoxon(pooled7, m, labels)))
write_csv(wil, file.path(tbl_dir, "wilcoxon_holm.csv"))
wtl <- bind_rows(lapply(c("roc_auc", "pr_auc"), function(m) win_tie_loss(pooled7, m, labels)))
write_csv(wtl, file.path(tbl_dir, "win_tie_loss.csv"))
top <- labels[1]
boot <- bind_rows(lapply(c("roc_auc", "pr_auc"), function(m)
  bind_rows(lapply(setdiff(labels, top), function(meth)
    bootstrap_delta_ci(pooled7, m, meth, top)))))
write_csv(boot, file.path(tbl_dir, "bootstrap_delta_ci.csv"))

# ------------------------------------------------------------------ 6. degenerate / no-signal / calibration
deg <- degenerate_rows(pooled, pred)
write_csv(deg, file.path(tbl_dir, "degenerate_classifiers.csv"))
fmt_deg <- function(d, total) sprintf("%d of %d (%d all-negative, %d all-positive)", nrow(d), total,
                                      sum(d$degenerate == "all-negative"), sum(d$degenerate == "all-positive"))
message("[single-class] all variants: ", fmt_deg(deg, nrow(pooled)),
        "; main methods: ", fmt_deg(filter(deg, method_name %in% keep_raw), nrow(pooled7)))
ns <- pooled7 %>% group_by(dataset) %>% summarise(max_roc = max(roc_auc), .groups = "drop")
no_signal <- ns %>% filter(max_roc < 0.6) %>% pull(dataset)
message("[no-signal] datasets (all methods ROC-AUC < 0.6): ", paste(sort(no_signal), collapse = ", "))
calib <- calibration_by_method_dataset(pred7 %>% mutate(method_name = as.character(method_name)), labels)
write_csv(calib$summary, file.path(tbl_dir, "calibration_summary.csv"))

# ------------------------------------------------------------------ bundle for plotting
plot_data_list <- list(
  labels = labels, keep_raw = keep_raw,
  mm_datasets = mm_datasets, no_signal = no_signal,
  pooled7 = pooled7, fold7 = fold7,
  mean_ranks = mean_ranks_list, cd_fold = cd_fold,          # fold-level (supplementary)
  mean_ranks_ds = mean_ranks_ds, cd_ds = cd_ds,              # dataset-level (main text)
  friedman = bind_rows(fn_rows),
  delong = dl, wilcoxon = wil, win_tie_loss = wtl, bootstrap = boot,
  degenerate = deg, calibration = calib,
  representatives = sel$detail, crosscheck = cc_diff)
saveRDS(plot_data_list, file.path(outdir, "benchmark_stats_plot_data.rds"))
message("[done] wrote tables + rds to ", outdir)
