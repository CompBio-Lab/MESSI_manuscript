library(stringr)
library(dplyr)
# This function is to extract parameters of the simulated data
retrieve_sim_params <- function(df) {
  df %>%
    # First handle the strategy, then handle params separately based on strategy
    mutate(
      # Extract the strategy part
      strategy = str_extract(dataset, "strategy-[^_]+") %>%
        str_remove("strategy-"),
      # Extract the rest of the parameters
      params = str_extract(dataset, "strategy-[^_]+_(.*)$") %>%
        str_remove("^strategy-[^_]+_")
    )  %>%
    mutate(
      n = str_extract(params, "n-\\d+"),
      p = str_extract(params, "p-\\d+"),
      dt = str_extract(params, "dt-\\d+"),
      rho = str_extract(params, "rho-[\\d\\.]+"),
      rep = str_extract(params, "rep-\\d+")
    ) %>%
    mutate(across(n:rep, ~ str_remove(., "^[a-z]+-") %>% as.numeric())) %>%
    rename(signal = dt, corr = rho) %>%
    select(-c(params))
}
