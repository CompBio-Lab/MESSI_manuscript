
# --- Data ---
library(stringr)
library(ComplexHeatmap)
library(dplyr)
library(ggplot2)
library(tidyr)
library(forcats)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source("src/common_helpers/save_plot_both.R")

input_path <- "data/processed/sc/sc_covid_organ_msigdbr_fgsea.csv"
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
    names = c("method", "dataset", "organ", "celltype"),
    too_many = "merge", too_few = "align_start"
  ) %>%
  filter(dataset == "covid_organ") %>%
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


## covid pathways
library(dplyr)
library(stringr)

new_df <- df %>%
  mutate(
    pathway = as.character(pathway),
    type = if_else(
      str_detect(pathway, regex("sars cov 2|late sars|spike|structural proteins|host interactions|therapeutics for sars",
                                ignore_case = TRUE)),
      "direct_sarscov2",
      "not related to covid"
    )
  ) %>%
  mutate(
    method   = as.character(method),
    celltype = as.character(celltype),
    type     = as.character(type)
  )
# 2) Build table (use dplyr::count explicitly)
wide_df <- new_df %>%
  filter(padj < 0.2, type == "direct_sarscov2") %>%
  transmute(
    method_celltype = paste(method, celltype, sep = " | "),
    pathway = pathway
  ) %>%
  dplyr::count(method_celltype, pathway, name = "n") %>%
  pivot_wider(names_from = pathway, values_from = n, values_fill = 0)
# 3) Matrix with proper rownames
nes <- wide_df %>% select(-method_celltype) %>% as.matrix()


# 4) Row annotation: method + celltype

# Celltype colors full legend
unique_celltypes <- sort(unique(new_df$celltype))
celltypes_cols <- scales::hue_pal()(length(unique_celltypes))
names(celltypes_cols) <- unique_celltypes


# But only show the celltypes that are present in the final matrix
celltypes_in_a <- str_remove(wide_df$method_celltype, ".*\\|") |> str_trim()
present_celltypes <- sort(unique(celltypes_in_a))
methods_in_a <- str_replace(wide_df$method_celltype, "\\s*\\|.*", "")
present_methods <- sort(unique(methods_in_a))

# ================
text_size <- 20
ht_opt(RESET=TRUE)
# Global option (affects all simple annotations)
#ht_opt(simple_anno_size = unit(30, "mm"))
# 4. Make the annotation
row_ha <- rowAnnotation(
  Celltype = factor(
    celltypes_in_a,
    levels = names(celltypes_cols)
  ),
  Method = factor(
    methods_in_a,
    levels = names(method_colors)  # ensure order and completeness
  ),
  simple_anno_size = unit(18, "mm"),
  col = list(Method = method_colors, Celltype = celltypes_cols),
  annotation_height= unit(3, "cm"),    # total block width
  annotation_legend_param = list(
    Celltype = list(
      at = present_celltypes,
      labels = present_celltypes,
      title_gp = gpar(fontsize = text_size, fontface = "bold"),  # legend title
      labels_gp = gpar(fontsize = text_size-2),                    # legend labels
      legend_height = unit(3, "cm")                       # size of legend keys
    ),
    Method = list(
      at = present_methods,
      labels = present_methods,
      title_gp = gpar(fontsize = text_size, fontface = "bold"),  # legend title
      labels_gp = gpar(fontsize = text_size-2),                    # legend labels
      legend_height = unit(5, "cm")                       # size of legend keys
    )
  ),
  #annotation_width = unit(2, "cm"),
  show_legend = c(Celltype = TRUE, Method = TRUE),
  annotation_name_gp = gpar(fontsize = text_size, fontface = "bold")
)

# ==================
# 5. Plot the heatmap

wrapped_text <- stringr::str_wrap(colnames(nes), 12)

colnames(nes) <- wrapped_text


ht <- Heatmap(
  nes,
  name = "n_sig",
  left_annotation = row_ha,
  #row_title = "Method_Celltype",
  row_title = NULL,
  column_title_gp = gpar(fontsize=text_size, fontface="bold"),
  column_title = "Pathway",
  cluster_rows = FALSE,
  split = methods_in_a,
  column_names_gp = gpar(fontsize=text_size),
  heatmap_legend_param = list(
    title_gp = gpar(fontsize = text_size, fontface = "bold"),  # legend title
    labels_gp = gpar(fontsize = text_size-2),                    # legend labels
    legend_height = unit(3, "cm")                       # size of legend keys
  )
)
ht

#
# # Draw heatmap and convert to grob
ht_grob <- grid.grabExpr(
  draw(ht, merge_legends = TRUE,
       heatmap_legend_side = "left",
       #show_heatmap_legend = FALSE,
        show_heatmap_legend = TRUE,
       #annotation_legend_side = "right",
       padding = unit(c(40, 0, 0, 0), "mm"),  # bottom, left, top, right
  )
)

ggsave("aaa.svg", ht_grob, width=10, height=18, dpi=1200)
