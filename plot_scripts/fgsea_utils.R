
summarize_by_collection <- function(data, collection, cutoff = 0.2) {
  data %>%
    dplyr::filter(gs_collection == collection, padj < cutoff) %>%
    dplyr::group_by(method, dataset) %>%
    dplyr::summarize(n_sig = n(), .groups = "drop") %>%
    dplyr::group_by(method, gs_collection) %>%
    dplyr::summarize(mean_n_sig = mean(n_sig),
              sd_n_sig = sd(n_sig),
              .groups = "drop")
}

add_manual_label <- function(df) {
  if (!"dataset" %in% colnames(df)) {
    stop("'dataset' column need to exist in the data, check if typo")
  }

  df %>%
    dplyr::mutate(
      organ_label = case_when(
        # Case for each dataset
        # First in the tcga ones
        str_detect(dataset, "tcga") ~ case_when(
          str_detect(dataset, "blca") ~ "urinary-bladder",
          str_detect(dataset, "brca") ~ "mammary-gland",
          str_detect(dataset, "chol") ~ "liver",
          str_detect(dataset, "esca") ~ "gi-tract",
          str_detect(dataset, "kich") ~ "kidney",
          str_detect(dataset, "kirc") ~ "kidney",
          str_detect(dataset, "meso") ~ "lungs", #~ "gi-tract",
          str_detect(dataset, "skcm") ~ "skin",
          str_detect(dataset, "stes") ~ "gi-tract",
          str_detect(dataset, "thca") ~ "thyroid",
          # Lastly base case is acc
          TRUE ~ "adrenal-glands"
        ),
        # Case for gse studies
        str_detect(dataset, "gse71669") ~ "urinary-bladder",
        str_detect(dataset, "gse38609") ~ "brain",
        # Lastly the base case here is rosmap
        TRUE ~ "brain"
      )
    )
}
