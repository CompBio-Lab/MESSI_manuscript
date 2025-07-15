# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)


source(here::here("src/common_helpers/retrieve_sim_params.R"))
source(here::here("src/fig_fgsea_analysis/_parse_db_utils.R"))

# Custom functions

wrangle_feat_selection <- function(df) {
  df %>%
    dplyr::rename(dataset = dataset_name) %>%
    dplyr::select(method, view, dataset, feature, coef) %>%
    dplyr::mutate(
      method = case_when(
        str_detect(view, "ncomp") ~ paste(method, str_extract(view, "ncomp-\\d+"), sep="-"),
        str_detect(view, "Factor") ~ paste(method, str_extract(view, "Factor\\d+"), sep="-"),
        TRUE ~ method
      )
    ) %>%
    dplyr::mutate(
      view = case_when(
        str_detect(view, "ncomp") ~ str_remove(view, "-ncomp.*"),
        str_detect(view, "Factor") ~ str_remove(view, "-Factor.*"),
        TRUE ~ view
      )
    )
}

create_category <- function(view) {
  case_when(
    # For mirnomics
    str_detect(view, "miRNA") ~ "mirna",
    # For proteomics data
    str_detect(view, "RPPA") ~ "protein",
    # For epigenomics data
    str_detect(view, "Methylation") |
      str_detect(view, "cpg") |
      str_detect(view, "epigen") ~ "cpg",
    # For transcriptomics data
    str_detect(view, "RNAseq") |
      str_detect(view, "mrna")  |
      str_detect(view, "transcript") ~ "mrna",
    # Rest leave it as is
    TRUE ~ view
  )
}


# ===================================================================
# Actual block goes here
input_path <- "data/raw/real_data_results/all_feature_selection_results.csv"

df <- data.table::fread(input_path)

feat_df <- df %>%
  wrangle_feat_selection() %>%
  dplyr::mutate(feat =  str_remove(feature, paste0("^", view, "_"))) %>%
  distinct(feat, view, dataset, coef, method) %>%
  as_tibble()

# Then from here partition each into list
# And look into those that do not have a symbol
all_feats_list <- feat_df |>
  group_by(dataset, view) %>%
  summarize(feat = list(unique(feat)), .groups = "drop") %>%
  ungroup() %>%
  # Cell type views are not mapped
  # Methylation_Gene_level, RNAseq, rppa in tcgas are are mapped symbols already
  filter(view != "cc") %>%
  filter(!str_detect(tolower(dataset), "tcga") | !str_detect(tolower(view),"methylation|rnaseq|rppa")) %>%
  dplyr::mutate(name = paste(dataset, view, sep = "_")) %>%
  dplyr::select(name, feat) %>%
  deframe() %>%
  purrr::map(unlist)

# Now apply it different function for each item in list via lapply
# then combine it back as one single df
# NOTE: this part could FAIL from biomaRt, retry few times
parsed_list_df <- lapply(names(all_feats_list), function(dataset_view_comb) {
  # Extract the data from list
  # This is a vector already
  #print(dataset_view_comb)
  dat <- all_feats_list[[dataset_view_comb]]
  #print(rlang::sym(dataset_view_comb))
  # Now check if they belong to geo studies or tcga
  is_tcga <- str_detect(tolower(dataset_view_comb), "tcga")
  is_geo <- str_detect(tolower(dataset_view_comb), "gse")
  # Simplest case goes in tcga
  if (is_tcga) {
    matched_symbol <- handle_tcga_data(dat, dataset_view_comb)
  } else if (is_geo) {
    matched_symbol <- handle_geo_data(dat, dataset_view_comb)
  } else {
    # Lastly custom
    # In the moment only have rosmap
    matched_symbol <- handle_custom(dat, dataset_view_comb)
  }

  # Then for all these matched symbol add the dataset and view name into it back
  new_parsed <- matched_symbol %>%
    dplyr::mutate(comb = dataset_view_comb)
  return(new_parsed)

}) %>%
  bind_rows()


# Lastly combine both parsed symbols with original dataset that has symbol in it
merged <- feat_df %>%
  mutate(comb_label = paste(dataset, view, sep="_")) %>%
  left_join(parsed_list_df, by = c("comb_label" = "comb", "feat" = "feat"),
            relationship = "many-to-many") %>%
  dplyr::select(c("feat", "symbol", "coef", "view", "dataset", "method")) %>%
  # Now coerce the symbol for those that were already symbol in its feature name
  mutate(symbol = case_when(
    is.na(symbol) &
      str_detect(tolower(dataset), "tcga") &
      str_detect(tolower(view),"methylation|rnaseq|rppa") ~ feat,
    # Rest just keep it as it is
    TRUE ~ symbol
  )) %>%
  # And fix the method names
  mutate(
    method = case_when(
      str_detect(method, "cooperative_learning") ~ "multiview",
      str_detect(method, "mofa") ~ paste(method, "glmnet", sep = " + " ),
      str_detect(method, "rgcca|sgcca") ~ paste(method, "lda", sep = " + "),
      TRUE ~ method
    )
  ) %>%
  mutate(category = create_category(view)) %>%
  # And drop feat
  dplyr::select(-c(feat))



# And save this to file
data.table::fwrite(merged, file = "data/processed/feat_selection_symbols.csv", row.names = F)
