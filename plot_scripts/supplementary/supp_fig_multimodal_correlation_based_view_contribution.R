standardize_method_names <- function(df) {
  df %>%
    mutate(
      method = case_when(
        str_detect(method, "cooperative_learning") ~ "multiview",
        str_detect(method, "mofa") ~ paste(method, "glmnet", sep = " + " ),
        str_detect(method, "gcca") ~ paste(method, "lda", sep = " + "),
        TRUE ~ method
      )
    )
}
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


pred_df <- data.table::fread("data/raw/multimodal_data/all_langs-result.csv") |>
  filter(dataset == "clinical_omics")

coef_df <- data.table::fread("data/raw/multimodal_data/all_feature_selection_results.csv") |>
  filter(dataset_name == "clinical_omics") |>
  dplyr::select(-feature_type, -dataset_type) %>%
  standardize_view_names() %>%
  standardize_method_names()

pred_df$method_name |> unique()


#clinical_mae <- loadHDF5MultiAssayExperiment("clinical_omics_processed_mae_data/")


get_mae <- function(dataset_name) {
    output_mae <- loadHDF5MultiAssayExperiment(dataset_name)
    return(output_mae)
}

get_view_matrix <- function(mae, view_name, samples) {
  # Try to match view_name to an experiment in the MAE
  exp_names <- names(experiments(mae))
  matched   <- exp_names[grepl(view_name, exp_names, ignore.case = TRUE)][1]

  if (is.na(matched)) {
    warning(paste("View not found in MAE:", view_name))
    return(NULL)
  }

  mat <- assay(mae[[matched]])  # features x samples

  # Subset to requested samples (test set)
  common_samples <- intersect(samples, colnames(mat))
  if (length(common_samples) == 0) {
    warning(paste("No overlapping samples for view:", view_name))
    return(NULL)
  }

  t(mat[, common_samples, drop = FALSE])  # return samples x features
}


# Compute view scores and correlate with y
# Iterates over unique method + dataset + fold + view combinations
compute_view_correlations <- function(preds, coefs) {

  results <- list()

  # Get unique method + dataset combinations
  method_dataset_combos <- unique(coefs[, .(method, dataset_name)])

  for (i in seq_len(nrow(method_dataset_combos))) {

    method_i  <- method_dataset_combos$method[i]
    dataset_i <- method_dataset_combos$dataset_name[i]

    cat(sprintf("Processing: %s | %s\n", method_i, dataset_i))

    # Get coefficients for this method + dataset
    coef_sub <- coefs[method == method_i & dataset_name == dataset_i]
    views     <- unique(coef_sub$view)

    # Get predictions for this method + dataset (to identify fold/test samples)
    # Note: method column name may differ between dfs — adjust if needed
    pred_sub <- preds[method_name == method_i & dataset == dataset_i]
    folds    <- unique(pred_sub$fold)

    # Load MAE for this dataset
    mae <- tryCatch(get_mae(dataset_i), error = function(e) {
      warning(paste("Could not load MAE for:", dataset_i, "-", e$message))
      return(NULL)
    })
    if (is.null(mae)) next

    for (fold_j in folds) {

      # Test samples for this fold
      test_samples <- pred_sub[fold == fold_j, sample_name]
      y_test       <- pred_sub[fold == fold_j, .(sample_name, y)]

      for (view_k in views) {

        # Get coefficients for this view
        coef_view <- coef_sub[view == view_k]
        # Need to add view name in front to the coef_view
        coef_view$feat <- stringr::str_c(view_k, "_", coef_view$feat)

        # Get feature matrix for this view from MAE
        X <- get_view_matrix(mae, view_k, test_samples)
        #print(X)
        if (is.null(X)) next

        # Align features: only keep features present in both coef and matrix
        common_feats <- intersect(coef_view$feat, colnames(X))
        if (length(common_feats) == 0) {
          warning(paste("No common features for view:", view_k))
          next
        }

        X_sub    <- X[, common_feats, drop = FALSE]
        coef_vec <- coef_view[feat %in% common_feats][match(common_feats, feat), coef]

        # Compute view score: linear combination of features weighted by coef
        # samples x features %*% features x 1 = samples x 1
        view_scores <- as.numeric(X_sub %*% coef_vec)

        # Align with y
        score_dt <- data.table(
          sample_name = rownames(X_sub),
          view_score  = view_scores
        )
        score_dt <- merge(score_dt, y_test, by = "sample_name")
        # Correlations
        pearson_r  <- cor(score_dt$view_score, score_dt$y, method = "pearson")
        spearman_r <- cor(score_dt$view_score, score_dt$y, method = "spearman")

        results[[length(results) + 1]] <- data.table(
          method       = method_i,
          dataset_name = dataset_i,
          fold         = fold_j,
          view         = view_k,
          n_samples    = nrow(score_dt),
          n_features   = length(common_feats),
          pearson_r    = pearson_r,
          spearman_r   = spearman_r
        )
      }
    }
  }

  rbindlist(results)
}

option_b_raw <- compute_view_correlations(pred_df, coef_df)

option_b_raw

# Summarize across folds: mean ± sd per method + dataset + view
option_b <- option_b_raw[, .(
  pearson_mean  = mean(pearson_r,  na.rm = TRUE),
  pearson_sd    = sd(pearson_r,    na.rm = TRUE),
  spearman_mean = mean(spearman_r, na.rm = TRUE),
  spearman_sd   = sd(spearman_r,   na.rm = TRUE),
  n_folds       = .N
), by = .(method, dataset_name, view)]


# Option B: dot plot of mean Spearman r per view, colored by dataset
p_b <- ggplot(option_b, aes(x = view, y = spearman_mean, color = dataset_name)) +
  geom_point(size = 3, position = position_dodge(width = 0.4)) +
  geom_errorbar(aes(ymin = spearman_mean - spearman_sd,
                    ymax = spearman_mean + spearman_sd),
                width = 0.2, position = position_dodge(width = 0.4)) +
  facet_wrap(~ method, scales = "free_y") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
  labs(title = "Option B: View Score Correlation with Outcome (Spearman)",
       x = "View", y = "Mean Spearman r (± SD across folds)",
       color = "Dataset") +
  theme_cowplot(12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

p_b
