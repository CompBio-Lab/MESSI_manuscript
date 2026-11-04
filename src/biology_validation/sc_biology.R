# ==============================================================================
# sc_biology.R — known-disease-gene recovery for the single-cell datasets.
# Same idea as the bulk biology: rank each method's gene-level features by |coef| and
# test how well the ranking recovers known disease genes (discrimination AUROC).
# Datasets: covid_multiomics, covid_organ (COVID-19 host genes, Open Targets) and
# htx_cell_views (allograft-rejection genes, MSigDB Hallmark).
#
# VIEW HANDLING. Feature names are "<view>_<cell type>_<gene>" for the
# COVID datasets and "<cell type>_<gene>" for HTX; IntegrAO/MOGONET drop the view prefix
# ("<cell type>_<gene>" or bare "<gene>"). The gene symbol is the last "_"-token.
#   covid_multiomics: view "RNA"     = PBMC pseudobulk mRNA            -> scored
#                     view "Protein" = CITE-seq ADTs (CD73, CD270, ..) -> NOT genes, excluded
#   covid_organ:      view "RNA"     = AIRWAY pseudobulk mRNA (3,829)  -> scored
#                     view "Protein" = BLOOD/PBMC pseudobulk mRNA (20,612; mislabelled
#                                      "Protein" upstream, e.g. Protein_B sw mem_CCSER1) -> scored
#   htx_cell_views:   10 cell-type views of Xenium mRNA                -> all scored
# The previous version kept only view "RNA" for both COVID datasets and so dropped the
# blood mRNA of covid_organ (only the 386 airway genes were scored).
# The modality is taken from the feature-name prefix when present (RNA_/Protein_), because
# the sklearn feature table mis-assigns 42 "Protein_*" covid_organ features to view "RNA"
# (substring match on e.g. "RNASEK"); otherwise from the view column.
# Gene-level score per method x dataset = max |coef| over cell types, views and components.
# WINDOWS: feature files are pre-copied to short paths (data/processed/sc_src/) to dodge MAX_PATH.
# ==============================================================================
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(ggplot2); library(here)
})
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/common_helpers/method_labels.R"))
source(here::here("src/common_helpers/theme_messi.R"))   # house style
OUT <- here::here("results/sc_new"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
up <- function(x) toupper(unique(x[!is.na(x) & x != ""]))

# ---- gene sets ----------------------------------------------------------------
G <- here::here("data/raw/known_gene_sets")
covid_f <- Sys.glob(file.path(G, "OT-MONDO_0100096-COVID19-*.tsv"))[1]
covid <- suppressMessages(read_tsv(covid_f, show_col_types = FALSE))
COVID_GENES <- up(covid$symbol[covid$globalScore >= 0.1])
REJ_GENES <- up(msigdbr::msigdbr(species = "Homo sapiens", collection = "H") %>%
                  filter(gs_name == "HALLMARK_ALLOGRAFT_REJECTION") %>% pull(gene_symbol))
GENE_SETS <- list(covid = COVID_GENES, rejection = REJ_GENES)
cat("gene sets — COVID:", length(COVID_GENES), " rejection:", length(REJ_GENES), "\n")

DS_SET <- c(covid_multiomics = "covid", covid_organ = "covid", htx_cell_views = "rejection")

# ---- feature data (pre-copied short paths) ------------------------------------
SRC <- here::here("data/processed/sc_src")
read_feat <- function(f) {
  if (!file.exists(f)) stop("cannot find expected input (run src/prep/make_short_paths.sh): ", f)
  suppressMessages(read_csv(f, show_col_types = FALSE))
}
feat <- bind_rows(read_feat(file.path(SRC, "cov_feat.csv")), read_feat(file.path(SRC, "htx_feat.csv"))) %>%
  filter(dataset_name %in% names(DS_SET))
stopifnot("a single-cell dataset has no features" = setequal(unique(feat$dataset_name), names(DS_SET)))
feat <- feat %>%
  mutate(base_view = str_remove(view, "-(Factor\\d+|ncomp-\\d+)$"),
         pfx = str_match(feature, "^(RNA|Protein)_")[, 2],
         src_view = ifelse(dataset_name != "htx_cell_views" & !is.na(pfx), pfx, base_view),
         modality = case_when(
           dataset_name == "covid_multiomics" & src_view == "RNA"     ~ "PBMC mRNA",
           dataset_name == "covid_multiomics" & src_view == "Protein" ~ "ADT protein",
           dataset_name == "covid_organ"      & src_view == "RNA"     ~ "Airway mRNA",
           dataset_name == "covid_organ"      & src_view == "Protein" ~ "Blood mRNA",
           dataset_name == "htx_cell_views"                           ~ "Cell-type mRNA",
           TRUE ~ NA_character_),
         is_gene = !is.na(modality) & modality != "ADT protein",
         gene = toupper(str_extract(feature, "[^_]+$")))
stopifnot(!any(is.na(feat$modality)))
cat("\nfeatures by dataset x modality (distinct feature names, scored = is_gene):\n")
feat %>% distinct(dataset_name, modality, is_gene, feature) %>% count(dataset_name, modality, is_gene) %>%
  as.data.frame() %>% print()

feat <- feat %>% filter(is_gene, !is.na(gene), gene != "", !str_detect(gene, "^LOC|^HSA-|^[0-9]+$"))
cat("\ndistinct genes scored per dataset x modality:\n")
feat %>% distinct(dataset_name, modality, gene) %>% count(dataset_name, modality) %>% as.data.frame() %>% print()

rank_genes <- function(d) d %>% group_by(method, dataset_name, gene) %>%
  summarise(abscoef = max(abs(coef), na.rm = TRUE), .groups = "drop")

disc_fun <- function(ranked) ranked %>% group_by(method, dataset_name) %>%
  group_modify(~{
    set <- GENE_SETS[[DS_SET[[.y$dataset_name]]]]
    lab <- as.integer(.x$gene %in% set); R <- sum(lab); N <- length(lab)
    if (R < 3 || R == N) return(tibble())
    r <- rank(.x$abscoef)
    auroc <- (sum(r[lab == 1]) - R * (R + 1) / 2) / (R * (N - R))
    p <- suppressWarnings(wilcox.test(.x$abscoef[lab == 1], .x$abscoef[lab == 0], alternative = "greater")$p.value)
    tibble(disease = DS_SET[[.y$dataset_name]], auroc = auroc, p = p, R = R, N = N,
           frac_zero = mean(.x$abscoef == 0))
  }) %>% ungroup() %>%
  mutate(method_raw = method, method = method_label(method_raw), class = method_class(method_raw))

# ---- discrimination AUROC per method x dataset (all scored mRNA) ---------------
disc <- disc_fun(rank_genes(feat))
write_csv(disc, file.path(OUT, "sc_known_gene_discrimination.csv"))
cat("\n=== sc known-gene discrimination AUROC (all mRNA views) ===\n")
disc %>% select(dataset_name, method, auroc, p, R, N, frac_zero) %>%
  mutate(across(where(is.numeric), ~signif(.x, 3))) %>% arrange(dataset_name, desc(auroc)) %>%
  as.data.frame() %>% print()

# ---- covid_organ per organ (sensitivity: airway only vs blood only) -----------
disc_org <- feat %>% filter(dataset_name == "covid_organ") %>%
  group_split(modality) %>%
  lapply(function(d) disc_fun(rank_genes(d)) %>% mutate(modality = d$modality[1])) %>% bind_rows()
write_csv(disc_org, file.path(OUT, "sc_known_gene_discrimination_covid_organ_by_organ.csv"))
cat("\n=== covid_organ by organ ===\n")
disc_org %>% select(modality, method, auroc, p, R, N) %>% mutate(across(where(is.numeric), ~signif(.x, 3))) %>%
  arrange(modality, desc(auroc)) %>% as.data.frame() %>% print()

# ---- plotting (house style: theme_messi; colour = significance only) ----------
DS_LAB <- c(covid_multiomics = "COVID multiomics", covid_organ = "COVID organ",
            htx_cell_views = "Heart transplant")
lollipop <- function(d, b = 9) {
  d %>% mutate(method = method_factor_y(method), sig = sig_label(p < 0.05)) %>%
    ggplot(aes(auroc, method)) +
    geom_vline(xintercept = 0.5, linetype = REF_LINE$linetype, colour = REF_LINE$colour, linewidth = REF_LINE$linewidth) +
    geom_segment(aes(x = 0.5, xend = auroc, yend = method), colour = "grey70", linewidth = 0.5) +
    geom_point(aes(colour = sig), size = 2.2, show.legend = TRUE) +
    scale_colour_manual(values = SIG_COLORS, name = "One-sided Wilcoxon", drop = FALSE,
                        labels = c(significant = "p < 0.05", `not significant` = "p ≥ 0.05")) +
    labs(x = "Known-gene AUROC", y = NULL) + theme_messi(b) +
    theme_method_axis(levels(method_factor_y(d$method)))   # class colours from theme_messi.R CLASS_COLORS
}

# (1) MAIN panel C: heart transplant, Logistic as the only sklearn baseline
htx_main <- disc %>% filter(dataset_name == "htx_cell_views", !method %in% c("Random Forest", "XGBoost"))
pfmt <- function(p) ifelse(p < 0.001, "p<0.001", sprintf("p=%.2g", p))
pC <- lollipop(htx_main) +
  geom_text(data = htx_main %>% mutate(method = method_factor_y(method), sig = sig_label(p < 0.05), plab = pfmt(p), xlab = pmax(auroc, 0.5)),
            aes(x = xlab, label = plab, colour = sig), hjust = -0.2, size = 2.5, show.legend = FALSE) +
  scale_x_continuous(limits = c(0.45, 1.0), breaks = seq(0.5, 0.9, 0.1)) +
  labs(title = "HTX: rejection-gene recovery")
saveRDS(pC, file.path(OUT, "figure_sc_biology_htx_main.rds"))

# (2) SUPP: all methods incl. RF/XGB, all three datasets
nds <- n_distinct(disc$dataset_name)
pS <- lollipop(disc %>% mutate(dataset = factor(DS_LAB[dataset_name], levels = DS_LAB))) +
  facet_wrap(~dataset, nrow = 1) +
  labs(title = sprintf("Known-disease-gene recovery, all methods (%d single-cell datasets)", nds),
       caption = paste0("AUROC that a method's |coefficient| ranking places known genes above the other scored genes (0.5 = chance).\n",
                        "Gene sets: Open Targets COVID-19 host genes (COVID); MSigDB Hallmark allograft rejection (heart transplant).\n",
                        "Scored: COVID multiomics = PBMC mRNA (ADT protein view excluded); COVID organ = airway + blood mRNA; heart transplant = 10 cell-type views.\n",
                        "Random Forest / XGBoost: impurity importances from 10 trees, so most genes tie at zero (90-99.9%); their AUROC is uninformative.")) +
  theme(plot.caption = element_text(hjust = 0, size = 7.5, colour = "grey30"), plot.caption.position = "plot")
save_plot_both(pS, file.path(OUT, "figure_sc_biology_full.png"), width = 7, height = 4.8, dpi = 300)

# (3) SUPP: COVID only (Logistic baseline), incl. covid_organ per-organ sensitivity
PANELS <- c("COVID multiomics\nPBMC mRNA", "COVID organ\nairway + blood", "COVID organ\nairway only", "COVID organ\nblood only")
covid_d <- bind_rows(
  disc %>% filter(dataset_name != "htx_cell_views") %>%
    mutate(panel = ifelse(dataset_name == "covid_multiomics", PANELS[1], PANELS[2])),
  disc_org %>% mutate(panel = ifelse(modality == "Airway mRNA", PANELS[3], PANELS[4]))) %>%
  filter(!method %in% c("Random Forest", "XGBoost")) %>%
  mutate(panel = factor(panel, levels = PANELS))
nR <- covid_d %>% distinct(panel, R, N) %>% mutate(lab = sprintf("%s
%d/%d genes known", panel, R, N))
covid_d <- covid_d %>% mutate(panel = factor(nR$lab[match(panel, nR$panel)], levels = nR$lab[match(PANELS, nR$panel)]))
pCov <- lollipop(covid_d) + facet_wrap(~panel, nrow = 1) +
  scale_x_continuous(limits = c(0.38, 0.62), breaks = c(0.4, 0.5, 0.6)) +
  labs(title = "COVID-19 datasets: Open Targets host-gene recovery",
       caption = "AUROC of each method's |coefficient| gene ranking (0.5 = chance). Right two panels split COVID organ by organ
(sensitivity analysis). Random Forest / XGBoost omitted (mostly zero importances; see full version).") +
  theme(plot.caption = element_text(hjust = 0, size = 7.5, colour = "grey30"), plot.caption.position = "plot")
save_plot_both(pCov, file.path(OUT, "figure_sc_biology_covid.png"), width = 7, height = 3.6, dpi = 300)
message("[done] single-cell biology -> ", OUT)
