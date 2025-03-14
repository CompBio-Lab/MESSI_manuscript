# Load required libraries
library(flextable)
library(tidyverse)
library(here)
# ==================================
# These are to edit variables
DATASET_NAMES <- c(".")
NUM_PATIENTS <- c(".")
NUM_VARS <- c(".")

metadata_path <- here("data/raw/real_data_results/parsed_metadata.csv")
# TODO: remember to add sex

# ==================================

metadata_df <- read.csv(metadata_path) |>
  #filter(!str_detect(dataset_name, "sim")) %>%
  dplyr::rename(dataset = dataset_name) %>%
  mutate(dataset = str_remove(dataset, "_processed")) %>%
  mutate(subject_dimensions_list = str_split(subject_dimensions, ",")) %>%
  mutate(
    sample_size = map_dbl(
      subject_dimensions_list, ~ case_when(
        all(.x == .x[1]) ~ as.numeric(.x[1]),
        TRUE ~ NA
      )
    ),
    type = "bulk"
  ) %>%
  # Then remove these old columns after getting sample size
  select(-c("subject_dimensions_list", "subject_dimensions", "is_simulated", "type")) %>%
  mutate(total_number_feature = str_split(feat_dimensions, ",") %>%
           map_dbl(~ sum(as.numeric(.x)))) %>%
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
  select(c("dataset", "obs", "var", "positive_prop", "omics_names")) %>%
  as_tibble()
metadata_df
  # mutate(
  #   class1 = paste0("positive, ", sample(14:25, size=1)),
  #   class2 = paste0("normal, ", sample(14:25, size=1)),
  #   sex = "Female (40%)",
  #        )%>%
  # select(-c("is_simulated", "positive_prop",
  #           "total_number_feature", "dataset_dim"))


# Need to manually add the disease that it studies ....
diseases <- c("Bladder cancer", "Alzheimer Disease",
              "Bladder cancer", "Breast cancer",
              "Pan-Kidney", "Thyroid cancer")

metadata_df$diseases <- diseases
# Create sample data
# data <- data.frame(
#   dataset = DATASET_NAMES,
#   num_patients = NUM_PATIENTS,
#   num_vars = NUM_VARS
# )


# =======================================
write.csv(metadata_df, file = "data/processed/metadata_real.csv", row.names = F)



# Create the table with flextable
flex_table <- flextable(metadata_df) %>%
  # Optionally set header
  set_header_labels(
    dataset = "Dataset",
    omics_names = "Omics",
    diseases = "Disease",
    var = "Number of predictors",
    obs = "Number of subjects",
    positive_prop = "Proportion of positive cases",
    #type = "Type",
    #class1 = "Pos Class",
    #class2 = "Neg Class",
    sex = "Sex"
  ) %>%
  theme_box() %>%
  autofit()




color_table <- flex_table %>%
  bg(i = seq(1, nrow(metadata_df), by = 2), bg = "lightblue") %>%  # Light grey for alternate rows
  bg(part = "header", bg = "grey20") %>%                 # Dark color for header background
  color(part = "header", color = "white")




ggsave("new_table.png", plot = gen_grob(color_table), width = 6, height = 4)

# Lastly should save this to output
save_as_image(table, "real_table.png")



