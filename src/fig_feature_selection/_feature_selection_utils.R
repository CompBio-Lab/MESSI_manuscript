suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)

# common_preprocessing <- function(df) {
#   workflow_prefix <- "NFCORE_MESSI_BENCHMARK:MESSI_BENCHMARK:"
#   df  %>%
#     # First remove workflow prefixes
#     mutate(
#       process = str_replace(process, workflow_prefix, "") |> tolower()
#     ) %>%
#     # Need to fix the cooperative learning name for regex matching later
#     mutate(process = str_replace_all(process, "cooperative_learning", "multiview")) %>%
#     # Second keep the cross validation workflows and select feature only
#     keep_relevant_process() %>%
#     {.}
#     # Third expand process into workflow/subworkflow/process action
#     # expand_process_col() %>%
#     # mutate(
#     #   method = case_when(
#     #     str_detect(tag, "sgcca") ~ "sgcca",
#     #     str_detect(tag, "rgcca") ~ "rgcca",
#     #     TRUE ~ method
#     #   )
#     # ) %>%
#     # # For the tcga ones use _ to replace it
#     # mutate(
#     #   tag = case_when(
#     #     # Only replace the first - to _ for tcga
#     #     str_detect(tag, "tcga") ~ str_replace(tag, "-", "_"),
#     #     TRUE ~ tag
#     #   )
#     # )
# }

# trace_df <- readr::read_tsv("data/raw/real_data_results/execution_trace.txt",
#                             col_types = readr::cols()) |>
#   select(process, tag) |>
#   common_preprocessing() |>
#   filter(str_detect(process, "feature_selection")) |>
#   mutate(
#     # Update the tag for tcga ones to replace first - to _
#     tag = case_when(
#         str_detect(tag, "tcga") ~ str_replace(tag, "-", "_"),
#         TRUE ~ tag
#       )
#     ) |>
#   mutate(
#     ncomp = str_extract(tag, "ncomp_\\d+") |> str_remove("ncomp_") |> as.integer(),
#     design = str_extract(tag, "design_(full|null)") %>% str_remove("design_")
#     ) |>
#   tidyr::separate_wider_delim(tag, delim="-", names=c("dataset", NA),
#                               too_many="merge", too_few="align_start") |>
#   tidyr::separate_wider_delim(process, delim=":", names=c(NA, "method"))  |>
#   mutate(
#     method = str_replace(method, "_select_feature", "")
#   ) |>
#   mutate(
#     method = case_when(
#       !(is.na(ncomp) | is.na(design)) ~ paste(
#         method,
#         paste("design", design, sep="_"),
#         sep="-"),
#       TRUE ~ method
#     )
#   ) |>
#   select(method, dataset)


wrangle_feat_selection <- function(df) {
  df %>%
    dtplyr::lazy_dt() %>%  # Translates dplyr to fast data.table
    rename(dataset = dataset_name) %>%

    # Fix mogonet feature naming
    mutate(feature = case_when(
      str_detect(method, "mogonet") ~ paste(view, feature, sep = "_"),
      TRUE ~ feature
    )) %>%

    # Remove problematic features
    filter(!(feature == "RNAseq_HiSeq_Gene_level_GAGE1" & dataset == "tcga-brca") &
             !(feature == "RNAseq_HiSeq_Gene_level_C8orf71" & dataset == "tcga-kipan")) %>%

    # Append view-related info to method
    mutate(method = case_when(
      str_detect(view, "Factor") ~ paste0(method, "-", str_extract(view, "Factor.*")),
      str_detect(view, "ncomp")  ~ paste0(method, "_", str_extract(view, "ncomp.*")),
      TRUE ~ method
    )) %>%

    # Final renaming of method
    mutate(method = case_when(
      str_detect(method, "gcca")        ~ paste0(method, " + lda"),
      str_detect(method, "mofa")        ~ paste0(method, " + glmnet"),
      str_detect(method, "cooperative") ~ "multiview",
      TRUE ~ method
    )) %>%

    as_tibble()  # Materialize result (computed now)
}
