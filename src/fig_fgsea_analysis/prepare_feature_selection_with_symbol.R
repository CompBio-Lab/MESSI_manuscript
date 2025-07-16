doc <- "

This script is used to get and transform gene symbols of the features selection result
from real data

Usage:
  prepare_feature_selection_with_symbol.R [options]

Options:
  --input_path=INPUT_PATH       File to load the input of feat selection results
  --output_path=OUTPUT_PATH     File to output the transformed symbols
"


# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)


source(here::here("src/common_helpers/retrieve_sim_params.R"))
source(here::here("src/fig_fgsea_analysis/_parse_db_utils.R"))

# Custom functions

wrangle_feat_selection <- function(df) {
  df %>%
    dtplyr::lazy_dt() %>%
    dplyr::rename(dataset = dataset_name) %>%
    dplyr::select(method, view, dataset, feature, coef) %>%
    dplyr::mutate(
      method = case_when(
        str_detect(view, "ncomp") ~ paste(method, str_extract(view, "ncomp-\\d+"), sep = "-"),
        str_detect(view, "Factor") ~ paste(method, str_extract(view, "Factor\\d+"), sep = "-"),
        TRUE ~ method
      ),
      view_cleaned = case_when(
        str_detect(view, "ncomp") ~ str_remove(view, "-ncomp.*"),
        str_detect(view, "Factor") ~ str_remove(view, "-Factor.*"),
        TRUE ~ view
      ),
      feat = str_remove(feature, paste0("^", view_cleaned, "_")),
      view = view_cleaned
    ) %>%
    dplyr::select(-view_cleaned) %>%
    as_tibble()  # if you want to continue in tidyverse downstream
    # dplyr::rename(dataset = dataset_name) %>%
    # dplyr::select(method, view, dataset, feature, coef) %>%
    # dplyr::mutate(
    #   method = case_when(
    #     str_detect(view, "ncomp") ~ paste(method, str_extract(view, "ncomp-\\d+"), sep="-"),
    #     str_detect(view, "Factor") ~ paste(method, str_extract(view, "Factor\\d+"), sep="-"),
    #     TRUE ~ method
    #   )
    # ) %>%
    # dplyr::mutate(
    #   view = case_when(
    #     str_detect(view, "ncomp") ~ str_remove(view, "-ncomp.*"),
    #     str_detect(view, "Factor") ~ str_remove(view, "-Factor.*"),
    #     TRUE ~ view
    #   )
    # ) %>%
    # dplyr::mutate(feat =  str_remove(feature, paste0("^", view, "_")))
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

retry_safe <- function(f, ..., times = 3, wait = 3) {
  for (i in seq_len(times)) {
    try_result <- try(f(...), silent = TRUE)
    if (!inherits(try_result, "try-error")) return(try_result)
    Sys.sleep(wait)
    message(sprintf("Retrying [%d/%d] after failure...", i, times))
  }
  stop("All retries failed.")
}


# ===================================================================
# Actual block goes here


main <- function(input_path, output_path) {
  if (is.null(input_path)) {
    input_path <- "data/raw/real_data_results/all_feature_selection_results.csv"
  }

  if (is.null(output_path)) {
    output_path <- "data/processed/feat_selection_symbols.csv"
  }


  feat_df <- data.table::fread(here::here(input_path)) %>%
    wrangle_feat_selection() %>%
    distinct(feat, view, dataset, coef, method)

  # Then from here partition each into list
  # And look into those that do not have a symbol
  all_feats_list <- feat_df |>
    group_by(dataset, view) %>%
    summarize(feat = list(unique(feat)), .groups = "drop") %>%
    ungroup() %>%
    # Cell type views are not mapped
    # Methylation_Gene_level, RNAseq, rppa in tcgas are are mapped symbols already
    filter(view != "cc") %>%
    filter(!str_detect(tolower(dataset), "tcga") |
             !str_detect(tolower(view),"methylation|rnaseq|rppa")) %>%
    dplyr::mutate(name = paste(dataset, view, sep = "_")) %>%
    dplyr::select(name, feat) %>%
    tibble::deframe() %>%
    purrr::map(unlist)


  parsed_list_df <- map2_dfr(
    names(all_feats_list), tolower(names(all_feats_list)),
    function(dataset_view_comb, lower_name) {
      dat <- all_feats_list[[dataset_view_comb]]

      matched_symbol <- if (str_detect(lower_name, "tcga")) {
        retry_safe(handle_tcga_data, dat, dataset_view_comb)
      } else if (str_detect(lower_name, "gse")) {
        retry_safe(handle_geo_data, dat, dataset_view_comb)
      } else {
        retry_safe(handle_custom, dat, dataset_view_comb)
      }

      matched_symbol %>% mutate(comb = dataset_view_comb)
    }
  )


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
  data.table::fwrite(merged, file = here::here(output_path), row.names = F)
  message("\nSaved to ", output_path)

}

# Lastly call the main function
opt <- docopt::docopt(doc)
main(input_path=opt$input_path, output_path=opt$output_path)


