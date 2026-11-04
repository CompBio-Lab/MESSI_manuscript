# ==============================================================================
# run_fig4_null.R -- permutation check of the Fig 4 known-gene significance claims.
#
# Null: within each method x dataset, permute feature weights among features WITHIN each view,
# moving a feature's weights across components together as one row. The feature->gene map and the
# known-gene labels stay fixed. Gene scores are rebuilt as in production (max |coef| over the
# gene's rows and components) and the AUROC is recomputed (mid-ranks, as in production).
#   empirical p = (1 + #{null AUROC >= observed}) / (1 + B)
#
# Reads only (nothing under src/ or data/ is written):
#   data/raw/final_classification_results/{bulk,multimodal}/copied_results_*/all_feature_selection_results.csv
#   data/processed/sc_src/{cov_feat,htx_feat}.csv       (byte copies of the covid_only/htx_only runs)
#   data/raw/known_gene_sets/ and msigdbr (same sources as recall_at_k.R and sc_biology.R)
#   results/biology_validation/tables/known_gene_discrimination.csv, results/sc_new/sc_known_gene_discrimination.csv
# Writes: OUT/fig4_null_results.csv, OUT/features_per_gene_check.csv, OUT/fig4_null_cancer_summary.csv,
#         OUT/fig4_null_ties_and_pools.csv; working files in WORK (no gene names are stored there).
# Run:    Rscript src/biology_validation/run_fig4_null.R   (not part of make figures: about 6 min on 16 cores)
# ==============================================================================
ROOT <- here::here()
WORK <- Sys.getenv("MESSI_NULL_WORK", file.path(tempdir(), "fig4_null"))   # cache; set it to resume a run
OUT  <- Sys.getenv("MESSI_NULL_OUT", file.path(ROOT, "results/biology_validation/tables"))
SEED <- 20261104L
B_NONCANCER <- 10000L
B_CANCER    <- 10000L
B_SENS      <- 2000L     # sensitivity run: pool = all features of the view, incl. those production drops
NCORES      <- 6L
TOL         <- 1e-10     # ">=" on AUROC uses this tolerance (floating-point sums of mid-ranks)
MAIN_DROP   <- c("sklearn-random_forest", "sklearn-xgboost")   # excluded from the main BH family, as in the paper

suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(stringr); library(parallel)
})
dir.create(WORK, recursive = TRUE, showWarnings = FALSE); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
T0 <- Sys.time()
msg <- function(...) cat(sprintf("[%6.1f min] ", as.numeric(difftime(Sys.time(), T0, units = "mins"))), ..., "\n", sep = "")

# ------------------------------------------------------------------ gene sets (held in memory only)
CANCER_DS <- c("tcga-acc","tcga-blca","tcga-brca","tcga-esca","tcga-kich","tcga-kirc","tcga-meso","tcga-skcm",
               "tcga-stes","tcga-thca","momix-aml","momix-breast","momix-colon","momix-gbm","momix-kidney",
               "momix-liver","momix-lung","momix-melanoma","momix-ovarian","momix-sarcoma","clinical_omics")
DS_SET <- c(setNames(rep("cancer", length(CANCER_DS)), CANCER_DS), imaging_omics = "DKD", GSE38609 = "autism",
            covid_multiomics = "covid", covid_organ = "covid", htx_cell_views = "rejection")
GENE_VIEWS <- c("RNAseq_HiSeq_Gene_level", "exp", "rna", "mrna", "genomics")

# ------------------------------------------------------------------ feature tables, parsed as in production
CACHE <- file.path(WORK, "feature_rows.rds")   # method, dataset, view, feature_id, gene_id, known, scored, comp, abscoef
if (!file.exists(CACHE)) {
  G  <- file.path(ROOT, "data/raw/known_gene_sets")
  up <- function(x) toupper(unique(x[!is.na(x) & x != ""]))
  rd <- function(f, ...) as.data.frame(suppressMessages(readr::read_delim(f, show_col_types = FALSE, ...)))
  ncg   <- rd(file.path(G, "NCG_cancerdrivers_annotation_supporting_evidence.tsv"), delim = "\t")
  dkd   <- rd(file.path(G, "OT-MONDO_0005016-DKD-associated-targets-10_2_2026-v26_09.tsv"), delim = "\t")
  sfari <- rd(file.path(G, "sfari_autism.csv"), delim = ",")
  covid <- rd(Sys.glob(file.path(G, "OT-MONDO_0100096-COVID19-*.tsv"))[1], delim = "\t")
  REJ   <- up(msigdbr::msigdbr(species = "Homo sapiens", collection = "H") %>%
                filter(gs_name == "HALLMARK_ALLOGRAFT_REJECTION") %>% pull(gene_symbol))
  GENE_SETS <- list(cancer = up(ncg$symbol[!is.na(ncg$cgc_annotation) & ncg$cgc_annotation != ""]),
                    DKD = up(dkd$symbol[dkd$globalScore >= 0.1]), autism = up(sfari$`gene-symbol`),
                    covid = up(covid$symbol[covid$globalScore >= 0.1]), rejection = REJ)
  msg("gene-set sizes: ", paste(names(GENE_SETS), lengths(GENE_SETS), sep = "=", collapse = ", "))

  runs <- c(Sys.glob(file.path(ROOT, "data/raw/final_classification_results/bulk/copied_results_*")),
            Sys.glob(file.path(ROOT, "data/raw/final_classification_results/multimodal/copied_results_*")))
  stopifnot(length(runs) == 2)
  cols <- c("feature", "view", "coef", "method", "dataset_name")
  bulk <- rbindlist(lapply(file.path(runs, "all_feature_selection_results.csv"), fread, select = cols, showProgress = FALSE))
  # production also includes rosmap when it derives dot_fmt (no effect: Ensembl ids are excluded from that step)
  bulk <- bulk[dataset_name %in% names(DS_SET)]
  bulk[, base_view := str_remove(view, "-(ncomp-\\d+|Factor\\d+)$")]
  bulk <- bulk[base_view %in% GENE_VIEWS]
  # --- verbatim recall_at_k.R parsing
  bulk[, raw := str_remove(str_remove(feature, paste0("^", base_view, "_")), "\\|\\d+$")]
  dot_fmt <- bulk[!str_detect(raw, "^(ENSG|ILMN_)"), .(f = mean(str_detect(raw, "\\.\\d+$"))), by = dataset_name][f > 0.9, dataset_name]
  msg("'.ENTREZ' format: ", paste(dot_fmt, collapse = ", "))
  bulk[, raw := ifelse(dataset_name %in% dot_fmt, str_remove(raw, "\\.\\d+$"), raw)]
  bulk[, raw := ifelse(str_detect(raw, "^(ENSG|ILMN_)"), raw, str_replace_all(raw, "\\.", "-"))]
  suppressPackageStartupMessages({library(AnnotationDbi); library(org.Hs.eg.db); library(illuminaHumanv4.db)})
  map_symbol <- function(raw) {
    raw <- as.character(raw); out <- toupper(raw)
    ilmn <- str_detect(raw, "^ILMN_"); ens <- str_detect(raw, "^ENSG")
    if (any(ilmn)) { m <- suppressMessages(AnnotationDbi::mapIds(illuminaHumanv4.db, keys = raw[ilmn], column = "SYMBOL", keytype = "PROBEID", multiVals = "first")); out[ilmn] <- toupper(unname(m)) }
    if (any(ens))  { m <- suppressMessages(AnnotationDbi::mapIds(org.Hs.eg.db, keys = str_remove(raw[ens], "\\.\\d+$"), column = "SYMBOL", keytype = "ENSEMBL", multiVals = "first")); out[ens] <- toupper(unname(m)) }
    out
  }
  bulk[, gene := map_symbol(raw)]
  bulk[, scored := !is.na(gene) & gene != "" & !str_detect(gene, "^LOC|^HSA-|^\\d+$")]
  bulk <- bulk[, .(method, dataset = dataset_name, view = base_view, feature, gene, scored, view_full = view, coef)]

  sc <- rbindlist(lapply(file.path(ROOT, "data/processed/sc_src", c("cov_feat.csv", "htx_feat.csv")), fread, select = cols, showProgress = FALSE))
  sc <- sc[dataset_name %in% names(DS_SET)]
  # --- verbatim sc_biology.R parsing
  sc[, base_view := str_remove(view, "-(Factor\\d+|ncomp-\\d+)$")]
  sc[, pfx := str_match(feature, "^(RNA|Protein)_")[, 2]]
  sc[, src_view := ifelse(dataset_name != "htx_cell_views" & !is.na(pfx), pfx, base_view)]
  sc[, modality := fcase(dataset_name == "covid_multiomics" & src_view == "RNA", "PBMC mRNA",
                         dataset_name == "covid_multiomics" & src_view == "Protein", "ADT protein",
                         dataset_name == "covid_organ" & src_view == "RNA", "Airway mRNA",
                         dataset_name == "covid_organ" & src_view == "Protein", "Blood mRNA",
                         dataset_name == "htx_cell_views", "Cell-type mRNA")]
  stopifnot(!any(is.na(sc$modality)))
  sc <- sc[modality != "ADT protein"]   # the ADT view is not gene-level and is not scored in production
  sc[, gene := toupper(str_extract(feature, "[^_]+$"))]
  sc[, scored := !is.na(gene) & gene != "" & !str_detect(gene, "^LOC|^HSA-|^[0-9]+$")]
  # permutation view: for COVID the modality from the name prefix (= production). For HTX the cell type: taken from
  # the feature-name prefix where there is one, because the sklearn tables mis-assign 3 Pericytes_* features to view
  # "NK" (same substring bug as documented in sc_biology.R); IntegrAO and MOGONET have bare gene names, so the view column.
  sc[, htx_pre := ifelse(str_detect(feature, "_"), str_remove(feature, "_[^_]*$"), base_view)]
  sc[, perm_view := ifelse(dataset_name == "htx_cell_views", htx_pre, modality)]
  sc <- sc[, .(method, dataset = dataset_name, view = perm_view, feature, gene, scored, view_full = view, coef)]

  fr <- rbind(bulk, sc)
  fr[, comp := str_match(view_full, "-(ncomp-\\d+|Factor\\d+)$")[, 2]]; fr[is.na(comp), comp := "single"]
  fr[, abscoef := abs(coef)]
  fr[, known := FALSE]
  for (ds in names(DS_SET)) fr[dataset == ds, known := gene %in% GENE_SETS[[DS_SET[[ds]]]]]
  # replace names by integer ids so that no curated list or gene name can leak into working files
  fr[, gene_id := match(gene, unique(gene)), by = dataset]
  fr[, feature_id := match(paste(view, feature), unique(paste(view, feature))), by = .(dataset, method)]
  fr <- fr[, .(method, dataset, view, feature_id, gene_id, known, scored, comp, abscoef)]
  saveRDS(fr, CACHE, compress = FALSE)
} else fr <- readRDS(CACHE)
msg("feature rows: ", nrow(fr), "; NA coef: ", sum(is.na(fr$abscoef)))

# one row per (method, dataset, view, feature) with its row score = max |coef| over components, moved jointly
rows <- fr[, .(s = max(abscoef, na.rm = TRUE), n_comp = .N, n_na = sum(is.na(abscoef))),
           by = .(method, dataset, view, feature_id, gene_id, known, scored)]
stopifnot("a feature row has weights on an unequal number of components within a method x dataset" =
            rows[, uniqueN(n_comp), by = .(method, dataset)][, all(V1 == 1)])
msg("components per feature row: ", paste(rows[, .(k = n_comp[1]), by = .(method)][, paste0(method, "=", k)], collapse = ", "))

# ------------------------------------------------------------------ observed scores (production definitions) + reproduction check
auroc_prod <- function(score, lab) {
  R <- sum(lab); N <- length(lab); r <- rank(score)
  (sum(r[lab]) - R * (R + 1) / 2) / (R * (N - R))
}
obs <- rows[scored == TRUE, .(g = max(s), known = known[1]), by = .(method, dataset, gene_id)]
obs_tab <- obs[, {
  R <- sum(known); N <- .N
  if (R < 3 || R == N) {
    .(auroc = numeric(), mw_p = numeric(), R = integer(), N = integer(), frac_zero = numeric(), n_unique = integer(), top10_ratio = numeric())
  } else {
    r <- rank(g); pct <- (N - r) / (N - 1)
    .(auroc = (sum(r[known]) - R * (R + 1) / 2) / (R * (N - R)),
      mw_p = suppressWarnings(wilcox.test(g[known], g[!known], alternative = "greater")$p.value),
      R = R, N = N, frac_zero = mean(g == 0), n_unique = uniqueN(g), top10_ratio = mean(pct[known] <= 0.1) / 0.1)
  }
}, by = .(method, dataset)]
obs_tab[, disease := DS_SET[dataset]]

pap_b <- fread(file.path(ROOT, "results/biology_validation/tables/known_gene_discrimination.csv"))[dataset_name %in% names(DS_SET), .(method, dataset = dataset_name, auroc_paper = auroc, p_paper = auc_p, R_paper = R, N_paper = N)]
pap_s <- fread(file.path(ROOT, "results/sc_new/sc_known_gene_discrimination.csv"))[, .(method = method_raw, dataset = dataset_name, auroc_paper = auroc, p_paper = p, R_paper = R, N_paper = N)]
pap <- rbind(pap_b, pap_s)
chk <- merge(obs_tab, pap, by = c("method", "dataset"), all = TRUE)
chk[, `:=`(d_auroc = abs(auroc - auroc_paper), rd_p = abs(mw_p - p_paper) / pmax(p_paper, 1e-300), ok_RN = R == R_paper & N == N_paper)]
msg("reproduction: ", nrow(chk), " method x dataset pairs; max |dAUROC| = ", signif(max(chk$d_auroc), 3),
    "; max relative dP = ", signif(max(chk$rd_p), 3), "; R,N all equal = ", all(chk$ok_RN))
fwrite(chk[, .(dataset, method, auroc, auroc_paper, d_auroc, mw_p, p_paper, rd_p, R, R_paper, N, N_paper)], file.path(WORK, "reproduction_check.csv"))
pt10 <- fread(file.path(ROOT, "results/biology_validation/tables/top10_enrichment_ratio_per_dataset.csv"))
if (nrow(pt10)) {
  pt10[, key := method]
  lab_of <- c(Logistic="sklearn-logit", XGBoost="sklearn-xgboost", `Random Forest`="sklearn-random_forest", `DIABLO-F`="diablo-full", `DIABLO-N`="diablo-null",
              `RGCCA-F`="rgcca-full", `RGCCA-N`="rgcca-null", `MOFA+`="mofa", IntegrAO="integrao", `Cooperative Learning`="cooperative_learning",
              caretMultimodal="caret_multimodal", MOGONET="mogonet")
  pt10[, method := lab_of[key]]
  ct <- merge(obs_tab, pt10[, .(method, dataset = dataset_name, er = enrichment_ratio)], by = c("method", "dataset"))
  msg("top-10% ratio reproduction: n = ", nrow(ct), ", max |d| = ", signif(max(abs(ct$top10_ratio - ct$er)), 3))
}
if (any(is.na(chk$d_auroc)) || max(chk$d_auroc) > 1e-6 || max(chk$rd_p) > 1e-3 || !all(chk$ok_RN))
  stop("REPRODUCTION FAILED: see ", file.path(WORK, "reproduction_check.csv"))

# ------------------------------------------------------------------ premise: features per gene, known vs other
one_multi <- function(d, label) {
  x <- d[, .(nf = .N), by = .(gene_id, known)]
  k <- x[known == TRUE, nf]; o <- x[known == FALSE, nf]
  if (length(k) == 0 || length(o) == 0) return(NULL)
  rk <- rank(x$nf); aur <- (sum(rk[x$known]) - length(k) * (length(k) + 1) / 2) / (length(k) * length(o))
  p <- if (uniqueN(x$nf) > 1) suppressWarnings(wilcox.test(k, o, alternative = "greater")$p.value) else NA_real_
  data.table(view = label, n_features = nrow(d), n_genes = nrow(x), n_known = length(k),
             known_fraction = length(k) / nrow(x), mean_fpg_known = mean(k), mean_fpg_other = mean(o),
             median_fpg_known = as.numeric(median(k)), median_fpg_other = as.numeric(median(o)), max_fpg = as.numeric(max(x$nf)),
             frac_multi_known = mean(k > 1), frac_multi_other = mean(o > 1),
             auroc_of_fpg = aur, mw_p_known_more = p)
}
keep_pairs <- obs_tab[, .(method, dataset)]
fpg <- rows[scored == TRUE][keep_pairs, on = .(method, dataset)][, {
  v <- rbindlist(lapply(unique(view), function(w) one_multi(.SD[view == w], w)))
  rbind(one_multi(.SD, "ALL_SCORED_VIEWS"), v)
}, by = .(dataset, method)]
fpg[, disease := DS_SET[dataset]]
keyc <- setdiff(names(fpg), c("method"))
fpg_c <- fpg[, .(methods = paste(sort(method), collapse = ";"), n_methods = .N), by = keyc]
setcolorder(fpg_c, c("disease", "dataset", "view", "methods", "n_methods"))
setorder(fpg_c, disease, dataset, view)
fwrite(fpg_c, file.path(OUT, "features_per_gene_check.csv"))

# ------------------------------------------------------------------ permutation engine
make_job <- function(d, pool = c("scored", "view")) {
  pool <- match.arg(pool)
  # d: one method x dataset, one row per feature. Unscored rows take part in the permutation only if pool == "view".
  if (pool == "scored") d <- d[scored == TRUE]
  sc_rows <- which(d$scored)
  gid <- match(d$gene_id[sc_rows], unique(d$gene_id[sc_rows])); N <- max(gid)
  kn <- logical(N); kn[gid] <- d$known[sc_rows]
  # layers: j-th row of every gene, so that max-by-gene is a chain of vectorised pmax()
  ord <- order(gid); gs <- gid[ord]; fs <- sc_rows[ord]; lay <- sequence(tabulate(gs))
  layers <- lapply(seq_len(max(lay)), function(j) list(g = gs[lay == j], f = fs[lay == j]))
  list(s = d$s, vidx = unname(split(seq_len(nrow(d)), d$view)), layers = layers, known = kn, N = N, R = sum(kn))
}
gene_scores <- function(sp, job) {
  l <- job$layers; g <- sp[l[[1]]$f]
  if (length(l) > 1) for (j in 2:length(l)) { gj <- l[[j]]$g; g[gj] <- pmax(g[gj], sp[l[[j]]$f]) }
  g
}
perm_run <- function(job, B, seed) {
  set.seed(seed, kind = "L'Ecuyer-CMRG", sample.kind = "Rejection")
  au <- numeric(B); tp <- numeric(B); N <- job$N; R <- job$R; kn <- job$known; s <- job$s; v <- job$vidx
  c0 <- R * (R + 1) / 2; c1 <- R * (N - R)
  for (b in seq_len(B)) {
    sp <- s
    for (ix in v) sp[ix] <- s[ix[sample.int(length(ix))]]
    r <- rank(gene_scores(sp, job))
    au[b] <- (sum(r[kn]) - c0) / c1
    tp[b] <- mean(((N - r) / (N - 1))[kn] <= 0.1) / 0.1
  }
  list(auroc = au, top10 = tp)
}

# ---- validation of the fast engine against a literal rebuild on the full component rows:
# draw a within-view permutation of rows; the component weights of row i move to row perm[i]; gene score =
# max over the long table, as dplyr::summarise(max(abs(coef))) does in production.
validate_engine <- function(ds, m, nperm = 5) {
  frm <- fr[dataset == ds & method == m & scored == TRUE]
  d <- rows[dataset == ds & method == m & scored == TRUE]
  job <- make_job(d, "scored")
  a0 <- auroc_prod(gene_scores(job$s, job), job$known)
  stopifnot(abs(a0 - obs_tab[dataset == ds & method == m, auroc]) < 1e-10)
  set.seed(1); res <- numeric(nperm)
  for (i in seq_len(nperm)) {
    map <- d[, .(from = feature_id, to = feature_id[sample.int(.N)]), by = view]
    # fast: row scores moved
    sp <- d$s; sp[match(map$to, d$feature_id)] <- d$s[match(map$from, d$feature_id)]
    fast <- auroc_prod(gene_scores(sp, job), job$known)
    # literal: long table, each component weight moved with its row, gene label taken from the destination row
    long <- merge(frm[, .(view, from = feature_id, comp, abscoef)], map, by = c("view", "from"))
    dest <- unique(d[, .(to = feature_id, gene_id, known)])
    long <- merge(long, dest, by = "to")
    gs <- long[, .(g = max(abscoef)), by = .(gene_id, known)]
    res[i] <- abs(fast - auroc_prod(gs$g, gs$known))
  }
  max(res)
}
msg("engine vs literal rebuild, max |dAUROC|: ",
    paste(sapply(list(c("htx_cell_views", "mofa"), c("GSE38609", "diablo-full"), c("covid_organ", "rgcca-full")),
                 function(x) signif(validate_engine(x[1], x[2]), 3)), collapse = ", "))

# ------------------------------------------------------------------ jobs
jobs_tab <- obs_tab[, .(method, dataset)]
setorder(jobs_tab, dataset, method)
jobs_tab[, job := .I]
Bfun <- function(ds) if (ds %in% CANCER_DS) B_CANCER else B_NONCANCER
main_cache <- file.path(WORK, sprintf("null_scored_B%d_%d_seed%d.rds", B_NONCANCER, B_CANCER, SEED))
t_perm <- Sys.time()
if (file.exists(main_cache)) {
  res <- readRDS(main_cache)
} else {
  jl <- lapply(seq_len(nrow(jobs_tab)), function(i) make_job(rows[dataset == jobs_tab$dataset[i] & method == jobs_tab$method[i]], "scored"))
  cl <- makeCluster(NCORES); clusterExport(cl, c("perm_run", "gene_scores"))
  args <- lapply(seq_along(jl), function(i) list(job = jl[[i]], B = Bfun(jobs_tab$dataset[i]), seed = SEED + jobs_tab$job[i]))
  res <- parLapplyLB(cl, args, function(a) perm_run(a$job, a$B, a$seed), chunk.size = 1)
  stopCluster(cl)
  saveRDS(res, main_cache, compress = FALSE)
}
msg("main null: ", nrow(jobs_tab), " method x dataset pairs, ", round(as.numeric(difftime(Sys.time(), t_perm, units = "mins")), 1), " min on ", NCORES, " workers")

ns <- rbindlist(lapply(seq_along(res), function(i) {
  x <- res[[i]]$auroc; j <- jobs_tab[i]; o <- obs_tab[dataset == j$dataset & method == j$method]
  zc <- qnorm(0.95) * sqrt((o$N + 1) / (12 * o$R * (o$N - o$R)))     # AUROC at which MW p = 0.05, ties ignored
  data.table(method = j$method, dataset = j$dataset, B = length(x),
             emp_p = (1 + sum(x >= o$auroc - TOL)) / (1 + length(x)),
             null_mean = mean(x), null_sd = sd(x), null_q025 = unname(quantile(x, 0.025)), null_q975 = unname(quantile(x, 0.975)),
             null_frac_mw_nominal = mean(x >= 0.5 + zc))
}))
tab <- merge(obs_tab, ns, by = c("method", "dataset"))

# ------------------------------------------------------------------ BH families as in the paper
tab[, in_main_family := !method %in% MAIN_DROP]
tab[in_main_family == TRUE, `:=`(mw_fdr = p.adjust(mw_p, "BH"), emp_fdr = p.adjust(emp_p, "BH"), family_size = .N), by = dataset]
tab[, `:=`(mw_fdr12 = p.adjust(mw_p, "BH"), emp_fdr12 = p.adjust(emp_p, "BH")), by = dataset]
mk <- function(f, p) fifelse(!is.na(f) & f < 0.05, "*", fifelse(p < 0.05, "+", "ns"))
tab[, `:=`(sig_paper = mk(mw_fdr, mw_p), sig_new = mk(emp_fdr, emp_p))]
tab[, sig_change := fifelse(sig_paper == sig_new, paste0("unchanged (", sig_new, ")"), paste0(sig_paper, " -> ", sig_new))]
tab[in_main_family == FALSE, sig_change := "not in main family"]

# ------------------------------------------------------------------ cancer: method-level summary as in Fig 4A/D
Vstat <- function(x, mu) { z <- x - mu; z <- z[z != 0]; n <- length(z); if (!n) return(0); r <- rank(abs(z)); (sum(r[z > 0]) - n * (n + 1) / 4) / sqrt(n * (n + 1) * (2 * n + 1) / 24) }
cancer_jobs <- jobs_tab[dataset %in% CANCER_DS]
meth_sum <- rbindlist(lapply(unique(cancer_jobs$method), function(m) {
  j <- cancer_jobs[method == m]; stopifnot(nrow(j) == length(CANCER_DS))
  o <- obs_tab[method == m][match(j$dataset, dataset)]; n0 <- ns[method == m][match(j$dataset, dataset)]
  # permutations are independent between datasets, so row b of A is one draw of the 21-dataset vector
  A <- do.call(cbind, lapply(j$job, function(i) res[[i]]$auroc)); Tp <- do.call(cbind, lapply(j$job, function(i) res[[i]]$top10))
  V0 <- apply(A, 1, Vstat, mu = 0.5); Vo <- Vstat(o$auroc, 0.5)
  V0t <- apply(Tp, 1, Vstat, mu = 1); Vot <- Vstat(o$top10_ratio, 1)
  med0 <- apply(A, 1, median); nm_t <- colMeans(Tp)
  data.table(method = m, n_datasets = nrow(j),
             median_auroc = median(o$auroc), n_above_0.5 = sum(o$auroc > 0.5),
             wilcoxon_p_paper = suppressWarnings(wilcox.test(o$auroc, mu = 0.5, alternative = "greater")$p.value),
             mean_null_auroc_over_datasets = mean(n0$null_mean), max_null_auroc_mean = max(n0$null_mean),
             median_auroc_minus_null = median(o$auroc - n0$null_mean), n_above_null = sum(o$auroc > n0$null_mean),
             wilcoxon_p_null_centred = suppressWarnings(wilcox.test(o$auroc - n0$null_mean, mu = 0, alternative = "greater")$p.value),
             emp_p_signed_rank_stat = (1 + sum(V0 >= Vo - TOL)) / (1 + nrow(A)),
             emp_p_median_auroc = (1 + sum(med0 >= median(o$auroc) - TOL)) / (1 + nrow(A)),
             null_q025_median = unname(quantile(med0, .025)), null_q975_median = unname(quantile(med0, .975)),
             n_datasets_emp_p05 = sum(n0$emp_p < 0.05), n_datasets_mw_p05 = sum(o$mw_p < 0.05),
             top10_median_ratio = median(o$top10_ratio),
             top10_wilcoxon_p_paper = suppressWarnings(wilcox.test(o$top10_ratio, mu = 1, alternative = "greater")$p.value),
             top10_mean_null_ratio = mean(nm_t),
             top10_wilcoxon_p_null_centred = suppressWarnings(wilcox.test(o$top10_ratio - nm_t, mu = 0, alternative = "greater")$p.value),
             top10_emp_p_signed_rank_stat = (1 + sum(V0t >= Vot - TOL)) / (1 + nrow(A)))
}))
meth_sum[, in_main_family := !method %in% MAIN_DROP]
setorder(meth_sum, -in_main_family, wilcoxon_p_null_centred)
fwrite(meth_sum, file.path(OUT, "fig4_null_cancer_summary.csv"))

# ------------------------------------------------------------------ sensitivity: permute among ALL features of the view
# (including features production drops because they do not map to a gene). Non-cancer panel only.
noncancer <- jobs_tab[!dataset %in% CANCER_DS]
sens_cache <- file.path(WORK, sprintf("null_viewpool_B%d_seed%d.rds", B_SENS, SEED))
n_unscored <- rows[, .(n_feat = .N, n_unscored = sum(!scored)), by = .(dataset, method)]
if (!file.exists(sens_cache)) {
  js <- noncancer[n_unscored[n_unscored > 0], on = .(dataset, method), nomatch = NULL]
  sens <- list(js = js, sr = list())
  if (nrow(js)) {
    jobs_s <- lapply(seq_len(nrow(js)), function(i) make_job(rows[dataset == js$dataset[i] & method == js$method[i]], "view"))
    cl <- makeCluster(NCORES); clusterExport(cl, c("perm_run", "gene_scores"))
    sens$sr <- parLapplyLB(cl, lapply(seq_along(jobs_s), function(i) list(job = jobs_s[[i]], seed = SEED + 100000L + js$job[i])),
                           function(a, B) perm_run(a$job, B, a$seed)$auroc, B = B_SENS, chunk.size = 1)
    stopCluster(cl)
  }
  saveRDS(sens, sens_cache, compress = FALSE)
} else sens <- readRDS(sens_cache)
sens_tab <- if (nrow(sens$js)) rbindlist(lapply(seq_len(nrow(sens$js)), function(i) {
  j <- sens$js[i]; x <- sens$sr[[i]]; o <- obs_tab[dataset == j$dataset & method == j$method]
  data.table(dataset = j$dataset, method = j$method, n_unscored = j$n_unscored, sens_viewpool_p = (1 + sum(x >= o$auroc - TOL)) / (1 + length(x)), sens_viewpool_null_mean = mean(x))
})) else data.table(dataset = character(), method = character(), n_unscored = integer(), sens_viewpool_p = numeric(), sens_viewpool_null_mean = numeric())

# ------------------------------------------------------------------ mechanism: ignore views (multi-view datasets only)
# Permuting across ALL scored features of the dataset keeps only the feature count per gene, so the difference in null
# mean from the main null is the part of the inflation due to which views a gene is measured in (view weight scale).
pool_cache <- file.path(WORK, sprintf("null_acrossviews_B%d_seed%d.rds", B_SENS, SEED))
jp <- noncancer[dataset %in% rows[scored == TRUE, .(nv = uniqueN(view)), by = dataset][nv > 1, dataset]]
if (!file.exists(pool_cache)) {
  jobs_p <- lapply(seq_len(nrow(jp)), function(i) {
    jj <- make_job(rows[dataset == jp$dataset[i] & method == jp$method[i]], "scored")
    jj$vidx <- list(seq_along(jj$s)); jj })
  cl <- makeCluster(NCORES); clusterExport(cl, c("perm_run", "gene_scores"))
  sr_p <- parLapplyLB(cl, lapply(seq_along(jobs_p), function(i) list(job = jobs_p[[i]], seed = SEED + 200000L + jp$job[i])),
                      function(a, B) perm_run(a$job, B, a$seed)$auroc, B = B_SENS, chunk.size = 1)
  stopCluster(cl); saveRDS(sr_p, pool_cache, compress = FALSE)
} else sr_p <- readRDS(pool_cache)
pool_tab <- rbindlist(lapply(seq_len(nrow(jp)), function(i) {
  j <- jp[i]; x <- sr_p[[i]]; o <- obs_tab[dataset == j$dataset & method == j$method]
  data.table(dataset = j$dataset, method = j$method, acrossviews_null_mean = mean(x), acrossviews_p = (1 + sum(x >= o$auroc - TOL)) / (1 + length(x)))
}))
sens_tab <- merge(sens_tab, pool_tab, by = c("dataset", "method"), all = TRUE)

# ------------------------------------------------------------------ outputs
out <- merge(tab, sens_tab, by = c("dataset", "method"), all.x = TRUE)
out <- out[, .(disease, dataset, method, in_main_family, family_size, R, N, auroc,
               mw_p, mw_fdr, emp_p, emp_fdr, B, null_mean, null_q025, null_q975, null_sd,
               sig_paper, sig_new, sig_change, mw_fdr12, emp_fdr12, null_frac_mw_nominal,
               frac_zero, n_unique_scores = n_unique, top10_ratio, sens_viewpool_p, sens_viewpool_null_mean, acrossviews_null_mean, acrossviews_p)]
ordd <- c("autism", "DKD", "rejection", "covid", "cancer")
out[, ordr := match(disease, ordd)]; setorder(out, ordr, dataset, -auroc); out[, ordr := NULL]
fwrite(out, file.path(OUT, "fig4_null_results.csv"))
tp <- rows[scored == TRUE, .(n_rows = .N, n_views = uniqueN(view), frac_rows_zero = mean(s == 0), frac_rows_tied = 1 - uniqueN(s) / .N), by = .(dataset, method)]
fwrite(merge(tp, n_unscored, by = c("dataset", "method")), file.path(OUT, "fig4_null_ties_and_pools.csv"))
sink(file.path(WORK, "sessionInfo.txt")); print(sessionInfo()); sink()
msg("done; total ", round(as.numeric(difftime(Sys.time(), T0, units = "mins")), 1), " min")
