
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
    names = c("method", "dataset", "celltype"),
    too_many = "merge", too_few = "align_start"
  ) %>%
  #tidyr::separate_wider_delim(view, names = c("organ", "celltype"), delim = " | ") %>%
  group_by(method, dataset, celltype) %>%
  mutate(padj = p.adjust(pval, method="BH")) %>%
  ungroup() %>%
  # Clean up the pathway
  mutate(pathway = pathway %>%
           str_remove("^REACTOME_") %>%   # remove prefix
           str_replace_all("_", " ") %>%  # replace underscores with spaces
           str_to_title()
  ) %>%
  mutate(method = standardize_method_names(method))



thresholds <- c(0.001, 0.005, 0.01, 0.05, 0.1, 0.2, 0.5)

sig_counts <- df %>%
  dplyr::select(method, celltype, padj) %>%
  crossing(threshold = thresholds) %>%
  group_by(celltype, method, threshold) %>%
  summarise(
    n_sig = sum(padj < threshold, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(dataset=df$dataset |> unique() |>
           str_replace_all("_", " ") %>%  # replace underscores with spaces
           str_to_title())

text_size <- 48
#text_size <- 24
out_plot <- sig_counts %>%
  filter(threshold %in% c(0.2)) %>%
  mutate(threshold = paste0("FDR < ", threshold * 100, "%")) %>%
  ggplot(aes(x = n_sig,
             y = reorder(method, n_sig),
             fill=celltype)) +
  #scale_y_reordered() + # Crucial step to fix labels
  geom_bar(stat = "identity") +
  ylab("Method") +
  xlab("Number of Significant Pathways") +
  scale_x_continuous(expand = expansion(c(0, 0.12))) +
  facet_grid(dataset~threshold) +
  theme_bw(text_size) +
  theme(
    panel.grid.major.y = element_blank(),
    legend.position = "bottom",
  )
the_plot <- out_plot +
   ylab(NULL) +
   xlab(NULL) +
   theme(legend.position = "none")

#the_plot <- get_legend_35(
#  out_plot +
#    guides(fill=guide_legend(
#      nrow=5
#    ))
#) %>% ggdraw()



# For the legend
#ggsave("aaa.svg", the_plot, width=8, height=5, dpi=1200)


ggsave("aaa.svg", the_plot, width=12, height=18, dpi=1200)
