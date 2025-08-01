library(dplyr)
library(stringr)

standardize_method_names <- function(method) {
  # Let this mapping to stay
  mapping <- c(
    diablo  = "DIABLO",
    rgcca   = "RGCCA",
    mogonet = "MOGONET",
    mofa    = "MOFA"
  )
  # Handle the chr version in case method is factor already
  method_chr <- as.character(method)
  na_mask <- is.na(method_chr)

  out <- purrr::reduce2(
    .x = names(mapping),
    .y = mapping,
    .f = function(current, key, replacement) {
      str_replace_all(current, fixed(key, ignore_case = TRUE), replacement)
    },
    .init = method_chr
  )

  out[na_mask] <- NA_character_
  out
}
