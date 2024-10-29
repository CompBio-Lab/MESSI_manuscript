# Load required libraries
library(flextable)
library(tidyverse)
library(here)
# ==================================
# These are to edit variables
DATASET_NAMES <- c(".")
NUM_PATIENTS <- c(".")
NUM_VARS <- c(".")

metadata_path <- here("data/parsed_metadata.csv")
# TODO: remember to add sex

# ==================================

metadata_df <- read.csv(metadata_path) |>
  filter(!str_detect(dataset_name, "sim")) %>%
  rename(dataset = dataset_name) %>%
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
  select(-subject_dimensions_list, -subject_dimensions) %>%
  mutate(total_number_feature = str_split(feat_dimensions, ",") %>%
           map_dbl(~ sum(as.numeric(.x)))) %>%
  mutate(dataset_dim = sample_size * total_number_feature) %>%
  rename(
    obs = sample_size,
    var = feat_dimensions
         ) %>%
  mutate(
    class1 = paste0("positive, ", sample(14:25, size=1)),
    class2 = paste0("normal, ", sample(14:25, size=1)),
    sex = "Female (40%)",
         )%>%
  select(-c("is_simulated", "positive_prop",
            "total_number_feature", "dataset_dim"))




# Create sample data
# data <- data.frame(
#   dataset = DATASET_NAMES,
#   num_patients = NUM_PATIENTS,
#   num_vars = NUM_VARS
# )

# Create the table with flextable


table <- flextable(metadata_df) %>%
  # Optionally set header
  set_header_labels(
    dataset = "Dataset",
    omics_names = "Omics",
    var = "Var",
    obs = "Obs",
    type = "Type",
    class1 = "Pos Class",
    class2 = "Neg Class",
    sex = "Sex"
  ) %>%
  theme_box() %>%
  autofit() %>%
  bg(i = seq(1, nrow(metadata_df), by = 2), bg = "grey90") %>%  # Light grey for alternate rows
  bg(part = "header", bg = "grey20") %>%                 # Dark color for header background
  color(part = "header", color = "white")


# Lastly should save this to output
table
save_as_image(table, "some_path.png")
