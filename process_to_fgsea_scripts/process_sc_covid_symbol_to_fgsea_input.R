library(dplyr)
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
      mix_feat = str_remove(feature, paste0("^", view_cleaned, "_")),
      view = view_cleaned
    ) %>%
    dplyr::select(-view_cleaned) %>%
    as_tibble()
}

# Load the feature part
covid_gsea_input_list <- data.table::fread("data/raw/sc_data/covid_data//all_feature_selection_results.csv") %>%
  dplyr::select(-dataset_type, -feature_type) %>%
  wrangle_feat_selection() %>%
  distinct(mix_feat, view, dataset, coef, method) %>%
  tidyr::separate_wider_delim(
  mix_feat, names=c("celltype", "feat"), delim="_", too_many="merge"
  ) %>%
#Now for the covid one need to explode more info out from the feature
  mutate(stat = abs(coef)) %>%
  arrange(desc(stat)) %>%
  mutate(group = paste(method, dataset, view, celltype, sep = " | ")) %>%
  group_by(group) %>%
  summarise(stat_vec = list(setNames(stat, feat)), .groups = "drop") %>%
  tibble::deframe()

saveRDS(covid_gsea_input_list, "data/processed/sc/sc_covid_fgsea_list_input.rds")

