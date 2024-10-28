# Load required libraries
library(flextable)
library(tidyverse)
library(here)
# ==================================
# These are to edit variables
METHOD_NAMES <- c("DIABLO", "MOGONET", "COOPERATIVE LEARNING")
NUM_PATIENTS <- c(".")
NUM_VARS <- c(".")


# Create sample data
data <- data.frame(
  method = METHOD_NAMES,
  type = c("GCCA", "Deep Learning", "Penalized Regression"),
  #accept_custom_data = c("yes", "no", "yes"),
  language = c("R", "Python", "R"),
  package = c("True", "False", "True"),
  code_repository = c("CRAN", "GitHub", "CRAN")
)

# Create the table with flextable


table <- flextable(data) %>%
  # Optionally set header
  theme_box() %>%
  autofit() %>%
  bg(i = seq(1, nrow(data), by = 2), bg = "grey90") %>%  # Light grey for alternate rows
  bg(part = "header", bg = "navyblue") %>%                 # Dark color for header background
  color(part = "header", color = "white")


# Lastly should save this to output
table
#save_as_image(table, "some_path.png")
