library(dplyr)
library(stringr)

method_mapping <-   mapping <- c(
  diablo   = "DIABLO",
  rgcca    = "RGCCA",
  mogonet  = "MOGONET",
  integrao = "IntegrAO",
  mofa     = "MOFA",
  cooperative_learning = "multiview",
  caret_multimodal = "caretMultimodal"
)

standardize_method_names <- function(method) {

  mapping <- c(
    diablo   = "DIABLO",
    rgcca    = "RGCCA",
    mogonet  = "MOGONET",
    integrao = "IntegrAO",
    mofa     = "MOFA",
    cooperative_learning = "multiview",
    caret_multimodal = "caret_Multimodal"
  )

  method_chr <- as.character(method)
  na_mask <- is.na(method_chr)

  replaced <- purrr::reduce2(
    names(mapping),
    mapping,
    function(current, key, replacement) {
      stringr::str_replace_all(
        current,
        stringr::fixed(key, ignore_case = TRUE),
        replacement
      )
    },
    .init = method_chr
  )

  # Step 2: Replace suffixes (-null -> _null, etc.)
  suffix_replacements <- c(
    "_null"   = "-null",
    "_full"   = "-full",
    "_Factor" = "-Factor",
    "_ncomp"  = "-ncomp"
  )
  replaced <- str_replace_all(replaced, suffix_replacements)

  # Step 3: Conditionally append + lda or + glmnet
  out <- replaced %>%
    sapply(function(x) {
      if (str_detect(x, "GCCA") & !str_detect(x, "\\+ lda")) {
        x <- paste(x, "+ lda")
      }
      if (str_detect(x, "MOFA") & !str_detect(x, "\\+ glmnet")) {
        x <- paste(x, "+ glmnet")
      }
      x
    }, USE.NAMES = FALSE)

  out[na_mask] <- NA_character_
  out
}

# standardize_method_names <- function(method) {
#   # Let this mapping to stay
#   mapping <- c(
#     diablo  = "DIABLO",
#     rgcca   = "RGCCA",
#     mogonet = "MOGONET",
#     mofa    = "MOFA"
#   )
#   # Handle the chr version in case method is factor already
#   method_chr <- as.character(method)
#   na_mask <- is.na(method_chr)
#
#   out <- purrr::reduce2(
#     .x = names(mapping),
#     .y = mapping,
#     .f = function(current, key, replacement) {
#       str_replace_all(current, fixed(key, ignore_case = TRUE), replacement)
#     },
#     .init = method_chr
#   )
#
#   out[na_mask] <- NA_character_
#   out
# }
#
#
# standardize_method_names2 <- function(df) {
#   df %>%
#     mutate(
#       method = case_when(
#         str_detect(method, "cooperative_learning") ~ "multiview",
#         str_detect(method, "mofa") ~ paste(method, "glmnet", sep = " + " ),
#         str_detect(method, "gcca") ~ paste(method, "lda", sep = " + "),
#         TRUE ~ method
#       )
#     )
# }
standardize_view_names <- function(df) {
  df %>%
    dplyr::mutate(
      method = case_when(
        str_detect(view, "ncomp") ~ paste(method, str_extract(view, "ncomp-\\d+"), sep = "-"),
        str_detect(view, "Factor") ~ paste(method, str_extract(view, "Factor\\d+"), sep = "-"),
        TRUE ~ method
      ),
      view_cleaned = case_when(
        str_detect(view, "ncomp") ~ str_remove(view, "-ncomp.*"),
        str_detect(view, "Factor") ~ str_remove(view, "-Factor.*"),
        TRUE ~ view
      ),
      feat = str_remove(feature, paste0("^", view_cleaned, "_")),
      view = view_cleaned
    ) %>%
    dplyr::select(-view_cleaned)
}
