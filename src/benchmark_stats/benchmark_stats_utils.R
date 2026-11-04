# ==============================================================================
# benchmark_stats_utils.R
# Turns sample-level out-of-fold predictions into fold-level / pooled metrics and
# statistical comparisons (Friedman + Nemenyi CD,
# DeLong, Wilcoxon + Holm, win/tie/loss, bootstrap CI) and metrics (PR-AUC, F1, MCC,
# balanced accuracy, calibration).
#
# Numerically validated against the Python reference (scipy/scikit-learn).
# Metric definitions mirror scikit-learn; stats mirror scipy.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(stringr)
  library(purrr)
  library(readr)
})

# ------------------------------------------------------------------ run discovery
#' All pipeline run directories under data/raw (one per samplesheet, e.g. bulk +
#' multimodal). New runs dropped in as copied_results_* are picked up automatically.
messi_runs <- function(raw_dir = here::here("data/raw")) {
  # bulk + multimodal runs; data was moved into final_classification_results/ so look there
  # too (not covid/htx/sim/pca50 — those are handled by their own figure scripts).
  dirs <- c(list.dirs(raw_dir, recursive = FALSE),
            Sys.glob(file.path(raw_dir, "final_classification_results", "bulk", "copied_results_*")),
            Sys.glob(file.path(raw_dir, "final_classification_results", "multimodal", "copied_results_*")))
  dirs <- dirs[dir.exists(dirs) & grepl("^copied_results_", basename(dirs))]
  sort(unique(dirs))
}

#' Read and row-bind one filename across all runs (disjoint datasets per run).
#' Every run must have the file. file.exists() is also FALSE for paths over the Windows MAX_PATH
#' limit, so skipping would silently drop that run's datasets. No caller has a run that legitimately
#' lacks its file, so there is no allowlist.
read_runs <- function(filename, runs = messi_runs(), ...) {
  if (length(runs) == 0) stop("read_runs: no run directories for ", filename)
  bind_rows(lapply(runs, function(d) {
    f <- file.path(d, filename)
    if (!file.exists(f)) stop(sprintf("read_runs: cannot find expected input (path length %d): %s", nchar(f), f))
    suppressWarnings(read_csv(f, show_col_types = FALSE, ...))
  }))
}

# Metrics we score (all higher-is-better).
BENCH_METRICS <- c("roc_auc", "pr_auc", "matthews_corrcoef", "balanced_accuracy",
                   "f1_score", "precision", "recall")

# Method families whose best variant is selected as the representative, and the
# fixed variant set per family.
BENCH_FAMILIES <- list(
  DIABLO = c("diablo-full_ncomp-1", "diablo-full_ncomp-2",
             "diablo-null_ncomp-1", "diablo-null_ncomp-2"),
  RGCCA  = c("rgcca-full_ncomp-2", "rgcca-null_ncomp-2")
)

# Display labels: delegated to the ONE canonical label map (src/common_helpers/method_labels.R:
# method_label / method_class / method_order). Representative variants collapse to the concise
# family label (diablo-null_ncomp-2 -> "DIABLO-N", rgcca-full_ncomp-2 -> "RGCCA-F",
# cooperative_learning -> "Multiview", mofa -> "MOFA+", sklearn-Logit-empty -> "Logistic").
# collapse = FALSE keeps non-representative variants distinguishable by appending the
# component count ("DIABLO-N, 1 comp."); only used in supplementary tables.
source(here::here("src/common_helpers/method_labels.R"))
bench_label <- function(m, collapse = TRUE) {
  m <- as.character(m)
  lab <- method_label(m)
  if (collapse) return(unname(lab))
  nc <- stringr::str_match(m, "_ncomp-([0-9]+)$")[, 2]
  unname(ifelse(is.na(nc), lab, sprintf("%s, %s comp.", lab, nc)))
}
bench_class <- function(m) method_class(m)

# House style (theme_messi, CLASS_COLORS, PAIR_COLORS, SIG_COLORS, method_factor_y, save_main).
source(here::here("src/common_helpers/theme_messi.R"))
BENCH_CLASS_COLORS <- CLASS_COLORS

#' Save a final figure: png + rds (via save_plot_both) + pdf, 300 dpi.
save_final_fig <- function(p, path_noext, width, height, dpi = 300) {
  dir.create(dirname(path_noext), recursive = TRUE, showWarnings = FALSE)
  save_plot_both(p, paste0(path_noext, ".png"), width = width, height = height, dpi = dpi)
  ggplot2::ggsave(paste0(path_noext, ".pdf"), p, width = width, height = height,
                  device = grDevices::cairo_pdf)
  invisible(path_noext)
}

# ------------------------------------------------------------------ metrics
# roc_auc via the Mann-Whitney / midrank formula (matches sklearn incl. ties).
.auc_rank <- function(y, score) {
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  r <- rank(score)                       # average ranks for ties
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# average_precision_score: area under precision-recall as a step sum, exactly
# matching sklearn's precision_recall_curve + AP = -sum(diff(recall)*precision[:-1]).
.average_precision <- function(y, score) {
  n1 <- sum(y == 1)
  if (n1 == 0) return(NA_real_)
  ord <- order(score, decreasing = TRUE)
  ys <- y[ord]; ss <- score[ord]
  # thresholds at distinct scores: index of the last tie in each run
  distinct <- which(c(ss[-length(ss)] != ss[-1], TRUE))
  tps <- cumsum(ys)[distinct]
  fps <- cumsum(1 - ys)[distinct]
  precision <- tps / (tps + fps)
  recall <- tps / n1
  # sklearn prepends the (p=1, r=0) origin, then AP = sum over steps of
  # (recall_i - recall_{i-1}) * precision_i
  recall0 <- c(0, recall)
  sum(diff(recall0) * precision)
}

# Threshold-0.5 confusion-matrix metrics (sklearn zero_division = 0).
.threshold_metrics <- function(y, score, thr = 0.5) {
  yhat <- as.integer(score >= thr)
  tp <- sum(yhat == 1 & y == 1); fp <- sum(yhat == 1 & y == 0)
  tn <- sum(yhat == 0 & y == 0); fn <- sum(yhat == 0 & y == 1)
  precision <- if ((tp + fp) == 0) 0 else tp / (tp + fp)
  recall    <- if ((tp + fn) == 0) 0 else tp / (tp + fn)      # sensitivity / TPR
  f1        <- if ((precision + recall) == 0) 0 else 2 * precision * recall / (precision + recall)
  tnr       <- if ((tn + fp) == 0) 0 else tn / (tn + fp)      # specificity / TNR
  bal_acc   <- (recall + tnr) / 2
  mcc_den   <- sqrt(as.double(tp + fp) * (tp + fn) * (tn + fp) * (tn + fn))
  mcc       <- if (mcc_den == 0) 0 else (tp * tn - fp * fn) / mcc_den
  list(matthews_corrcoef = mcc, balanced_accuracy = bal_acc,
       f1_score = f1, precision = precision, recall = recall)
}

#' All metrics for one (y, score) vector set.
score_one <- function(y, score) {
  tm <- .threshold_metrics(y, score)
  tibble(
    roc_auc = .auc_rank(y, score),
    pr_auc = .average_precision(y, score),
    matthews_corrcoef = tm$matthews_corrcoef,
    balanced_accuracy = tm$balanced_accuracy,
    f1_score = tm$f1_score,
    precision = tm$precision,
    recall = tm$recall
  )
}

#' Per (method, dataset, fold) metrics from sample-level predictions.
compute_fold_metrics <- function(pred) {
  pred %>%
    group_by(method_name, dataset, fold) %>%
    group_modify(~ bind_cols(
      tibble(n = nrow(.x), n_pos = sum(.x$y)),
      score_one(.x$y, .x$phat)
    )) %>%
    ungroup()
}

#' Make fold labels mean the same test samples for every method, so that dataset x fold can be used
#' as a paired block. All methods share one fold partition, but R and Python methods number it
#' differently. Each fold becomes the ref_method's fold for the same (dataset, sample_name).
canonicalise_folds <- function(pred, ref_method = "sklearn-Logit-empty") {
  ref <- pred %>% filter(method_name == ref_method) %>%
    distinct(dataset, sample_name, canonical_fold = fold)
  if (anyDuplicated(ref[c("dataset", "sample_name")]))
    stop("canonicalise_folds: a sample is in more than one ", ref_method, " fold")
  out <- pred %>% left_join(ref, by = c("dataset", "sample_name"))
  if (anyNA(out$canonical_fold))
    stop(sprintf("canonicalise_folds: %d rows have no %s fold, e.g. dataset %s", sum(is.na(out$canonical_fold)),
                 ref_method, out$dataset[is.na(out$canonical_fold)][1]))
  bad <- out %>% distinct(method_name, dataset, fold, canonical_fold) %>%
    group_by(method_name, dataset) %>%
    filter(n() != n_distinct(fold) | n() != n_distinct(canonical_fold)) %>% ungroup()
  if (nrow(bad) > 0)
    stop(sprintf("canonicalise_folds: fold mapping is not 1-to-1 for %s on %s", bad$method_name[1], bad$dataset[1]))
  out %>% mutate(fold = canonical_fold) %>% select(-canonical_fold)
}

#' Per (method, dataset) metrics from fold-pooled out-of-fold predictions.
compute_pooled_metrics <- function(pred) {
  pred %>%
    group_by(method_name, dataset) %>%
    group_modify(~ bind_cols(
      tibble(n = nrow(.x), n_pos = sum(.x$y)),
      score_one(.x$y, .x$phat)
    )) %>%
    ungroup()
}

#' Degenerate classifiers: every pooled prediction is one class at threshold 0.5. Predicted positives
#' are counted directly (same >= rule as .threshold_metrics); the threshold metrics cannot identify
#' this case. pred = the sample-level predictions that `pooled` was computed from.
degenerate_rows <- function(pooled, pred, thr = 0.5) {
  n_pred <- pred %>% group_by(method_name, dataset) %>%
    summarise(n_pred_pos = sum(phat >= thr), .groups = "drop")
  pooled %>%
    left_join(n_pred, by = c("method_name", "dataset")) %>%
    mutate(degenerate = case_when(
      n_pred_pos == 0 ~ "all-negative",
      n_pred_pos == n ~ "all-positive",
      TRUE ~ NA_character_
    )) %>%
    filter(!is.na(degenerate))
}

# ------------------------------------------------------------------ ranking
#' Rank table: blocks (dataset or dataset+fold) x methods; rank 1 = best.
#' Returns a matrix with blocks as rows, methods as columns.
rank_table <- function(df, metric) {
  block_cols <- intersect(c("dataset", "fold"), names(df))
  wide <- df %>%
    select(all_of(c(block_cols, "method_name", metric))) %>%
    pivot_wider(names_from = method_name, values_from = all_of(metric)) %>%
    arrange(across(all_of(block_cols)))
  mat <- as.matrix(wide[, setdiff(names(wide), block_cols), drop = FALSE])
  rownames(mat) <- do.call(paste, c(as.list(wide[block_cols]), sep = "|"))
  # rank 1 = best (higher value better); average ties; per block (row)
  ranks <- t(apply(mat, 1, function(r) rank(-r, na.last = "keep", ties.method = "average")))
  colnames(ranks) <- colnames(mat)
  ranks
}

#' Best variant per family by overall mean rank across all metrics.
select_representatives <- function(pooled) {
  reps <- list(); detail <- list()
  for (fam in names(BENCH_FAMILIES)) {
    variants <- BENCH_FAMILIES[[fam]]
    sub <- pooled %>% filter(method_name %in% variants)
    # mean rank per variant averaged across metrics
    per_metric <- sapply(BENCH_METRICS, function(m) {
      rk <- rank_table(sub, m)
      colMeans(rk, na.rm = TRUE)[variants]
    })
    overall <- rowMeans(per_metric)
    best <- names(which.min(overall))
    reps[[fam]] <- best
    detail[[fam]] <- tibble(family = fam,
                            variant = variants,
                            mean_rank = round(as.numeric(overall[variants]), 3),
                            selected = best)
  }
  list(reps = reps, detail = bind_rows(detail))
}

# ------------------------------------------------------------- Friedman / Nemenyi
#' Friedman chi-square with tie correction (matches scipy.friedmanchisquare) +
#' Nemenyi critical difference. Input: rank table (blocks x methods), complete rows.
friedman_nemenyi <- function(ranks) {
  ranks <- ranks[stats::complete.cases(ranks), , drop = FALSE]
  n <- nrow(ranks); k <- ncol(ranks)
  # re-rank within each block (idempotent on ranks; mirrors scipy rankdata)
  rr <- t(apply(ranks, 1, rank, ties.method = "average"))
  colsum <- colSums(rr)
  ssbn <- sum(colsum^2)
  chisq <- 12.0 / (n * k * (k + 1)) * ssbn - 3 * n * (k + 1)
  # tie correction: c = 1 - sum(t^3 - t) / (n*k*(k^2-1))
  tie_term <- sum(apply(rr, 1, function(row) {
    tb <- table(row); sum(tb^3 - tb)
  }))
  cfac <- 1 - tie_term / (n * k * (k^2 - 1))
  if (cfac != 0) chisq <- chisq / cfac
  p <- stats::pchisq(chisq, df = k - 1, lower.tail = FALSE)
  W <- chisq / (n * (k - 1))
  q <- stats::qtukey(1 - 0.05, k, Inf) / sqrt(2)      # Nemenyi q_alpha
  cd <- q * sqrt(k * (k + 1) / (6.0 * n))
  mean_ranks <- sort(colMeans(rr))
  list(chi2 = chisq, p = p, kendall_w = W, cd = cd, q = q,
       n_blocks = n, k = k, mean_ranks = mean_ranks)
}

#' Demsar (2006) cliques: maximal runs of methods (in mean-rank order) whose total
#' span (worst - best mean rank) is < CD, i.e. no pair inside is significantly different.
nemenyi_groups <- function(mean_ranks, cd) {
  mr <- sort(mean_ranks); ord <- names(mr); k <- length(mr)
  groups <- list(); last_end <- 0
  for (i in seq_len(k)) {
    j <- max(which(mr - mr[i] < cd))
    if (j > i && j > last_end) { groups <- c(groups, list(ord[i:j])); last_end <- j }
  }
  groups
}

# ------------------------------------------------------------------ DeLong
.delong_components <- function(y, phat) {
  pos <- phat[y == 1]; neg <- phat[y == 0]
  diffm <- outer(pos, neg, "-")
  v10 <- (diffm > 0) + 0.5 * (diffm == 0)
  list(xi10 = rowMeans(v10), xi01 = colMeans(v10), auc = mean(v10))
}

#' Paired DeLong test for two correlated AUCs on the same samples.
delong_test <- function(y, p1, p2) {
  c1 <- .delong_components(y, p1); c2 <- .delong_components(y, p2)
  n1 <- length(c1$xi10); n0 <- length(c1$xi01)
  s10 <- stats::cov(cbind(c1$xi10, c2$xi10))
  s01 <- stats::cov(cbind(c1$xi01, c2$xi01))
  var1 <- s10[1, 1] / n1 + s01[1, 1] / n0
  var2 <- s10[2, 2] / n1 + s01[2, 2] / n0
  cov  <- s10[1, 2] / n1 + s01[1, 2] / n0
  var_diff <- max(var1 + var2 - 2 * cov, 1e-12)
  z <- (c1$auc - c2$auc) / sqrt(var_diff)
  p <- 2 * stats::pnorm(-abs(z))
  list(auc1 = c1$auc, auc2 = c2$auc, z = z, p = p)
}

#' Per dataset: each method vs the dataset-best method (by pooled ROC-AUC). BH-FDR.
delong_all_datasets <- function(pred, methods) {
  rows <- list()
  for (ds in unique(pred$dataset)) {
    g <- pred %>% filter(dataset == ds, method_name %in% methods)
    wide <- g %>% select(sample_name, method_name, phat) %>%
      pivot_wider(names_from = method_name, values_from = phat)
    yv <- g %>% distinct(sample_name, y) %>%
      right_join(wide["sample_name"], by = "sample_name") %>% pull(y)
    present <- intersect(methods, names(wide))
    aucs <- sapply(present, function(m) .auc_rank(yv, wide[[m]]))
    ref <- present[which.max(aucs)]
    for (m in present) {
      if (m == ref) next
      dt <- delong_test(yv, wide[[ref]], wide[[m]])
      rows[[length(rows) + 1]] <- tibble(
        dataset = ds, reference = ref, method = m,
        auc_ref = dt$auc1, auc_method = dt$auc2,
        delta = dt$auc2 - dt$auc1, z = dt$z, p = dt$p)
    }
  }
  res <- bind_rows(rows)
  res$p_fdr <- stats::p.adjust(res$p, method = "BH")
  res
}

# ------------------------------------------------------------ pairwise tests
#' Dataset-level Wilcoxon signed-rank for all method pairs + Holm correction.
pairwise_wilcoxon <- function(pooled, metric, methods) {
  wide <- pooled %>% filter(method_name %in% methods) %>%
    select(dataset, method_name, all_of(metric)) %>%
    pivot_wider(names_from = method_name, values_from = all_of(metric))
  rows <- list()
  for (i in seq_along(methods)) {
    for (j in seq_along(methods)) {
      if (j <= i) next
      a <- methods[i]; b <- methods[j]
      d <- wide[[b]] - wide[[a]]
      nz <- d[d != 0 & !is.na(d)]
      if (length(nz) < 3) {
        p <- NA_real_
      } else {
        p <- suppressWarnings(stats::wilcox.test(nz)$p.value)
      }
      rows[[length(rows) + 1]] <- tibble(
        metric = metric, method_a = a, method_b = b,
        median_delta_b_minus_a = stats::median(d, na.rm = TRUE),
        n_datasets = sum(!is.na(d)), p = p)
    }
  }
  res <- bind_rows(rows)
  res$p_holm <- stats::p.adjust(ifelse(is.na(res$p), 1, res$p), method = "holm")
  res
}

#' Win / tie / loss counts per method pair (b relative to a).
win_tie_loss <- function(pooled, metric, methods, tol = 0.01) {
  wide <- pooled %>% filter(method_name %in% methods) %>%
    select(dataset, method_name, all_of(metric)) %>%
    pivot_wider(names_from = method_name, values_from = all_of(metric))
  rows <- list()
  for (i in seq_along(methods)) {
    for (j in seq_along(methods)) {
      if (j <= i) next
      a <- methods[i]; b <- methods[j]
      d <- (wide[[b]] - wide[[a]]); d <- d[!is.na(d)]
      rows[[length(rows) + 1]] <- tibble(
        metric = metric, method_a = a, method_b = b,
        b_wins = sum(d > tol), tie = sum(abs(d) <= tol), b_loses = sum(d < -tol))
    }
  }
  bind_rows(rows)
}

#' Bootstrap 95% CI (resampling datasets) of median paired delta method - reference.
bootstrap_delta_ci <- function(pooled, metric, method, reference,
                               n_boot = 10000, seed = 0) {
  wide <- pooled %>% filter(method_name %in% c(method, reference)) %>%
    select(dataset, method_name, all_of(metric)) %>%
    pivot_wider(names_from = method_name, values_from = all_of(metric))
  d <- (wide[[method]] - wide[[reference]]); d <- d[!is.na(d)]
  set.seed(seed)
  meds <- replicate(n_boot, stats::median(sample(d, length(d), replace = TRUE)))
  tibble(method = method, reference = reference, metric = metric,
         median_delta = stats::median(d),
         ci_low = stats::quantile(meds, 0.025, names = FALSE),
         ci_high = stats::quantile(meds, 0.975, names = FALSE))
}

# ------------------------------------------------------------------ calibration
#' Reliability-curve points + Brier score + ECE per (method, dataset).
#' phat is clipped to [0,1] first (some methods emit scores slightly outside).
calibration_by_method_dataset <- function(pred, methods, n_bins = 10) {
  g <- pred %>% filter(method_name %in% methods) %>%
    mutate(p = pmin(pmax(phat, 0), 1),
           bin = pmin(floor(p * n_bins) + 1, n_bins))
  curve <- g %>%
    group_by(method_name, dataset, bin) %>%
    summarise(p_mean = mean(p), y_rate = mean(y), n = n(), .groups = "drop")
  summ <- g %>%
    group_by(method_name, dataset) %>%
    summarise(brier = mean((p - y)^2), n = n(), .groups = "drop")
  ece <- curve %>%
    group_by(method_name, dataset) %>%
    summarise(N = sum(n), ece = sum(n / N * abs(y_rate - p_mean)), .groups = "drop") %>%
    select(method_name, dataset, ece)
  list(curve = curve, summary = left_join(summ, ece, by = c("method_name", "dataset")))
}

# ------------------------------------------------------------------ CD diagram (shared plot helper)
#' Demsar critical-difference diagram as a ggplot. Top axis = mean rank (1 = best, left).
#' Labels split left (better half) / right (worse half) with elbow connectors; thick bars
#' join cliques whose adjacent mean-rank gaps are < CD (Nemenyi, alpha = 0.05).
#' Label text is coloured by integration class. `lab_size` in mm (ggplot units).
plot_cd_ggplot <- function(mean_ranks, cd, title = NULL, subtitle = NULL, base = 9,
                           lab_size = 2.6, margin_lr = c(105, 105)) {
  mr <- sort(mean_ranks); k <- length(mr); meth <- names(mr); rk <- as.numeric(mr)
  axis_lo <- floor(min(rk)); axis_hi <- ceiling(max(rk))
  nL <- ceiling(k / 2); side <- c(rep("L", nL), rep("R", k - nL))
  groups <- nemenyi_groups(mr, cd); gbars <- NULL
  if (length(groups) > 0) {
    yb <- -0.04
    gbars <- do.call(rbind, lapply(groups, function(g) {
      rs <- rk[meth %in% g]; row <- tibble(x = min(rs) - 0.04, xend = max(rs) + 0.04, y = yb)
      yb <<- yb - 0.05; row }))
  }
  top <- (if (is.null(gbars)) 0 else min(gbars$y)) - 0.09; step <- 0.13
  ypos <- numeric(k)
  ypos[side == "L"] <- top - (seq_len(nL) - 1) * step
  ypos[side == "R"] <- rev(top - (seq_len(k - nL) - 1) * step)   # worst method nearest axis on the right
  seg <- tibble(method = meth, rank = rk, y = ypos,
                lx = ifelse(side == "L", axis_lo, axis_hi), hj = ifelse(side == "L", 1, 0),
                lab = ifelse(side == "L", sprintf("%s (%.2f) ", meth, rk), sprintf(" (%.2f) %s", rk, meth)),
                class = method_class(meth))
  ylo <- min(c(ypos, if (is.null(gbars)) 0 else min(gbars$y))) - 0.08
  ggplot2::ggplot(seg) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.4) +
    ggplot2::geom_segment(ggplot2::aes(x = rank, xend = rank, y = 0, yend = y), linewidth = 0.3, color = "grey45") +
    ggplot2::geom_segment(ggplot2::aes(x = rank, xend = lx, y = y, yend = y), linewidth = 0.3, color = "grey45") +
    ggplot2::geom_text(ggplot2::aes(x = lx, y = y, label = lab, hjust = hj, color = class), size = lab_size) +
    { if (!is.null(gbars)) ggplot2::geom_segment(data = gbars,
        ggplot2::aes(x = x, xend = xend, y = y, yend = y), linewidth = 1, color = "grey15", lineend = "round") } +
    ggplot2::annotate("segment", x = axis_lo, xend = axis_lo + cd, y = 0.13, yend = 0.13, linewidth = 0.7) +
    ggplot2::annotate("text", x = axis_lo + cd / 2, y = 0.2, label = sprintf("CD = %.2f", cd), size = lab_size) +
    ggplot2::scale_color_manual(values = BENCH_CLASS_COLORS, guide = "none") +
    ggplot2::scale_x_continuous(position = "top", breaks = seq(axis_lo, axis_hi), expand = c(0, 0)) +
    ggplot2::scale_y_continuous(limits = c(ylo, 0.26)) +
    ggplot2::coord_cartesian(xlim = c(axis_lo, axis_hi), clip = "off") +
    ggplot2::labs(title = title, subtitle = subtitle, x = "Mean rank (1 = best)", y = NULL) +
    ggplot2::theme_minimal(base_size = base) +
    ggplot2::theme(axis.text.y = ggplot2::element_blank(), panel.grid = ggplot2::element_blank(),
                   axis.line.x.top = ggplot2::element_line(linewidth = 0.4),
                   axis.ticks.x.top = ggplot2::element_line(linewidth = 0.3),
                   axis.text.x = ggplot2::element_text(color = "black"),
                   plot.title = ggplot2::element_text(face = "bold", size = base + 1),
                   plot.subtitle = ggplot2::element_text(size = base - 1, color = "grey30"),
                   plot.tag = ggplot2::element_text(face = "bold", size = 14),
                   plot.margin = ggplot2::margin(4, margin_lr[2], 4, margin_lr[1]))
}
