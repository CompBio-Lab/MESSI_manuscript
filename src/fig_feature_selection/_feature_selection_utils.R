suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)


# Custom function
wrangle_feat_selection <- function(df) {
  df %>%
  rename(dataset = dataset_name) %>%
  # Need to fix error for mogonet appending view in front of feature
  mutate(
    feature = case_when(
      str_detect(method, "mogonet") ~ paste(view, feature, sep="_"),
      TRUE ~ feature
    ),
    # Rename rgcca to sgcca
    method = case_when(
      str_detect(method, "rgcca") ~ "sgcca",
      TRUE ~ method
    )
  ) %>%
    # SGCCA has slight problem in missing a feature in tcga-brca and tcga-kipan???
    # So need to drop this
    filter(! (
      (feature == "RNAseq_HiSeq_Gene_level_GAGE1" & dataset == "tcga-brca") |
        (feature == "RNAseq_HiSeq_Gene_level_C8orf71" & dataset == "tcga-kipan")
    )
    ) %>%
    # Rename the method names
    mutate(
      method = case_when(
        str_detect(method, "sgcca") ~ "sgcca + lda",
        str_detect(method, "mofa") ~ "mofa + glmnet",
        str_detect(method, "cooperative") ~ "multiview",
        TRUE ~ method
      )
    )
}