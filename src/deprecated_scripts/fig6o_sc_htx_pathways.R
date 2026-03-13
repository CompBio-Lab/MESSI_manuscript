library(dplyr)
library(stringr)
library(ggplot2)
library(dplyr)
#library(ggtext)

source("src/common_helpers/save_plot_both.R")
source("src/common_helpers/plot_utils.R")
source("src/common_helpers/standardize_data_funs.R")

# --- Data ---
library(dplyr)
library(ggplot2)
library(tidyr)
library(forcats)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source("src/common_helpers/save_plot_both.R")

input_path <- "data/processed/sc/sc_htx_msigdbr_fgsea.csv"
msigdbr_pathways <- readRDS("data/processed/pathways_db/msigdbr_pathways_collection.rds")
df <- data.table::fread(input_path)

# For the sc datasets should look at reactome pathways only
# Htx has mogonet in it, it has 3 views
msigdbr_df <- inner_join(
  df, msigdbr_pathways,
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
  group_by(method, dataset, view) %>%
  mutate(padj = p.adjust(pval, method="BH")) %>%
  ungroup() %>%
  # Clean up the pathway
  mutate(pathway = pathway %>%
           str_remove("^REACTOME_") %>%   # remove prefix
           str_replace_all("_", " ") %>%  # replace underscores with spaces
           str_to_title()
  ) %>%
  mutate(method = standardize_method_names(method))


# define significance threshold
alpha <- 0.2

df_sig_counts <- msigdbr_df %>%
  filter(padj < alpha) %>%
  group_by(method, view) %>%
  summarise(n_sig_pathways = n(), .groups = "drop")


out_plot <- ggplot(df_sig_counts,
                   aes(y = method,
                       x = view,
                       fill = n_sig_pathways)) +
  geom_tile() +
  scale_fill_viridis_c() +
  theme_bw() +
  labs(
    y = "Method",
    x = "Cell Type",
    fill = "# Significant\nPathways"
  )


output_png_path <- "results/sc/fig6o_sc_htx_pathways.png"
save_plot_both(out_plot, output_png_path, width=12, height=8)
