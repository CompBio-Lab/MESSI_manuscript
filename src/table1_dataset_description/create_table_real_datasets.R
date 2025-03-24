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
tcga_neg <- "stagei,stageii"
tcga_pos <- "stageiii,stageiv"
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
  tcga_neg, # tcga-kipan
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
  tcga_pos, # tcga-kipan
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
diseases <- c(
  "Autism" , # GSE38609
  "Bladder Cancer", # GSE71669
  "Alzheimer's Disease", # rosmap
  "Adrenocortical Carcinoma", # tcga-acc
  "Bladder Urothelial Carcinoma", # tcga-blca
  "Breast Invasive Carcinoma", # tcga-brca
  "Cholangiocarcinoma", # tcga-chol
  "Esophageal Carcinoma", # tcga-esca
  "Adenomas and Adenocarcinomas", # tcga-kich
  "Kidney Cancer", # tcga-kipan
  "Kidney Renal Clear Cell Carcinoma", # tcga-kirc
  "Mesothelioma", # tcga-meso
  "Skin Cutaneous Melanoma", # tcga-skcm
  "Stomach and Esophageal Carcinoma", # tcga-stes
  "Thyroid Carcinoma" # tcga-thca
)


metadata_path <- here("data/raw/real_data_results/parsed_metadata.csv")
# TODO: remember to add sex

# ==================================

metadata_df <- read.csv(metadata_path) |>
  #filter(!str_detect(dataset_name, "sim")) %>%
  dplyr::rename(dataset = dataset_name) %>%
  dplyr::filter(toupper(dataset) != "GSE47592") %>%
  mutate(dataset = str_remove(dataset, "_processed")) %>%
  mutate(subject_dimensions_list = str_split(subject_dimensions, ",")) %>%
  mutate(
    sample_size = purrr::map_dbl(
      subject_dimensions_list, ~ case_when(
        all(.x == .x[1]) ~ as.numeric(.x[1]),
        TRUE ~ NA
      )
    ),
    type = "bulk"
  ) %>%
  # Then remove these old columns after getting sample size
  dplyr::select(-c("subject_dimensions_list", "subject_dimensions", "is_simulated", "type")) %>%
  mutate(total_number_feature = str_split(feat_dimensions, ",") %>%
           purrr::map_dbl(~ sum(as.numeric(.x)))) %>%
  mutate(dataset_dim = sample_size * total_number_feature) %>%
  # order it by dataset
  arrange(dataset) %>%
  # Get relevant cols in order
  dplyr::rename(
    obs = sample_size,
    var = feat_dimensions
         ) %>%
  # Remove extra string
  mutate(omics_names = str_remove_all(omics_names, "_Gene_[lL]evel")) %>%
  # This is from kipan?
  mutate(omics_names = str_remove_all(omics_names, "gene_level")) %>%
  mutate(diseases = diseases,
         pos_col = pos_col,
         neg_col = neg_col) %>%
  mutate(dataset = toupper(dataset)) %>%
  distinct() %>%                       # Remove duplicate rows
  # Lastly expand omic names and number of predictors
  tidyr::separate_rows(omics_names, var, sep = ",") %>%  # Split into rows
  tidyr::separate_rows(neg_col, sep=",") %>%
  tidyr::separate_rows(pos_col, sep=",") %>%
  mutate(across(c(omics_names, var), trimws)) %>%
  dplyr::select(c("dataset", "obs", "diseases", "positive_prop", "omics_names", "var", "pos_col", "neg_col")) %>%
  as_tibble()

  # mutate(


  #   class1 = paste0("positive, ", sample(14:25, size=1)),
  #   class2 = paste0("normal, ", sample(14:25, size=1)),
  #   sex = "Female (40%)",
  #        )%>%
  # select(-c("is_simulated", "positive_prop",
  #           "total_number_feature", "dataset_dim"))

# Create sample data
# data <- data.frame(
#   dataset = DATASET_NAMES,
#   num_patients = NUM_PATIENTS,
#   num_vars = NUM_VARS
# )

# =======================================
write.csv(
  metadata_df,
  file = "data/processed/real_dataset_metadata.csv", row.names = F)


#
# # Create the table with flextable
# flex_table <- flextable(metadata_df) %>%
#   # Merge cells
#   merge_v(j = c("dataset", "obs", "diseases", "positive_prop")) %>%  # Merge grouped cells
#   theme_box() %>%                                                    # Add borders
#   # Optionally set header
#   set_header_labels(
#     dataset = "Dataset",
#     omics_names = "Omics",
#     diseases = "Disease",
#     var = "# of predictors",
#     obs = "# of subjects",
#     positive_prop = "Prop(Y=1)",
#     #type = "Type",
#     #class1 = "Pos Class",
#     #class2 = "Neg Class",
#     sex = "Sex"
#   ) %>%
#   autofit()

#
# color_table <- flex_table %>%
#   theme_vanilla() %>%
#   bg(bg = "#44B29C", part = "header") %>%
#   #align(i = 1, j = NULL, align = "center", part = "header") %>%
#   align(align="center", part="all") %>%
#   fontsize(size=16, part="all") %>%
#   fit_to_width(max_width = 9) %>%
#   fix_border_issues()
#
#
#   #
#   # flex_table %>%
#   # bg(i = seq(1, nrow(metadata_df), by = 2), bg = "lightblue") %>%  # Light grey for alternate rows
#   # bg(part = "header", bg = "grey20") %>%                 # Dark color for header background
#   # color(part = "header", color = "white")
#
#
#
#
# ggsave("new_table.png", plot = gen_grob(color_table), width = 9, height = 12)
#
# # Lastly should save this to output
# save_as_image(flex_table, "real_table.png")



