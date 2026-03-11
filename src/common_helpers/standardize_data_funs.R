library(dplyr)
library(stringr)

# method_mapping <-   mapping <- c(
#   diablo   = "DIABLO",
#   rgcca    = "RGCCA",
#   mogonet  = "MOGONET",
#   integrao = "IntegrAO",
#   mofa     = "MOFA",
#   cooperative_learning = "multiview",
#   caret_multimodal = "caretMultimodal"
# )

# ====================
# method_names <- combined_df$method |> unique()
# method_names
# method_names |>
#   standardize_method_names(mode="perf")


standardize_method_names <- function(method, mode="feature") {

  mapping <- c(
    diablo   = "DIABLO",
    rgcca    = "RGCCA",
    mogonet  = "MOGONET",
    integrao = "IntegrAO",
    mofa     = "MOFA",
    cooperative_learning = "Multiview",
    multiview = "Multiview",
    caret_multimodal = "caretMultimodal"
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

  # # Otherwise loop through this and go adding variants and shortening
  #
  # Step 2: Replace suffixes (-null -> _null, etc.)
  suffix_replacements <- c(
    "_null"   = "-null",
    "_full"   = "-full",
    "_Factor" = "-Factor",
    "_ncomp"  = "-ncomp"
  )
  replaced <- str_replace_all(replaced, suffix_replacements)
  # # Step 3: Replace the extra full ncomp, factor to shorthands
  # # Step 3: Collapse null/full + ncomp and MOFA Factor into shorthands
  shorthanded <- sapply(replaced, function(x) {
    m <- str_match(x, "^(.*?)-(full|null|Factor)(?:-ncomp|-_ncomp)?[-_]?(\\d+)(.*)$")
    if (is.na(m[1,1])) return(x)
    type_letter <- ifelse(m[1,3] == "full", "F",
                          ifelse(m[1,3] == "null", "N", ""))
    paste0(m[1,2], "-", type_letter, m[1,4], m[1,5])
  })

  #
  # Step 4: Conditionally append + lda or + glmnet
  out <- shorthanded %>%
    sapply(function(x) {
      if (str_detect(x, "GCCA") & !str_detect(x, "\\+ lda")) {
        x <- paste0(x, "+LDA")
      }
      if (str_detect(x, "MOFA") & !str_detect(x, "\\+ glmnet")) {
        x <- paste0(x, "+glmnet")
      }
      if (str_detect(x, "lda")) {
        x <- str_replace(x, "lda", "LDA")
      }
      # Lastly remove all white spaces
      return(stringr::str_replace_all(x, " ", ""))
    }, USE.NAMES = FALSE) |> as.character()
  if (mode == "feature") {
    return(out)
  }
  out |>
    stringr::str_replace_all("-(F|N)\\d+", "-\\1") |>  # drop numbers
    stringr::str_replace_all("-FA.*$", "")             # drop FA entirely
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
