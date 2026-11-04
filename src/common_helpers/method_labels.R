# method_labels.R - ONE canonical method naming for every figure.
# Maps any raw/legacy method name (prediction files: sklearn-Logit-empty, diablo-null_ncomp-2;
# feature files: sklearn-logit, diablo-null; older display labels: Multiview, MOFA+glmnet,
# RGCCA-F+LDA, DIABLO-N (nc2)) onto the concise manuscript label + integration class.
suppressPackageStartupMessages({library(dplyr); library(stringr)})

METHOD_LABELS <- tibble::tribble(
  ~key,                     ~label,                 ~class,          ~order,
  "sklearn-logit",          "Logistic",             "Early",          1,
  "sklearn-xgboost",        "XGBoost",              "Early",          2,
  "sklearn-random_forest",  "Random Forest",        "Early",          3,
  "sklearn-mlp",            "MLP",                  "Early",          4,
  "diablo-full",            "DIABLO-F",             "Intermediate",   5,
  "diablo-null",            "DIABLO-N",             "Intermediate",   6,
  "rgcca-full",             "RGCCA-F",              "Intermediate",   7,
  "rgcca-null",             "RGCCA-N",              "Intermediate",   8,
  "mofa",                   "MOFA+",                "Intermediate",   9,
  "integrao",               "IntegrAO",             "Intermediate",  10,
  "cooperative_learning",   "Multiview", "Intermediate",  11,
  "caret_multimodal",       "caretMultimodal",      "Late",          12,
  "mogonet",                "MOGONET",              "Late",          13
)

# Legacy display labels used by older scripts -> canonical key
.LEGACY <- c("logistic" = "sklearn-logit", "xgboost" = "sklearn-xgboost",
             "random forest" = "sklearn-random_forest", "mlp" = "sklearn-mlp",
             "multiview" = "cooperative_learning", "cooperative" = "cooperative_learning",
             "cooperative learning" = "cooperative_learning",
             "mofa+glmnet" = "mofa", "mofa+" = "mofa", "caretmultimodal" = "caret_multimodal",
             "rgcca-f+lda" = "rgcca-full", "rgcca-n+lda" = "rgcca-null",
             "rgcca-f" = "rgcca-full", "rgcca-n" = "rgcca-null",
             "diablo-f" = "diablo-full", "diablo-n" = "diablo-null")

method_key <- function(x) {
  k <- tolower(trimws(as.character(x)))
  k <- str_replace(k, "\\s*\\(nc\\d\\)$", "")           # "DIABLO-N (nc2)"
  k <- str_replace(k, "[_-]ncomp-?\\d+$", "")           # diablo-null_ncomp-2
  k <- str_replace(k, "-empty$", "")                     # sklearn-*-empty
  ifelse(k %in% names(.LEGACY), unname(.LEGACY[k]), k)
}

# Concise label; unknown names (e.g. PCA50 variants) are returned unchanged unless pca50 suffix.
method_label <- function(x) {
  raw <- as.character(x); k <- method_key(raw)
  pca <- str_detect(k, "-pca50$"); k2 <- str_remove(k, "-pca50$")
  i <- match(k2, METHOD_LABELS$key)
  out <- ifelse(is.na(i), raw, METHOD_LABELS$label[i])
  ifelse(pca & !is.na(i), paste0(out, " (PCA50)"), out)
}
method_class <- function(x) METHOD_LABELS$class[match(str_remove(method_key(x), "-pca50$"), METHOD_LABELS$key)]
method_order <- function(x) METHOD_LABELS$order[match(str_remove(method_key(x), "-pca50$"), METHOD_LABELS$key)]
