# ==============================================================================
# process_cost.R  (computational complexity / efficiency)
# Parses the Nextflow execution_trace.txt into a per-(method, dataset, stage)
# cost table (runtime seconds + peak memory GiB, median across folds/variants),
# joins dataset size (n subjects, p features) and benchmark performance, and
# fits observational runtime scaling exponents. Reuses the repo's existing trace
# parser (src/common_helpers/computational_resources_utils.R).
#
# Usage:
#   Rscript src/cost/process_cost.R \
#     --run data/raw/<run> --outdir data/processed/cost
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(tibble); library(here)
})
source(here::here("src/common_helpers/computational_resources_utils.R"))  # convert_to_seconds/_mb
source(here::here("src/benchmark_stats/benchmark_stats_utils.R"))          # compute_pooled_metrics, bench_label

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, d = NULL) { i <- which(args == flag); if (length(i) == 1 && i < length(args)) args[i + 1] else d }
run    <- get_arg("--run", NULL)   # optional single-run override; default = all runs
outdir <- get_arg("--outdir", here::here("data/processed/cost"))
runs <- if (is.null(run)) messi_runs() else run
message(sprintf("[runs] %d run(s): %s", length(runs), paste(basename(runs), collapse = ", ")))
dir.create(file.path(outdir, "tables"), recursive = TRUE, showWarnings = FALSE)

# Nextflow process prefix -> raw pipeline method key (labels come from method_labels.R)
METHOD_PREFIX <- c(DIABLO = "diablo", RGCCA = "rgcca", CARET_MULTIMODAL = "caret_multimodal",
                   COOPERATIVE_LEARNING = "cooperative_learning", INTEGRAO = "integrao",
                   MOFA = "mofa", MOGONET = "mogonet")
REPRESENTATIVE <- c("diablo-null_ncomp-2", "rgcca-full_ncomp-2")   # as in process_benchmark_stats.R
STAGE_MAP <- c(TRAIN = "Training", SELECT_FEATURE = "Model selection")

# ------------------------------------------------------------------ parse trace (across all runs)
trace <- bind_rows(lapply(runs, function(d) {
  f <- file.path(d, "execution_trace.txt")
  if (file.exists(f)) suppressWarnings(read_tsv(f, show_col_types = FALSE)) else NULL
})) %>%
  mutate(leaf = str_extract(chop_nf_core_prefix(process), "[^:]+$"),
         m_prefix = str_extract(leaf, "^[A-Z_]+(?=_(TRAIN|SELECT_FEATURE|PREDICT|PREPROCESS)$)"),
         stage_raw = str_extract(leaf, "(TRAIN|SELECT_FEATURE|PREDICT|PREPROCESS)$"),
         cand = str_remove(tag, "-fold_.*$"),           # clean for per-fold stages
         time_s = convert_to_seconds(realtime),
         mem_gib = convert_to_mb(peak_rss) / 1024) %>%
  filter(!is.na(m_prefix), stage_raw %in% c("TRAIN", "SELECT_FEATURE"))

# raw method key: sklearn carries its classifier in the tag (after -fold_N-); DIABLO/RGCCA carry
# design_{full,null} + ncomp_K, so each variant is costed separately (DIABLO-N = design_null, ncomp 2).
trace <- trace %>%
  mutate(design = str_match(tag, "design_(full|null)")[, 2],
         ncomp  = str_match(tag, "ncomp_([0-9]+)")[, 2],
         method_raw = case_when(
           m_prefix == "SKLEARN" ~ paste0("sklearn-", str_match(tag, "-fold_[0-9]+-(.+)$")[, 2]),
           m_prefix %in% c("DIABLO", "RGCCA") & !is.na(design) ~
             paste0(METHOD_PREFIX[m_prefix], "-", design, "_ncomp-", ncomp),
           TRUE ~ unname(METHOD_PREFIX[m_prefix])),
         stage = unname(STAGE_MAP[stage_raw]))

# Canonical multimodal dataset set from the TRAIN stage (tags reliably carry -fold_);
# integration methods only ever run on multimodal datasets.
mm <- trace %>% filter(stage_raw == "TRAIN", m_prefix != "SKLEARN") %>% distinct(cand) %>% pull(cand)
if (is.null(run)) stopifnot("expected 26 multimodal datasets" = length(mm) == 26)
# Resolve each row's dataset: use the clean candidate when it is a multimodal
# dataset; otherwise remap integration feature-selection tags (which use design_/
# ncomp/he100 markers, not -fold_) to their multimodal dataset by longest prefix.
remap_mm <- function(cand) { h <- mm[startsWith(cand, mm)]; if (length(h) == 0) NA_character_ else h[which.max(nchar(h))] }
trace <- trace %>%
  mutate(dataset = dplyr::case_when(
    cand %in% mm ~ cand,
    m_prefix != "SKLEARN" ~ vapply(cand, remap_mm, character(1)),
    TRUE ~ NA_character_)) %>%
  filter(dataset %in% mm)

# ------------------------------------------------------------------ dataset size (n, p)
# Force the comma-joined per-modality dimension columns to character: readr would
# otherwise read "8110,1674,12" as a grouped number and strip the commas.
meta <- read_runs("parsed_metadata.csv", runs = runs,
                  col_types = cols(feat_dimensions = col_character(),
                                   subject_dimensions = col_character())) %>%
  distinct(dataset_name, .keep_all = TRUE) %>%
  mutate(dataset = str_remove(dataset_name, "_processed$"),
         p_total = sapply(str_split(feat_dimensions, ","), function(x) sum(as.numeric(x))),
         n_sub   = sapply(str_split(subject_dimensions, ","), function(x) max(as.numeric(x)))) %>%
  select(dataset, n_sub, p_total, positive_prop)

# ------------------------------------------------------------------ aggregate cost
# main_text = the 11 methods of the bulk benchmark (representative DIABLO/RGCCA variant + others).
cost_all <- trace %>%
  group_by(method_raw, dataset, stage) %>%
  summarise(time_s = median(time_s, na.rm = TRUE),
            mem_gib = median(mem_gib, na.rm = TRUE),
            n_tasks = n(), .groups = "drop") %>%
  left_join(meta, by = "dataset") %>%
  mutate(main_text = !str_detect(method_raw, "^(diablo|rgcca)") | method_raw %in% REPRESENTATIVE,
         method = if_else(main_text, bench_label(method_raw), bench_label(method_raw, collapse = FALSE)),
         method_class = bench_class(method_raw), .after = method_raw)
write_csv(cost_all, file.path(outdir, "tables", "cost_by_dataset_all_variants.csv"))
cost <- cost_all %>% filter(main_text, !is.na(method_class))
write_csv(cost, file.path(outdir, "tables", "cost_by_dataset.csv"))
message(sprintf("[cost] %d methods x %d datasets, stages: %s",
                dplyr::n_distinct(cost$method), dplyr::n_distinct(cost$dataset),
                paste(unique(cost$stage), collapse = ", ")))

# ------------------------------------------------------------------ join performance (time vs ROC-AUC)
pred <- read_runs("all_langs-result.csv", runs = runs) %>%
  distinct(sample_name, y, phat, method_name, dataset, fold)
perf <- compute_pooled_metrics(pred %>% filter(dataset %in% mm)) %>%
  select(method_raw = method_name, dataset, roc_auc, pr_auc)
cost_perf <- cost %>% filter(stage == "Training") %>%
  inner_join(perf, by = c("method_raw", "dataset"))
write_csv(cost_perf, file.path(outdir, "tables", "cost_vs_performance.csv"))
cost_summary <- cost %>% group_by(method, method_class, stage) %>%
  summarise(median_time_s = median(time_s), median_mem_gib = median(mem_gib),
            max_mem_gib = max(mem_gib), n_datasets = n(), .groups = "drop") %>%
  left_join(cost_perf %>% group_by(method) %>%
              summarise(median_roc_auc = median(roc_auc), .groups = "drop"), by = "method") %>%
  arrange(stage, median_time_s)
write_csv(cost_summary, file.path(outdir, "tables", "cost_summary.csv"))
print(as.data.frame(cost_summary %>% filter(stage == "Training")))

# ------------------------------------------------------------------ scaling fits  log(time) ~ log(n) + log(p)
# Observational exponents with a leave-one-dataset-out R2 (interpolation check)
# and a drop-ROSMAP sensitivity variant. Descriptive, NOT algorithmic Big-O.
fit_scaling <- function(d) {
  d <- d %>% filter(time_s > 0, n_sub > 0, p_total > 0)
  if (nrow(d) < 4) return(NULL)
  fit <- tryCatch(lm(log(time_s) ~ log(n_sub) + log(p_total), data = d), error = function(e) NULL)
  if (is.null(fit)) return(NULL)
  y <- log(d$time_s)
  # leave-one-dataset-out predicted errors
  loo_err <- sapply(seq_len(nrow(d)), function(i) {
    f <- tryCatch(lm(log(time_s) ~ log(n_sub) + log(p_total), data = d[-i, ]), error = function(e) NULL)
    if (is.null(f)) return(NA_real_)
    y[i] - predict(f, newdata = d[i, ])
  })
  loo_r2 <- 1 - sum(loo_err^2, na.rm = TRUE) / sum((y - mean(y))^2)
  co <- coef(fit)
  tibble(alpha_n = co[["log(n_sub)"]], beta_p = co[["log(p_total)"]],
         r2 = summary(fit)$r.squared, loo_r2 = loo_r2, n_points = nrow(d))
}
scaling <- cost %>% filter(stage == "Training") %>% group_by(method) %>%
  group_modify(~{
    all_fit <- fit_scaling(.x); if (is.null(all_fit)) return(tibble())
    nr_fit  <- fit_scaling(.x %>% filter(dataset != "rosmap"))
    all_fit %>% mutate(
      alpha_n_no_rosmap = if (is.null(nr_fit)) NA_real_ else nr_fit$alpha_n,
      beta_p_no_rosmap  = if (is.null(nr_fit)) NA_real_ else nr_fit$beta_p,
      loo_r2_no_rosmap  = if (is.null(nr_fit)) NA_real_ else nr_fit$loo_r2)
  }) %>% ungroup()
write_csv(scaling, file.path(outdir, "tables", "scaling_fits.csv"))
message("[cost] scaling fits (log time ~ log n + log p, with LOO R2):")
print(as.data.frame(scaling %>% select(method, alpha_n, beta_p, r2, loo_r2)))

saveRDS(list(cost = cost, cost_perf = cost_perf, scaling = scaling, mm = mm),
        file.path(outdir, "cost_plot_data.rds"))
message("[done] cost tables + rds -> ", outdir)
