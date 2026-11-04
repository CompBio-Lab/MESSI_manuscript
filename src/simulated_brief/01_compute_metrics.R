# 01_compute_metrics.R - derive the simulation prediction metric (pooled OOF ROC-AUC) and the
# feature-recovery metric (within-view recovery AUROC, macro-averaged across the 3 views).
# Raw data read-only; writes derived tables only.
# Notes:
#   * MOFA+ feature weights are exported with view label "omicX-Factor1".
#   * one row per feature x method x dataset is now VERIFIED (no component aggregation needed:
#     ncomp = 1 / num_factors = 1 in the simulation configuration).
#   * the S1/dt=0 logical cell (identical to S0/dt=0 by generator design) is filled and flagged.
#   * macro-average requires all 3 views (no silent na.rm over fewer views).
#   * method labels from src/common_helpers/method_labels.R (via theme_simulation.R).
suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(tidyr); library(readr); library(stringr); library(here)
})
source(here::here("src/simulated_brief/theme_simulation.R"))
OUT <- here::here("results/simulated_brief/data_derived"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

RUN <- here::here("data/raw/final_classification_results/simulated",
                  "copied_results_20261003_124923-job13207577-MESSI_results-simulated_data-samplesheet_simulated_full")
PRED <- file.path(RUN, "all_langs-result.csv")
FEAT <- here::here("data/processed/sim_src/sim_feat.csv")   # 589MB copy of RUN/all_feature_selection_results.csv

cov <- list(computed_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))  # coverage / sanity log
mm_lookup <- function(raw) { u <- unique(raw); m <- map_method(u); m[match(raw, u), ] }
sim_lookup <- function(ds) { u <- unique(ds); s <- parse_sim_id(u); s[match(ds, u), ] }

# ============================ Prediction: pooled OOF ROC-AUC ============================
message("[B] reading predictions ...")
p <- fread(PRED, select = c("sample_name","y","phat","method_name","dataset","fold"))
mm <- mm_lookup(p$method_name); sm <- sim_lookup(p$dataset)
p[, `:=`(method = mm$method, class = mm$class, order = mm$order,
         scenario = sm$scenario, dt = sm$dt, rho = sm$rho, is_single = sm$is_single)]

# OOF uniqueness check (each sample once per method x dataset) BEFORE dropping single-modality
chk <- p[, .(n = .N, u = uniqueN(sample_name), nf = uniqueN(fold)), by = .(method_name, dataset)]
cov$oof_dupe_configs <- sum(chk$n != chk$u)
cov$oof_configs_not_500 <- sum(chk$u != 500)
cov$oof_configs_not_5fold <- sum(chk$nf != 5)
# same labels and same fold PARTITION for every method within a dataset. Fold NUMBERS differ
# between the R-based and Python-based methods (a fixed relabelling, e.g. R fold_1 = Py fold_4),
# so compare the partition itself: each test set = sorted sample IDs; 5 distinct sets / dataset.
cov$label_misaligned <- sum(duplicated(unique(p[, .(dataset, sample_name, y)])[, .(dataset, sample_name)]))
fk <- p[, .(key = paste(sort(sample_name), collapse = ",")), by = .(method_name, dataset, fold)]
cov$fold_partition_mismatch_datasets <- sum(fk[, uniqueN(key), by = dataset]$V1 != 5)

pmm <- p[is_single == FALSE & !is.na(scenario)]
perfB <- pmm[, .(roc_auc = auroc(phat, y == 1), n = .N, n_pos = sum(y == 1)),
             by = .(method, class, order, scenario, dt, rho)]
perfB[, reused_from := NA_character_]
# Generator design (simulated_data_gen_code/create_data.R): with dt = 0 the two-sided shift is
# identically 0, so S1/dt=0 == S0/dt=0 and the generator reuses that dataset (45 physical
# datasets for 48 logical cells). Fill the logical S1/dt=0 cell from S0/dt=0 and flag it.
if (!nrow(perfB[scenario == "S1_nonlinear" & dt == 0])) {
  s1d0 <- copy(perfB[scenario == "S0_linear" & dt == 0])
  s1d0[, `:=`(scenario = "S1_nonlinear", reused_from = "S0_linear")]
  perfB <- rbind(perfB, s1d0)
}
setorder(perfB, order, scenario, dt, rho)
fwrite(perfB, file.path(OUT, "prediction_metrics_by_rho.csv"))
message("[B] perf rows: ", nrow(perfB))

# ============================ Recovery: within-view recovery AUROC ====================
message("[C] reading feature weights (589MB) ...")
f <- fread(FEAT, select = c("feature","feature_type","view","coef","method","dataset_name"))
cov$feature_types <- paste(sort(unique(f$feature_type)), collapse = ";")
stopifnot(all(f$feature_type %in% c("real", "noise")))      # no unknown truth labels
cov$feature_views_raw <- paste(sort(unique(f$view)), collapse = ";")
# view labels: omicX (sklearn/caret/coop/IntegrAO/MOGONET), omicX-ncomp-1 (DIABLO/RGCCA),
# omicX-Factor1 (MOFA+, num_factors = 1 in the simulation config).
f[, view := str_replace(view, "-(ncomp-?[0-9]+|Factor[0-9]+)$", "")]
stopifnot(all(f$view %in% c("omic1","omic2","omic3")))
f[, pos := feature_type == "real"]                           # real = generator signal block
mm <- mm_lookup(f$method); sm <- sim_lookup(f$dataset_name)
f[, `:=`(method_raw = method, method = mm$method, class = mm$class, order = mm$order,
         scenario = sm$scenario, dt = sm$dt, rho = sm$rho, is_single = sm$is_single)]
f <- f[is_single == FALSE & !is.na(scenario)]
cov$n_feature_rows <- nrow(f)
cov$coef_NA <- sum(is.na(f$coef))
# one row per feature x method x dataset (ncomp = 1 / num_factors = 1) - verify, don't assume
cov$feature_dup_rows <- f[, .N, by = .(method_raw, dataset_name, feature)][N > 1, .N]
if (cov$feature_dup_rows > 0) stop("duplicate feature rows - define a component aggregation first")
cov$features_per_cfg <- paste(unique(f[, .N, by = .(method_raw, dataset_name)]$N), collapse = ";")

f[, score := abs(coef)]   # |coef| / |loading|; RF/XGB importances are already >= 0; ties -> mid-rank
recV <- f[, .(recovery_auroc = auroc(score, pos), n_real = sum(pos), n_noise = sum(!pos),
              frac_zero = mean(score == 0)),
          by = .(method, class, order, scenario, dt, rho, view)]
setorder(recV, order, scenario, dt, rho, view)
fwrite(recV, file.path(OUT, "recovery_by_view.csv"))

# macro-average across the 3 views; require all 3 (dt = 0 has no signal features -> NA)
recC <- recV[, .(recovery_auroc = if (all(!is.na(recovery_auroc)) && .N == 3) mean(recovery_auroc) else NA_real_,
                 n_views = sum(!is.na(recovery_auroc))),
             by = .(method, class, order, scenario, dt, rho)]
cov$recovery_cfg_incomplete_views_dtpos <- recC[dt > 0 & n_views < 3, .N]
setorder(recC, order, scenario, dt, rho)
fwrite(recC, file.path(OUT, "recovery_by_rho.csv"))
message("[C] recovery rows: ", nrow(recC))

# ============================ V2: average across rho (equal weight) ==================
sumB <- perfB[, .(roc_auc = if (.N == 3 && all(!is.na(roc_auc))) mean(roc_auc) else NA_real_,
                  roc_min = min(roc_auc), roc_max = max(roc_auc), n_rho = .N,
                  reused_from = reused_from[1]),
              by = .(method, class, order, scenario, dt)]
sumC <- recC[, .(recovery_auroc = if (.N == 3 && all(!is.na(recovery_auroc))) mean(recovery_auroc) else NA_real_,
                 rec_min = min(recovery_auroc), rec_max = max(recovery_auroc), n_rho_rec = .N),
             by = .(method, class, order, scenario, dt)]
summ <- merge(sumB, sumC, by = c("method","class","order","scenario","dt"), all = TRUE)
setorder(summ, order, scenario, dt)
fwrite(summ, file.path(OUT, "metrics_rho_summary.csv"))

# ============================ method mapping + coverage ==============================
fwrite(METHOD_TBL, file.path(OUT, "method_mapping.csv"))
cov$n_methods_pred     <- uniqueN(perfB$method)
cov$methods_feat       <- paste(unique(recC[order(order)]$method), collapse = ";")
cov$n_methods_feat     <- uniqueN(recC$method)
cov$n_physical_datasets <- nrow(unique(perfB[is.na(reused_from), .(scenario, dt, rho)]))
cov$n_logical_cells    <- nrow(unique(perfB[, .(scenario, dt, rho)]))
cov$n_datasets_feat    <- nrow(unique(recC[, .(scenario, dt, rho)]))
cov$rho_values         <- paste(sort(unique(perfB$rho)), collapse = ";")
cov$dt_values          <- paste(sort(unique(perfB$dt)), collapse = ";")
cov$scenarios          <- paste(sort(unique(perfB$scenario)), collapse = ";")
cov$dt0_recovery_allNA <- all(is.na(recC[dt == 0]$recovery_auroc))
cov$perf_below_half    <- sum(perfB[is.na(reused_from)]$roc_auc < 0.5, na.rm = TRUE)  # not auto-flipped
cov$perf_NA            <- sum(is.na(perfB$roc_auc))
cov_df <- tibble(check = names(cov), value = sapply(cov, as.character))
fwrite(cov_df, file.path(OUT, "coverage_checks.csv"))
print(cov_df, n = 50)
message("[done] derived tables -> ", OUT)
