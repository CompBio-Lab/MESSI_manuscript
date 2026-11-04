# ==============================================================================
# recall_at_k.R  -- real known-gene ground truth
# Does a method's coefficient-ranked genes recover known disease genes? Features are
# returned densely, so the signal is the |coef| RANKING. We rank gene-level features
# by |coef| and measure Recall@k + top-k hypergeometric enrichment against a curated
# known-gene set per disease. Plus same-cancer momix<->TCGA concordance (no DB).
#
# Gene sets (data/raw/known_gene_sets/): NCG cancer (COSMIC-CGC canonical),
# Open Targets AD + DKD (globalScore thresholds), SFARI autism.
# Feature naming handled: TCGA symbols, MOMIX `exp_SYMBOL|ENTREZ` / `exp_SYMBOL.ENTREZ` / `exp_SYMBOL`,
# Illumina ILMN_* (GSE38609), Ensembl (rosmap). GSE71669 (unknown numeric probes) left out.
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(ggplot2); library(here)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/common_helpers/method_labels.R"))
G   <- here::here("data/raw/known_gene_sets")
OUT <- here::here("results/biology_validation"); dir.create(file.path(OUT,"tables"), recursive=TRUE, showWarnings=FALSE)
# Feature-selection data moved into final_classification_results/ — glob both bulk + multimodal.
RUNS <- c(Sys.glob(here::here("data/raw/final_classification_results/bulk/copied_results_*")),
          Sys.glob(here::here("data/raw/final_classification_results/multimodal/copied_results_*")),
          # fall back to the old flat location if present
          Sys.glob(here::here("data/raw/copied_results_*samplesheet_bulk")),
          Sys.glob(here::here("data/raw/copied_results_*samplesheet_multimodal")))
RUNS <- RUNS[dir.exists(RUNS)]
stopifnot("expected the bulk and multimodal runs" = length(RUNS) == 2)

# ------------------------------------------------------------------ known-gene sets
up <- function(x) toupper(unique(x[!is.na(x) & x!=""]))
ncg <- suppressMessages(read_tsv(file.path(G,"NCG_cancerdrivers_annotation_supporting_evidence.tsv"), show_col_types=FALSE))
ad  <- suppressMessages(read_tsv(file.path(G,"OT-MONDO_0004975-AD-associated-targets-10_2_2026-v26_09.tsv"), show_col_types=FALSE))
dkd <- suppressMessages(read_tsv(file.path(G,"OT-MONDO_0005016-DKD-associated-targets-10_2_2026-v26_09.tsv"), show_col_types=FALSE))
sfari <- suppressMessages(read_csv(file.path(G,"sfari_autism.csv"), show_col_types=FALSE))
GENE_SETS <- list(
  cancer = up(ncg$symbol[!is.na(ncg$cgc_annotation) & ncg$cgc_annotation!=""]),  # COSMIC-CGC canonical
  AD     = up(ad$symbol[ad$globalScore >= 0.3]),
  DKD    = up(dkd$symbol[dkd$globalScore >= 0.1]),
  autism = up(sfari$`gene-symbol`))
message("[gene sets] ", paste(names(GENE_SETS), sapply(GENE_SETS, length), sep="=", collapse=", "))

# dataset -> gene set. Cancer = 20 TCGA/momix + clinical_omics (metastasis vs primary).
CANCER_DS <- c("tcga-acc","tcga-blca","tcga-brca","tcga-esca","tcga-kich","tcga-kirc",
               "tcga-meso","tcga-skcm","tcga-stes","tcga-thca","momix-aml","momix-breast",
               "momix-colon","momix-gbm","momix-kidney","momix-liver","momix-lung",
               "momix-melanoma","momix-ovarian","momix-sarcoma","clinical_omics")
DS_SET <- c(setNames(rep("cancer", length(CANCER_DS)), CANCER_DS),
            imaging_omics = "DKD", rosmap = "AD", GSE38609 = "autism")
# gene-level views: direct symbols (RNAseq.../exp/rna), Illumina probes (mrna, GSE38609),
# Ensembl IDs (genomics, rosmap). GSE71669 (numeric probes, unknown platform) left out.
GENE_VIEWS <- c("RNAseq_HiSeq_Gene_level", "exp", "rna", "mrna", "genomics")

# Map a raw feature id to a HGNC symbol: ILMN_* via illuminaHumanv4, ENSG* via org.Hs,
# everything else assumed to already be a symbol.
suppressPackageStartupMessages({library(AnnotationDbi); library(org.Hs.eg.db); library(illuminaHumanv4.db)})
map_symbol <- function(raw) {
  raw <- as.character(raw); out <- toupper(raw)
  ilmn <- str_detect(raw, "^ILMN_"); ens <- str_detect(raw, "^ENSG")
  if (any(ilmn)) {
    m <- suppressMessages(AnnotationDbi::mapIds(illuminaHumanv4.db, keys = raw[ilmn],
          column = "SYMBOL", keytype = "PROBEID", multiVals = "first"))
    out[ilmn] <- toupper(unname(m))
  }
  if (any(ens)) {
    m <- suppressMessages(AnnotationDbi::mapIds(org.Hs.eg.db, keys = str_remove(raw[ens], "\\.\\d+$"),
          column = "SYMBOL", keytype = "ENSEMBL", multiVals = "first"))
    out[ens] <- toupper(unname(m))
  }
  out
}

# ------------------------------------------------------------------ load features -> ranked genes
feat <- bind_rows(lapply(RUNS, function(d){
  f <- file.path(d,"all_feature_selection_results.csv")
  # file.exists() is also FALSE for paths over the Windows MAX_PATH limit; never skip silently
  if(!file.exists(f)) stop(sprintf("cannot find expected input (path length %d): %s", nchar(f), f))
  suppressMessages(read_csv(f, show_col_types=FALSE))
})) %>% filter(dataset_name %in% names(DS_SET)) %>%
  mutate(base_view = str_remove(view, "-(ncomp-\\d+|Factor\\d+)$")) %>% filter(base_view %in% GENE_VIEWS)
stopifnot("a dataset in DS_SET has no gene-level features" = setequal(unique(feat$dataset_name), names(DS_SET)))
feat <- feat %>%
  # strip view prefix and the MOMIX Entrez suffix ("XIST|7503" or "XIST.7503"); ENSG versions handled in map_symbol
  mutate(raw = str_remove(str_remove(feature, paste0("^", base_view, "_")), "\\|\\d+$"))
# The ".ENTREZ" suffix is stripped ONLY in datasets whose gene view is in that format (5 MOMIX
# cancers: aml, liver, melanoma, ovarian, sarcoma) -- elsewhere a trailing ".1" is part of a name
# (e.g. lncRNA clone "RP11-35N6.1") and must not be cut.
dot_fmt <- feat %>% filter(!str_detect(raw, "^(ENSG|ILMN_)")) %>% group_by(dataset_name) %>%
  summarise(f = mean(str_detect(raw, "\\.\\d+$")), .groups = "drop") %>% filter(f > 0.9) %>% pull(dataset_name)
message("[parse] '.ENTREZ' gene-name format in: ", paste(dot_fmt, collapse = ", "))
feat <- feat %>%
  mutate(raw = ifelse(dataset_name %in% dot_fmt, str_remove(raw, "\\.\\d+$"), raw),
         # R make.names() turned hyphens into dots in the dot-format MOMIX files and clinical_omics
         # ("NKX2.5" = NKX2-5, "HLA.DRA" = HLA-DRA); real HGNC symbols contain no dots.
         raw = ifelse(str_detect(raw, "^(ENSG|ILMN_)"), raw, str_replace_all(raw, "\\.", "-")))
feat$gene <- map_symbol(feat$raw)
feat <- feat %>% filter(!is.na(gene), gene!="", !str_detect(gene, "^LOC|^HSA-|^\\d+$"))
ranked <- feat %>% group_by(method, dataset_name, gene) %>%
  summarise(abscoef = max(abs(coef), na.rm=TRUE), .groups="drop")
# gene-level rankings with known-gene flag (used by the Fig 4D "barcode" panel)
saveRDS(ranked %>% group_by(dataset_name) %>%
          mutate(known = gene %in% GENE_SETS[[DS_SET[[dplyr::first(dataset_name)]]]]) %>% ungroup(),
        file.path(OUT, "tables", "ranked_genes.rds"))

# ------------------------------------------------------------------ Recall@k + hypergeometric
KS <- c(50,100,200)
res <- ranked %>% group_by(method, dataset_name) %>%
  group_modify(~{
    g <- arrange(.x, desc(abscoef)); set <- GENE_SETS[[DS_SET[[.y$dataset_name]]]]
    N <- nrow(g); R <- length(intersect(g$gene, set)); if(R==0) return(tibble())
    bind_rows(lapply(KS, function(k){
      hit <- length(intersect(head(g$gene,k), set))
      tibble(disease=DS_SET[[.y$dataset_name]], k=k, recall=hit/R, hits=hit, n_known=R, N=N,
             p=phyper(hit-1, R, N-R, min(k, N), lower.tail=FALSE)) }))  # k capped at N (rosmap N=74)
  }) %>% ungroup()
write_csv(res, file.path(OUT,"tables","recall_at_k.csv"))
summ <- res %>% filter(k==100) %>% group_by(method) %>%
  summarise(mean_recall100=mean(recall), median_recall100=median(recall),
            frac_sig=mean(p<0.05), n_ds=n(), .groups="drop") %>% arrange(desc(mean_recall100))
write_csv(summ, file.path(OUT,"tables","recall_summary.csv"))
message("[recall@100] by method (real known-gene sets):"); print(as.data.frame(summ %>% mutate(across(where(is.numeric),~round(.x,3)))))

# gene-set sizes present in data (for Supp Table S2 #genes)
nknown <- res %>% filter(k==100) %>% distinct(dataset_name, disease, n_known) %>% arrange(disease, dataset_name)
write_csv(nknown, file.path(OUT,"tables","n_known_per_dataset.csv"))

# ------------------------------------------------------------------ metric: AUROC + odds ratio
# AUROC = how well a method's |coef| ranks KNOWN disease genes above the rest
# (0.5 = random, 1 = all known genes on top). Normalized, comparable across datasets,
# uses the FULL ranking (not one k). Plus Fisher odds ratio / p for the top-100.
disc <- ranked %>% group_by(method, dataset_name) %>%
  group_modify(~{
    set <- GENE_SETS[[DS_SET[[.y$dataset_name]]]]
    g <- arrange(.x, desc(abscoef)); lab <- as.integer(g$gene %in% set)
    R <- sum(lab); N <- length(lab); if (R < 3) return(tibble())
    rk <- rank(g$abscoef)
    auroc <- (sum(rk[lab == 1]) - R * (R + 1) / 2) / (R * (N - R))
    auc_p <- suppressWarnings(wilcox.test(g$abscoef[lab == 1], g$abscoef[lab == 0],
                                          alternative = "greater")$p.value)
    k <- 100; hit <- sum(lab[seq_len(min(k, N))])
    or <- (hit * ((N - R) - (k - hit))) / max((R - hit) * (k - hit), 1)
    fp <- fisher.test(matrix(c(hit, R - hit, k - hit, (N - R) - (k - hit)), 2),
                      alternative = "greater")$p.value
    tibble(disease = DS_SET[[.y$dataset_name]], auroc = auroc, auc_p = auc_p,
           odds_ratio = or, fisher_p = fp, R = R, N = N)
  }) %>% ungroup()
write_csv(disc, file.path(OUT, "tables", "known_gene_discrimination.csv"))
# clean display labels (shared manuscript notation) for all biology figures below
disc <- disc %>% mutate(method = method_label(method))
N_CANCER <- n_distinct(disc$dataset_name[disc$disease == "cancer"])
message("[datasets] cancer datasets with >=3 known genes: ", N_CANCER)
disc_summ <- disc %>% filter(disease == "cancer") %>% group_by(method) %>%
  summarise(mean_auroc = mean(auroc), median_auroc = median(auroc),
            frac_sig = mean(p.adjust(auc_p, "BH") < 0.05), n_ds = n(), .groups = "drop") %>%
  arrange(desc(mean_auroc))
message("[AUROC] known-cancer-gene discrimination by method:")
print(as.data.frame(disc_summ %>% mutate(across(where(is.numeric), ~round(.x, 3)))))
ord <- disc_summ$method
ds_ord <- disc %>% filter(disease == "cancer") %>% group_by(dataset_name) %>%
  summarise(m = mean(auroc), .groups = "drop") %>% arrange(desc(m)) %>% pull(dataset_name)

# ---- FIG A: AUROC heatmap (method x dataset), * = BH-significant ----
pa <- disc %>% filter(disease == "cancer") %>%
  mutate(method = factor(method, levels = rev(ord)), dataset_name = factor(dataset_name, levels = ds_ord),
         star = ifelse(p.adjust(auc_p, "BH") < 0.05, "*", "")) %>%
  ggplot(aes(dataset_name, method, fill = auroc)) +
  geom_tile(color = "white") + geom_text(aes(label = star), size = 5, vjust = 0.78) +
  scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B", midpoint = 0.5, name = "AUROC") +
  labs(title = "Do a method's feature weights rank known cancer genes highly?",
       subtitle = "AUROC of |coef| discriminating COSMIC-CGC genes (0.5 = random); * = FDR < 0.05",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank(), axis.text = element_text(color = "black"))
save_plot_both(pa, file.path(OUT, "auroc_heatmap_cancer.png"), width = 11, height = 5.5, dpi = 300)

# ---- FIG B: per-method AUROC summary ----
pb <- disc %>% filter(disease == "cancer") %>% mutate(method = factor(method, levels = rev(ord))) %>%
  ggplot(aes(auroc, method)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", color = "grey50") +
  geom_boxplot(outlier.shape = NA, fill = "grey95", color = "grey55", width = 0.6) +
  geom_jitter(aes(color = p.adjust(auc_p, "BH") < 0.05), height = 0.15, width = 0, size = 1.5, alpha = 0.85) +
  scale_color_manual(values = c("TRUE" = "#B2182B", "FALSE" = "grey60"), name = "FDR < 0.05") +
  labs(title = "Known-cancer-gene discrimination by method",
       subtitle = sprintf("AUROC across %d cancer datasets (0.5 dashed = random)", N_CANCER), x = "AUROC", y = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom", panel.grid.minor = element_blank(), axis.text = element_text(color = "black"))
save_plot_both(pb, file.path(OUT, "auroc_summary_cancer.png"), width = 8, height = 5.5, dpi = 300)

# ---- FIG B2: cross-disease panel -> moved to figure4_biology.R (honest per-dataset version: autism
# and DKD are ONE dataset each, so each method gets its own per-dataset Mann-Whitney test, not a
# "consistent across three diseases" claim). It overwrites results/biology_validation/auroc_cross_disease.png.


# ---- FIG A (HEADLINE, main figure): per-method credibility across cancer datasets ----
# For each method, is its known-gene discrimination AUROC CREDIBLY above chance across
# all cancer datasets (N_CANCER = 21)? One-sample Wilcoxon signed-rank of per-dataset AUROC vs 0.5.
# Honest story = aggregate enrichment + reproducibility, NOT specific named genes
# (individual drivers bounce around; see README). Methods grouped by family so the
# reader sees that the joint latent-variable integrators light up and the rest do not.
FAMILY <- c(`DIABLO-F`="Multimodal integration", `DIABLO-N`="Multimodal integration",
            `MOFA+`="Multimodal integration", `RGCCA-F`="Multimodal integration",
            `RGCCA-N`="Multimodal integration", IntegrAO="Multimodal integration",
            MOGONET="Multimodal integration", `Multiview`="Multimodal integration",
            caretMultimodal="Multimodal integration",
            Logistic="Concatenation baseline", XGBoost="Concatenation baseline",
            `Random Forest`="Concatenation baseline")
cred <- disc %>% filter(disease == "cancer") %>% group_by(method) %>%
  summarise(median_auroc = median(auroc),
            p_vs_chance = suppressWarnings(wilcox.test(auroc, mu = 0.5, alternative = "greater")$p.value),
            n_above = sum(auroc > 0.5), n = n(), .groups = "drop") %>%
  mutate(credible = p_vs_chance < 0.05,
         family = factor(FAMILY[method],
                         levels = c("Multimodal integration", "Concatenation baseline"),
                         labels = c("Multimodal integration", "Baseline")),
         lab = ifelse(credible, sprintf("p=%.3g *", p_vs_chance), sprintf("p=%.2g", p_vs_chance)))
# Main figure keeps only the dense Logistic baseline: RF/XGBoost (n_estimators = 10) give zero
# importance to ~99% of genes, so their AUROC is pinned at 0.5 by ties. They are shown only in
# the supplementary full version with that caveat.
SPARSE_BASELINES <- c("Random Forest", "XGBoost")
plot_credibility <- function(drop = character(0), title, caption = NULL) {
  cr <- cred %>% filter(!method %in% drop)
  a_ord <- cr %>% arrange(median_auroc) %>% pull(method)
  dcan <- disc %>% filter(disease == "cancer", !method %in% drop) %>%
    left_join(cr %>% dplyr::select(method, credible, family), by = "method") %>%
    mutate(method = factor(method, levels = a_ord))
  xmax <- max(dcan$auroc, na.rm = TRUE)
  ggplot(dcan, aes(auroc, method)) +
    geom_vline(xintercept = 0.5, linetype = "dashed", color = "grey45") +
    geom_boxplot(aes(color = credible), outlier.shape = NA, fill = NA, width = 0.6, linewidth = 0.5) +
    geom_jitter(aes(color = credible), height = 0.16, width = 0, size = 1.3, alpha = 0.55) +
    stat_summary(aes(fill = credible), fun = median, geom = "point",
                 shape = 21, size = 2.8, color = "white", stroke = 0.6) +
    geom_text(data = cr %>% mutate(method = factor(method, levels = a_ord), xlab_pos = xmax + 0.015),
              aes(x = xlab_pos, y = method, label = lab, color = credible),
              hjust = 0, size = 3, show.legend = FALSE) +
    facet_grid(family ~ ., scales = "free_y", space = "free_y", switch = "y") +
    scale_color_manual(values = c(`TRUE` = "#B2182B", `FALSE` = "grey55"),
                       labels = c(`TRUE` = "credibly above chance (p < 0.05)", `FALSE` = "indistinguishable from chance"),
                       name = NULL, aesthetics = c("color", "fill")) +
    coord_cartesian(xlim = c(min(dcan$auroc, na.rm = TRUE), xmax + 0.07), clip = "off") +
    labs(title = title,
         subtitle = sprintf("Known-cancer-gene discrimination AUROC per dataset (%d datasets; dashed = chance).\n* = credibly above chance across datasets (one-sample Wilcoxon vs 0.5).", N_CANCER),
         caption = caption, x = "known-gene discrimination AUROC", y = NULL) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom", panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank(), axis.text = element_text(color = "black"),
          strip.text.y.left = element_text(angle = 90, face = "bold"),
          strip.placement = "outside", plot.title = element_text(face = "bold"),
          plot.caption = element_text(hjust = 0, size = 8.5, color = "grey30"),
          plot.margin = margin(6, 60, 6, 6))
}
cred_sig <- cred %>% filter(credible, !method %in% SPARSE_BASELINES) %>% pull(method)
message("[credible] ", paste(cred_sig, collapse = ", "))
pA <- plot_credibility(SPARSE_BASELINES,
  title = "DIABLO, RGCCA, MOFA+ and IntegrAO recover known cancer genes")
save_plot_both(pA, file.path(OUT, "auroc_credibility_main.png"), width = 9, height = 6, dpi = 300)
pA_full <- plot_credibility(character(0),
  title = "Known-cancer-gene recovery, all methods (incl. tree-based baselines)",
  caption = "Random Forest and XGBoost (n_estimators = 10) assign zero importance to 88-99.9% of genes (median 98.5%); their AUROC is therefore\npinned near 0.5 by ties and is not interpretable as absence of biological signal.")
save_plot_both(pA_full, file.path(OUT, "auroc_credibility_full_supp.png"), width = 9, height = 6.6, dpi = 300)
# auroc_credibility_cancer.csv is written ONLY by figure4_biology.R (superset: + mean_auroc), which

# ---- FIG C: concrete driver-gene prioritization heatmap ----
# percentile of each gene's |coef| rank (0 = top) per method x dataset
pct <- ranked %>% filter(dataset_name %in% CANCER_DS) %>% group_by(method, dataset_name) %>%
  mutate(pctile = (rank(-abscoef) - 1) / (n() - 1)) %>% ungroup()
# canonical drivers present in the most cancer datasets (interpretable, widely measured)
drv <- pct %>% filter(gene %in% GENE_SETS$cancer) %>% count(gene) %>% arrange(desc(n)) %>% head(25) %>% pull(gene)
drv_mat <- pct %>% filter(gene %in% drv) %>% group_by(method, gene) %>%
  summarise(med_pct = median(pctile), .groups = "drop")
m_ord <- drv_mat %>% group_by(method) %>% summarise(a = mean(med_pct), .groups = "drop") %>% arrange(a) %>% pull(method)
g_ord <- drv_mat %>% group_by(gene) %>% summarise(a = mean(med_pct), .groups = "drop") %>% arrange(a) %>% pull(gene)
pc2 <- drv_mat %>% mutate(method = factor(method, levels = rev(m_ord)), gene = factor(gene, levels = g_ord)) %>%
  ggplot(aes(gene, method, fill = med_pct)) +
  geom_tile(color = "white") +
  scale_fill_gradientn(colors = c("#B2182B", "#F7F7F7", "#2166AC"),
                       name = "median rank\npercentile (0 = top)", limits = c(0, 1)) +
  labs(title = "Where does each method rank canonical cancer-driver genes?",
       subtitle = "median |coef| rank-percentile across cancer datasets (red = ranked near top)",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 9) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank(), axis.text = element_text(color = "black"))
save_plot_both(pc2, file.path(OUT, "driver_gene_heatmap.png"), width = 12, height = 5.5, dpi = 300)

# ------------------------------------------------------------------ same-cancer concordance (no DB)
# Non-zero |coef| per (method, dataset): RF/XGBoost (n_estimators = 10) give importance to only a
# few dozen genes, so any top-k (k > #non-zero) is filled by arbitrary tie order.
nz <- ranked %>% group_by(method, dataset_name) %>%
  summarise(n_genes = n(), n_nonzero = sum(abscoef > 0), frac_nonzero = n_nonzero / n_genes, .groups = "drop")
write_csv(nz, file.path(OUT, "tables", "nonzero_genes_per_method.csv"))

PAIRS <- list(breast=c("momix-breast","tcga-brca"), kidney=c("momix-kidney","tcga-kirc"), melanoma=c("momix-melanoma","tcga-skcm"))
K_CONC <- 100
topk <- function(m, ds, k=K_CONC) ranked %>% filter(method==m, dataset_name==ds) %>% arrange(desc(abscoef)) %>% head(k) %>% pull(gene)
nzk  <- function(m, ds) sum(ranked$abscoef[ranked$method==m & ranked$dataset_name==ds] > 0)
conc <- bind_rows(lapply(names(PAIRS), function(pn) bind_rows(lapply(unique(ranked$method), function(m){
  a<-topk(m,PAIRS[[pn]][1]); b<-topk(m,PAIRS[[pn]][2]); if(!length(a)||!length(b)) return(NULL)
  ga <- ranked$gene[ranked$method==m & ranked$dataset_name==PAIRS[[pn]][1]]
  gb <- ranked$gene[ranked$method==m & ranked$dataset_name==PAIRS[[pn]][2]]
  # chance: two random top-k lists from the two gene universes -> E|overlap| = k^2 |shared| / (Na Nb)
  e_ov <- K_CONC^2 * length(intersect(ga, gb)) / (length(ga) * length(gb))
  tibble(pair=pn, method=m, jaccard=length(intersect(a,b))/length(union(a,b)),
         overlap=length(intersect(a,b)), expected_overlap=e_ov,
         expected_jaccard=e_ov/(2*K_CONC - e_ov), n_shared_genes=length(intersect(ga, gb)),
         # top-k is defined only if both rankings have >= k non-zero genes
         topk_defined = nzk(m, PAIRS[[pn]][1]) >= K_CONC & nzk(m, PAIRS[[pn]][2]) >= K_CONC) }))))
write_csv(conc, file.path(OUT,"tables","same_cancer_concordance.csv"))
conc <- conc %>% filter(topk_defined) %>% mutate(method = method_label(method))
cs <- conc %>% group_by(method) %>% summarise(mean_jaccard=mean(jaccard), .groups="drop") %>% arrange(desc(mean_jaccard))
pc <- conc %>% mutate(method=factor(method, levels=rev(cs$method))) %>%
  ggplot(aes(jaccard, method, color=pair)) + geom_point(size=2.6) +
  geom_point(aes(x = expected_jaccard), shape = 124, size = 3, show.legend = FALSE) +
  scale_color_brewer(palette="Dark2", name="same-cancer pair") +
  labs(title="Same-cancer gene-selection concordance (MOMIX ↔ TCGA)",
       subtitle="Jaccard of top-100 |coef| genes across two datasets of the same cancer (| = chance)",
       x="Top-100 Jaccard", y=NULL) +
  theme_minimal(base_size=11) + theme(legend.position="bottom", panel.grid.minor=element_blank(), axis.text=element_text(color="black"))
save_plot_both(pc, file.path(OUT,"same_cancer_concordance.png"), width=8, height=5.5, dpi=300)
message("[done] biology validation (real gene sets) -> ", OUT)
