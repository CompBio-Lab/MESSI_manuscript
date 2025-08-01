source("src/common_helpers/standardize_data_funs.R")



# Function to read and annotate each RDS file located in directory
read_and_annotate <- function(file) {
  result <- readRDS(file)

  # Extract file name
  #file_name <- basename(file)
  # Remove the _fgsea.rds suffix
  #core_name <- str_remove(file_name, "_fgsea\\.rds$")


  # Add columns for method and dataset
  result <- as_tibble(result)
  #  mutate(comb_name = core_name)

  return(result)
}

wrangle_data <- function(df) {
  df %>%
  mutate(
    comb_name = case_when(
      # Replace the first _ to - for diablo and rgcca
      str_detect(comb_name, "diablo|rgcca") ~ str_replace(comb_name, "_", "-"),
      # Rest no change
      TRUE ~ comb_name
    )
  ) %>%
    # HAVE TO DO IT IN TWO MUTATE
    mutate(
      comb_name = case_when(
        # Then replce the second _ to + for rgcca , first _ to + for mofa
        str_detect(comb_name, "mofa|rgcca") ~ str_replace(comb_name, "_", "+"),
        # Rest no change
        TRUE ~ comb_name
      )
    ) %>%
    # Remove any na entries in pval
    filter(!is.na(pval)) %>%
    dplyr::select(-c("leadingEdge", "log2err", "size")) %>%
    tidyr::separate_wider_delim(
      comb_name,
      names = c("method", "dataset"), delim="_",
      too_many = "merge", too_few = "align_start"
    ) %>%
    # Capitalize or to upper the method names
    mutate(method = standardize_method_names(method)) %>%
    dplyr::select(-c("ES", "NES"))
}



summarize_by_collection <- function(data, collection, cutoff = 0.2) {
  data %>%
    filter(gs_collection == collection, padj < cutoff) %>%
    group_by(method, dataset) %>%
    summarize(n_sig = n(), .groups = "drop") %>%
    group_by(method, gs_collection) %>%
    summarize(mean_n_sig = mean(n_sig),
              sd_n_sig = sd(n_sig),
              .groups = "drop")
}

add_manual_label <- function(df) {
  if (!"dataset" %in% colnames(df)) {
    stop("'dataset' column need to exist in the data, check if typo")
  }

  df %>%
    dplyr::mutate(
      # organ_label = case_when(
      #   # Case for each dataset
      #   # First in the tcga ones
      #   str_detect(dataset, "tcga") ~ case_when(
      #     str_detect(dataset, "blca") ~ "urinary-bladder,liver,immune-system",
      #     str_detect(dataset, "brca") ~ "mammary-gland,immune-system,liver",
      #     str_detect(dataset, "chol") ~ "liver,gi-tract,pancreas",
      #     str_detect(dataset, "esca") ~ "gi-tract,liver,immune-system",
      #     str_detect(dataset, "kich") ~ "kidney,liver,immune-system",
      #     str_detect(dataset, "kirc") ~ "kidney,liver,immune-system",
      #     str_detect(dataset, "meso") ~ "gi-tract,liver,immune-system",
      #     str_detect(dataset, "skcm") ~ "skin,immune-system,liver",
      #     str_detect(dataset, "stes") ~ "gi-tract,liver,immune-system",
      #     str_detect(dataset, "thca") ~ "thgi-tract,immune-system,liver",
      #     # Lastly base case is acc
      #     TRUE ~ "adrenal-glands,liver,immune-system"
      #   ),
      #   # Case for gse studies
      #   str_detect(dataset, "gse71669") ~ "urinary-bladder,liver,immune-system",
      #   str_detect(dataset, "gse38609") ~ "brain,immune-system,epithelium",
      #   # Lastly the base case here is rosmap
      #   TRUE ~ "brain,immune-system,skeletal-muscle"
      # )
      # )
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
