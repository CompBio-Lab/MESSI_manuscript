# Load required libraries
library(flextable)
library(dplyr)
library(stringr)
library(here)
# ==================================
# These are to edit variables
DATASET_NAMES <- c(".")
NUM_PATIENTS <- c(".")
NUM_VARS <- c(".")


# =================================================
# DATASET MANUAL ADD ON
# GSE38609, GSE71669, rosmap, tcga-blca,
# tcga-brca, tcga-kipan, tcga-thca
# =================================================
# Come in this order:


# And the response column labels
# The neg are comma separated
tcga_neg <- "stagei/stageii"
tcga_pos <- "stageiii/stageiv"
neg_col <- c(
  "control Cer" , # GSE38609
  "non-invasive bladder cancer", # GSE71669
  "normal control", # rosmap
  tcga_neg, # tcga-acc
  tcga_neg, # tcga-blca
  tcga_neg, # tcga-brca
  tcga_neg, # tcga-chol
  tcga_neg, # tcga-esca
  tcga_neg, # tcga-kich
  #tcga_neg, # tcga-kipan
  tcga_neg, # tcga-kirc
  tcga_neg, # tcga-meso
  tcga_neg, # tcga-skcm
  tcga_neg, # tcga-stes
  tcga_neg # tcga-thca
)

pos_col <- c(
  "autistic" , # GSE38609
  "invasive bladder cancer", # GSE71669
  "alzheimer's disease", # rosmap
  tcga_pos, # tcga-acc
  tcga_pos, # tcga-blca
  tcga_pos, # tcga-brca
  tcga_pos, # tcga-chol
  tcga_pos, # tcga-esca
  tcga_pos, # tcga-kich
  #tcga_pos, # tcga-kipan
  tcga_pos, # tcga-kirc
  tcga_pos, # tcga-meso
  tcga_pos, # tcga-skcm
  tcga_pos, # tcga-stes
  tcga_pos # tcga-thca
)

# Need to manually add the disease that it studies ....
# In this order:
# GSE38609, GSE71669, rosmap, tcga-blca, tcga-brca, tcga-kipan, tcga-thca
# GSE47592 is checking normal or cancerous tissue
# This function maps the disease name into its common name
map_disease_name_table_format <- function(dname) {
  # Make dataset to lower
  dataset <- tolower(dname)
  dplyr::case_when(
    # The bulk ones
    dataset == "gse38609" ~ "Autism",
    dataset == "tcga-stes" ~ "Stomach/Esophagus cancer",
    dataset == "gse71669" ~ "Bladder cancer 1",
    dataset == "tcga-acc" ~ "Adrenal Gland cancer",
    dataset == "tcga-kich" ~ "Kidney cancer",
    dataset == "tcga-meso" ~ "Pleura cancer",
    dataset == "tcga-skcm" ~ "Skin cancer",
    dataset == "tcga-brca" ~ "Breast cancer",
    dataset == "tcga-esca" ~ "Esophagus cancer",
    dataset == "tcga-kirc" ~ "Kidney cancer",
    dataset == "tcga-thca" ~ "Thyroid cancer",
    dataset == "tcga-blca" ~ "Bladder cancer 2",
    dataset == "rosmap" ~ "Alzheimer's Disease",
    # The multimodal
    dataset == "clinical_omics" ~ "Clinical-omics",
    dataset == "electrical_omics" ~ "Electrical-omics",
    dataset == "imaging_omics" ~ "Imaging-omics",
    # The single cell
    dataset == "htx_cell_views" ~ "Heart transplant-scRNAseq",
    dataset == "covid_multiomics" ~ "COVID19-multiomics",
    dataset == "covid_organ" ~ "COVID19-multiorgan",
    TRUE ~ "not mapped"
  )
}

map_dataset_name_table_format <- function(dataset) {
  # Make dataset to lower
  dplyr::case_when(
    # The bulk ones just remain their upper case ones
    # The multimodal
    dataset == "clinical_omics" ~ "Clinical-omics",
    dataset == "electrical_omics" ~ "Electrical-omics",
    dataset == "imaging_omics" ~ "Imaging-omics",
    # The single cell
    dataset == "htx_cell_views" ~ "GSE290577",
    dataset == "covid_multiomics" ~ "COVID19-multiomics",
    dataset == "covid_organ" ~ "COVID19-multiorgan",
    TRUE ~ toupper(dataset)
  )
}

map_modality_name_table_format <- function(dataset) {

}



library(readr)



# Load all metadata together and do a bind rows
p1 <- "data/raw/bulk_data/parsed_metadata.csv"
p2 <- "data/raw/multimodal_data/parsed_metadata.csv"
p3 <- "data/raw/sc_data/htx_data/parsed_metadata.csv"
p4 <- "data/raw/sc_data/covid_data/parsed_metadata.csv"
all_metadata_path <- c(p1, p2, p3, p4)
raw_metadata_df <- purrr::map(
  all_metadata_path, function(f) readr::read_csv(
    f,
    col_types = readr::cols(
      feat_dimensions = col_character(),
      subject_dimensions = col_character()),
    show_col_types = FALSE)
) |> bind_rows()
# Now clean it, this is metadata from filtered MAE/MuData
metadata_df <- raw_metadata_df |>
  # First drop irrelevant columns
  dplyr::select(-is_simulated) |>
  # Then rename dataset column
  dplyr::rename(dataset = dataset_name) |>
  # Chop the suffix of dataset and make it to upper
  mutate(dataset = str_remove(dataset, "_processed") |> str_to_lower()) |>
  # TODO: this should not show up kipan and chol
  filter(!dataset %in% c("tcga-chol", "tcga-kipan")) |>
  # Then specific mapping names
  mutate(
    disease = map_disease_name_table_format(dataset),
    dataset = map_dataset_name_table_format(dataset),
         # This is a specific util here, not like the one in commmon_utils/standardize_data_funs.R
    ) |>
  # Then expand the subjection dimensions
  mutate(subject_dimensions_list = str_split(subject_dimensions, ",")) |>
  mutate(
    sample_size = purrr::map_dbl(
      subject_dimensions_list, ~ case_when(
        all(.x == .x[1]) ~ as.numeric(.x[1]),
        TRUE ~ NA
      )
    )
  ) |>
  # Then remove these old columns after getting sample size
  dplyr::select(-c("subject_dimensions_list", "subject_dimensions")) |>
  # order it by dataset
  arrange(dataset) |>
  # Get relevant cols in order
  dplyr::rename(
    obs = sample_size,
    var = feat_dimensions
  ) |>
  # Lastly expand omic names and number of predictors
  tidyr::separate_rows(omics_names, var, sep = ",") %>%  # Split into rows
  # Standardize some col names
  mutate(
    omics_names = case_when(
      str_detect(tolower(omics_names), "meth") | omics_names == "epigenomics" ~ "cpg",
      str_detect(tolower(omics_names), "rppa") | omics_names == "proteomics" ~ "proteins",
      str_detect(tolower(omics_names), "rnaseq") | omics_names == "transcriptomics" ~ "mrna",
      str_detect(tolower(omics_names), "mirna") ~ "mirna",
      TRUE ~ omics_names
    )
  ) |>
  # Now further rename only for covid19 multiorgan
  mutate(
    omics_names = case_when(
      (dataset == "COVID19-multiorgan" & omics_names == "RNA") ~ "Airway",
      (dataset == "COVID19-multiorgan" & omics_names == "Protein") ~ "Blood",
      TRUE ~ omics_names
    )
  )

metadata_df |>
  filter(dataset == "TCGA-BLCA")

# Now also read in the raw metadata that are not filtered yet
pre_filter_metadata <- read_csv("data/raw/data_prefilter.csv", show_col_types = FALSE)


# And join both
# Set a custom order of datasets
dataset_order <- c(
  "GSE38609", "TCGA-STES", "GSE71669", "TCGA-ACC", "TCGA-KICH",
  "TCGA-MESO", "TCGA-SKCM", "TCGA-BRCA", "TCGA-ESCA", "TCGA-KIRC",
  "TCGA-THCA", "TCGA-BLCA", "ROSMAP", # All the bulks here
  "Clinical-omics", "Electrical-omics", "Imaging-omics", # All the multimodal here
  "GSE290577", "COVID19-multiomics", "COVID19-multiorgan"
)


# Use this as the starting point to add stuff
full_metadata_df <- left_join(metadata_df, pre_filter_metadata,
                              by=c("dataset", "omics_names" = "modality")) |>
  dplyr::rename(
    n_before = n_obs,
    n_after = obs,
    p_before = n_feature,
    p_after = var
    ) |>
  mutate(positive_n = ceiling(positive_prop * n_after)) |>
  # Then lastly bundle omics_names together by the omics_names and p before, and omics_nams and p after
  mutate(
    feat_before = paste0(omics_names, " (", p_before, ")"),
    feat_after = paste0(omics_names, " (", p_after, ")")
  ) %>%
  group_by(dataset, disease, n_before, n_after) %>%
  summarise(
    positive = paste0(positive_n, " - ", positive_prop) %>% unique() %>% paste(collapse = ", "),
    feat_before = paste0(feat_before, collapse = ","),
    feat_after = paste0(feat_after, collapse = ","),
    .groups = "drop"
  ) %>%
  # arrange order of columns
  dplyr::select(disease, n_after, positive,feat_before, feat_after, dataset) |>
  # Set order by of dataset
  mutate(dataset_levels = factor(dataset, levels=dataset_order)) |>
  arrange(dataset_levels)

full_metadata_df %>%
  filter(dataset == "TCGA-ESCA") %>%
  pull(feat_after)


full_metadata_df %>%
 write.csv("dataset_metadata.csv", row.names = FALSE)

