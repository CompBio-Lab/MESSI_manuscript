# Load required libraries
library(flextable)
library(tidyverse)
library(here)
# ========================================
# These are to edit variables
#DATASET_NAMES <- c(".")
#NUM_PATIENTS <- c(".")
#NUM_VARS <- c(".")
metadata_path <- here("data/parsed_metadata.csv")
# TODO: remember to add sex

# Helper to separate params out
# Function to separate parameters
separate_params <- function(dataset) {
  # Extract the parameters part after "sim-data"
  params_string <- str_extract(dataset, "sim-data_(.*)$")

  # Split parameters into key-value pairs
  params_split <- str_split(params_string, "_")[[1]]

  # Further split each parameter into key and value
  params_key_value <- str_split(params_split, "-")

  # Create a data frame with parameter keys and values
  params_df <- bind_rows(lapply(params_key_value, function(x) {
    if (length(x) == 2) {
      tibble(param = x[1], value = x[2])
    } else {
      tibble(param = x[1], value = NA)
    }
  })) %>%
    mutate(dataset = dataset)  # Add the dataset column for tracking

  return(params_df)
}


# ========================================
# This would only look into simulated data
metadata_df <- read.csv(metadata_path) |>
  filter(str_detect(dataset_name, "sim")) %>%
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




# Apply the function to the dataset and combine into a single data frame
separated_params <- metadata_df %>%
  pull(dataset) %>%
  lapply(separate_params) %>%
  bind_rows() %>%
  pivot_wider(names_from = param, values_from = value)

# Combine with original data
final_result <- metadata_df %>%
  select(-dataset) %>%  # Exclude original dataset column if needed
  bind_cols(separated_params) %>%
  mutate(dataset = paste0("sim_data-", row_number())) %>%
  mutate(across(everything(), ~ replace_na(., "N/A"))) %>%
  select(-c("sim")) %>%
  select(dataset, everything())



# Create sample data
# data <- data.frame(
#   dataset = DATASET_NAMES,
#   num_patients = NUM_PATIENTS,
#   num_vars = NUM_VARS
# )

# Create the table with flextable
missing_indices <- which(final_result == "N/A", arr.ind = T)
table <- flextable(final_result) %>%
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
  align(align = "center", part = "all") %>%
  valign(valign = "center", part = "header") %>%
  bg(part = "header", bg = "grey20") %>%
  bg(i = seq(1, nrow(final_result), by = 2), bg = "grey90") %>%  # Light grey for alternate rows
             # Dark color for header background
  # TODO: this is not working now?
  #bg(i = missing_indices[, "row"], j = missing_indices[, "col"], bg = "red") %>%
  color(part = "header", color = "white") %>%
  set_table_properties(width = 0.75, layout = "autofit")
# Lastly should save this to output
table
#save_as_image(table, "some_path.png")
