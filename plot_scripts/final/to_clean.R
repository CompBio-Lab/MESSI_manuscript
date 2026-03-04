
# --- Data ---
library(dplyr)
library(ggplot2)
library(tidyr)
library(forcats)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source("src/common_helpers/save_plot_both.R")




input_path <- "data/processed/sc/sc_covid_msigdbr_fgsea.csv"
msigdbr_pathways <- readRDS("data/processed/pathways_db/msigdbr_pathways_collection.rds")

raw_df <- data.table::fread(input_path)

# For the sc datasets should look at reactome pathways only
# Htx has mogonet in it, it has 3 views
df <- inner_join(
  raw_df, msigdbr_pathways,
  by = c("pathway" = "gs_name")
) %>%
  filter(gs_collection_name == "Reactome Pathways") %>%
  # Then in this one, need to readjust the pval later, so
  # rename its existing padj to another name
  dplyr::rename(old_padj = padj) %>%
  dplyr::select(-c("gs_collection")) %>%
  tidyr::separate_wider_delim(
    group, delim = " | ",
    names = c("method", "dataset", "view"),
    too_many = "merge", too_few = "align_start"
  ) %>%
  filter(dataset == "covid_multiomics") %>%
  tidyr::separate_wider_delim(view, names = c("organ", "celltype"), delim = " | ") %>%
  group_by(method, dataset, organ, celltype) %>%
  mutate(padj = p.adjust(pval, method="BH")) %>%
  ungroup() %>%
  # Clean up the pathway
  mutate(pathway = pathway %>%
           str_remove("^REACTOME_") %>%   # remove prefix
           str_replace_all("_", " ") %>%  # replace underscores with spaces
           str_to_title()
  ) %>%
  mutate(method = standardize_method_names(method))


# =============================================================================
# Amrit code
#setwd("~/Downloads")
#df <- read.csv("covid_multiomics_pathways.csv")


thresholds <- c(0.001, 0.005, 0.01, 0.05, 0.1, 0.2, 0.5)

sig_counts <- expand_grid(
  threshold = thresholds,
  method = unique(df$method)
) %>%
  rowwise() %>%
  mutate(
    n_sig = sum(
      df$padj < threshold &
        df$method == method,
      na.rm = TRUE
    )
  ) %>%
  ungroup()

#sig_counts

library(ggrepel)

ggplot(sig_counts,
       aes(x = n_sig,
           y = threshold,
           color = method)) +
  geom_point(size = 3) +
  geom_line() +

  # Label only threshold = 0.5
  geom_text_repel(
    data = sig_counts %>% filter(threshold == 0.2),
    aes(label = method),
    nudge_x = 0.05,
    direction = "y",
    hjust = 0,
    show.legend = FALSE
  ) +

  theme_bw() +
  labs(
    x = "Number of Significant Genes",
    y = "Adjusted p-value Threshold",
    color = "Cell Type"
  ) +
  scale_y_reverse() +
  scale_x_log10()


## method x celltype

library(dplyr)
library(tidyr)

thresholds <- c(0.001, 0.005, 0.01, 0.05, 0.1, 0.2, 0.5)

sig_counts <- df %>%
  dplyr::select(method, celltype, padj) %>%
  crossing(threshold = thresholds) %>%
  group_by(celltype, method, threshold) %>%
  summarise(
    n_sig = sum(padj < threshold, na.rm = TRUE),
    .groups = "drop"
  )


library(ggplot2)
library(ggrepel)

a=sig_counts %>%
  filter(celltype %in% c("B", "CD14 mono",
                         "CD16 mono", "CD4 T"))
ggplot(a, aes(x = n_sig,
              y = threshold,
              color = method,
              group = method)) +
  geom_point(size = 2) +
  geom_line() +

  # Label at threshold = 0.2 (adjust if desired)
  geom_text_repel(
    data = a %>% filter(threshold == 0.2),
    aes(label = method),
    direction = "y",
    hjust = 0,
    show.legend = FALSE,
    size = 3
  ) +

  facet_wrap(~ celltype, ncol = 1) +

  theme_bw() +
  theme(
    legend.position = "none",
    axis.text.x = element_text(size = 7)
  ) +
  labs(
    x = "Number of Significant Genes",
    y = "Adjusted p-value Threshold"
  ) +
  scale_y_reverse() +
  scale_x_log10()



### htx (across cells)
sig_counts <- df %>%
  dplyr::select(method, celltype, padj, organ) %>%
  crossing(threshold = thresholds) %>%
  group_by(celltype, method, threshold) %>%
  summarise(
    n_sig = sum(padj < threshold, na.rm = TRUE),
    .groups = "drop"
  )
sig_counts %>%
  filter(threshold %in% c(0.2)) %>%
  mutate(threshold = "FDR < 20%") %>%
  ggplot(aes(x = n_sig, y = reorder(method, n_sig),
             fill=celltype)) +
  geom_bar(stat = "identity") +
  facet_grid(~threshold, scales = "free")

### covid (across omics, across organ)
sig_counts <- df %>%
  select(method, celltype, padj, organ) %>%
  crossing(threshold = thresholds) %>%
  group_by(celltype, method, threshold, organ) %>%
  summarise(
    n_sig = sum(padj < threshold, na.rm = TRUE),
    .groups = "drop"
  )
sig_counts %>%
  filter(threshold %in% c(0.2)) %>%
  mutate(threshold = "FDR < 20%") %>%
  ggplot(aes(x = n_sig, y = reorder(method, n_sig),
             fill=celltype)) +
  geom_bar(stat = "identity") +
  facet_grid(organ~threshold, scales = "free")


## covid pathways
library(dplyr)
library(stringr)

df <- df %>%
  mutate(
    pathway = as.character(pathway),
    type = if_else(
      str_detect(pathway, regex("sars cov 2|late sars|spike|structural proteins|host interactions|therapeutics for sars",
                                ignore_case = TRUE)),
      "direct_sarscov2",
      "not related to covid"
    )
  )
dplyr::count(df, type, sort = TRUE)
df %>% distinct(pathway, type) %>% head(20)
sig_counts <- df %>%
  filter(padj < 0.2) %>%
  filter(type == "direct_sarscov2") %>%
  dplyr::select(method, celltype, type, organ) %>%
  group_by(celltype, method, type, organ) %>%
  summarise(
    n_sig = n(),
    .groups = "drop"
  )
sig_counts %>%
  ggplot(aes(x = n_sig, y = reorder(method, n_sig),
             fill=celltype)) +
  geom_bar(stat = "identity") +
  facet_grid(type~organ, scales = "free")

library(dplyr)
library(tidyr)
library(stringr)
library(ComplexHeatmap)

# 1) Ensure the key columns are plain atomic vectors (not list-columns)
df2 <- df %>%
  mutate(
    method   = as.character(method),
    pathway  = as.character(pathway),
    celltype = as.character(celltype),
    type     = as.character(type)
  )

# 2) Build table (use dplyr::count explicitly)
a <- df2 %>%
  filter(padj < 0.2, type == "direct_sarscov2") %>%
  transmute(
    method_celltype = paste(method, celltype, sep = "_"),
    pathway = pathway
  ) %>%
  dplyr::count(method_celltype, pathway, name = "n") %>%
  pivot_wider(names_from = pathway, values_from = n, values_fill = 0)

# 3) Matrix with proper rownames
nes <- a %>% select(-method_celltype) %>% as.matrix()
# rownames(nes) <- a$method_celltype

# 4) Row annotation: method + celltype
row_ha <- rowAnnotation(
  method   = str_replace(a$method_celltype, "_.*$", ""),
  celltype = str_replace(a$method_celltype, "^[^_]+_", "")
)
method=str_replace(a$method_celltype, "_.*$", "")

Heatmap(
  nes,
  name = "n_sig",
  left_annotation = row_ha,
  row_title = "Method_Celltype",
  column_title = "Pathway",
  cluster_rows = FALSE,
  split = method
)


# -----------------------------
# Organ transplantation pathway categories
# -----------------------------
df <- df %>%
  mutate(
    pathway = as.character(pathway),
    type = if_else(
      str_detect(pathway, regex("mhc|antigen presentation|allograft|histocompatibility",
                                ignore_case = TRUE)),
      "allograft_rejection_mhc",
      "not related to organ rejection"
    )
  )

