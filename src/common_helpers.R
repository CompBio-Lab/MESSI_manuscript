# ==============================================================================
# Common helpers used in all figures wrangling data
# ==============================================================================
library(stringr)

# Function to extract simulation parameters from dataset name
# retrieve_sim_params <- function(df) {
#   df %>%
#     tidyr::separate(
#       dataset,
#       into = c("type", "strategy", "n", "p", "j", "dt", "rho", "rep"),
#       sep = "_") %>%
#     dplyr::mutate(
#       dplyr::across(n:rep, ~ stringr::str_extract(., "[0-9.]+") %>% as.numeric())
#     ) %>%
#     dplyr::rename(signal = dt, corr = rho) %>%
#     #mutate(rep = stringr::str_sort(rep, numeric=TRUE)) %>%
#     # Then also sort rep by alpha numeric
#     dplyr::select(-type)
# }


retrieve_sim_params <- function(df) {
  df %>%
    # First handle the strategy, then handle params separately based on strategy
    dplyr::mutate(
      # Extract the strategy part
      strategy = str_extract(dataset, "strategy-[^_]+") %>%
        str_remove("strategy-"),
      # Extract the rest of the parameters
      params = str_extract(dataset, "strategy-[^_]+_(.*)$") %>%
        str_remove("^strategy-[^_]+_")
    )  %>%
    dplyr::mutate(
      n = str_extract(params, "n-\\d+"),
      p = str_extract(params, "p-\\d+"),
      dt = str_extract(params, "dt-\\d+"),
      rho = str_extract(params, "rho-[\\d\\.]+"),
      rep = str_extract(params, "rep-\\d+")
    ) %>%
    dplyr::mutate(across(n:rep, ~ str_remove(., "^[a-z]+-") %>% as.numeric())) %>%
    dplyr::rename(signal = dt, corr = rho) %>%
    dplyr::select(-c(params))
}
