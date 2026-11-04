# =======================================================================================
# MESSI parameter definition: MODEL SELECTION / FEATURE SELECTION only.
# Repository: https://github.com/CompBio-Lab/MESSI-pipeline
# This is descriptive metadata, not an executable tuning configuration.
# Values reflect the default config and the arguments passed by select_feature/main.nf.
# Overrides and library versions can change effective settings.
# Dependencies: install.packages(c("tibble", "dplyr"))
# =======================================================================================
library(tibble)
library(dplyr)

# Treatment vocabulary:
# Tuned: multiple candidate values explicitly supplied to a search.
# Fixed: one value supplied, including singleton search distributions.
# Variant: separately run configurations; no best-variant selection is implied.
# Derived: computed from data or another parameter.
# Library-managed: exact search behavior/grid not explicitly set in this repo.

logistic_regression <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Classifier", "C", "Tuned", "Log-uniform: 1e-4 to 1e4", "Inverse regularization strength",
  "Classifier", "penalty", "Fixed", "l2", "Penalty type",
  "Classifier", "solver", "Fixed", "liblinear", "Optimization algorithm"
)

random_forest <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Classifier", "n_estimators", "Fixed", "10", "Number of trees",
  "Classifier", "max_depth", "Fixed", "10", "Maximum tree depth",
  "Classifier", "max_features", "Tuned", "sqrt; log2; 100; 500; 1000; None", "Features considered per split",
  "Classifier", "max_leaf_nodes", "Tuned", "10; 100; 1000; None", "Maximum leaves per tree",
  "Classifier", "min_samples_leaf", "Tuned", "Integer: 1 to 5 inclusive", "Minimum observations per leaf"
)

gradient_boosting <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Classifier", "loss", "Fixed", "log_loss", "Training loss",
  "Classifier", "n_estimators", "Tuned", "Integer: 50 to 500 inclusive", "Number of boosting stages",
  "Classifier", "learning_rate", "Tuned", "Uniform: [0.01, 1.11)", "Contribution of each boosting stage",
  "Classifier", "min_samples_leaf", "Tuned", "Integer: 1 to 5 inclusive", "Minimum observations per leaf",
  "Classifier", "max_features", "Tuned", "sqrt; log2; 100; 500; 1000; None", "Features considered per split"
)

mlp <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Classifier", "hidden_layer_sizes", "Tuned", "(32,); (64,); (128,); (64, 32)", "Hidden network architecture",
  "Classifier", "alpha", "Tuned", "Log-uniform: 1e-5 to 1e-1", "L2 regularization coefficient",
  "Classifier", "max_iter", "Fixed", "500", "Maximum training iterations"
)


diablo <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Global", "scheme", "Fixed", "horst", "Objective function g to maximize",
  "Global", "ncomp", "Fixed", "params.num_comps; default 2", "Number of latent components",
  "Feature selection", "n_percent", "Fixed", "100 (script default; not passed by Nextflow)", "Percentage of features retained per block",
  "Modality x component", "keepX", "Derived", "round(n_percent * ncol(X_block) / 100), repeated for each component", "Number of retained features",
  "Cross-block design", "design", "Variant", "full; null", "Separate block connection configurations"
)

rgcca <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Global", "scheme", "Fixed", "horst", "Objective function g to maximize",
  "Global", "ncomp", "Fixed", "params.num_comps; default 2", "Number of latent components supplied to rgcca_cv",
  "Integration", "method", "Fixed", "rgcca", "Integration algorithm",
  "Cross-block design", "connection", "Variant", "full: 1 - diag(J); null: diag(J)", "Connection matrix, including the response block",
  "Modality", "tau", "Library-managed", "tau = 1 supplied; par_type and candidate grid omitted", "Block regularization; verify effective search in installed RGCCA",
  "Modality", "sparsity", "Fixed", "1 supplied with method = rgcca", "Supplied sparsity setting; not an explicit SGCCA search",
  "Prediction", "prediction_model", "Fixed", "lda", "Classifier used by rgcca_cv",
  "Validation", "validation / k / n_run", "Fixed", "kfold / 5 / 1", "Cross-validation configuration",
  "Validation", "metric", "Fixed", "Balanced_Accuracy", "Evaluation criterion"
)

mofa <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Factor model", "num_factors", "Fixed", "params.num_comps; default 2", "Number of latent factors requested",
  "Preprocessing", "scale_views", "Fixed", "FALSE", "Whether to scale views before factor learning",
  "Feature extraction", "factor_levels", "Fixed", "Factor1; Factor2 (hard-coded)", "Factors whose feature weights are exported",
  "Factor model", "other model / training options", "Library-managed", "get_default_model_options / get_default_training_options", "MOFA2 defaults inherited by the wrapper"
)

cooperative_learning <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Integration", "rho", "Fixed", "0.5", "Weight of the agreement penalty",
  "Classifier", "useLasso / alpha", "Fixed", "FALSE / 0 (ridge)", "Penalty type",
  "Classifier", "lambda", "Tuned", "Library-generated regularization path; choose lambda.min", "Regularization strength",
  "Classifier", "family", "Fixed", "binomial", "Response distribution",
  "Validation", "nfolds", "Fixed", "5", "Number of CV folds",
  "Validation", "type.measure", "Fixed", "deviance", "CV selection criterion"
)

caret_multimodal <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Per-modality classifier", "method", "Fixed", "glmnet", "Base learner",
  "Per-modality classifier", "alpha", "Fixed", "0 (ridge)", "Penalty type",
  "Per-modality classifier", "lambda", "Tuned", "10^seq(-4, 3, length = 20)", "Base learner regularization strength",
  "Stacking classifier", "method", "Fixed", "glmnet", "Meta learner",
  "Stacking classifier", "alpha", "Fixed", "0 (ridge)", "Penalty type",
  "Stacking classifier", "lambda", "Tuned", "10^seq(-4, 3, length = 20)", "Meta learner regularization strength",
  "Validation", "method / number", "Fixed", "cv / 5", "CV configuration for both learning stages",
  "Validation", "summaryFunction", "Fixed", "caret::twoClassSummary", "Computes ROC, sensitivity and specificity; metric not explicitly passed"
)

mogonet <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "GCN", "he_base_dim", "Fixed", "params.he_base_dim; default 100", "Hidden embedding dimension per view",
  "Graph construction", "adj_parameter", "Fixed", "5", "Adjacency construction parameter",
  "Optimization", "lr_e_pretrain", "Fixed", "1e-3", "Encoder pretraining learning rate",
  "Optimization", "lr_e", "Fixed", "5e-4", "Encoder training learning rate",
  "Optimization", "lr_c", "Fixed", "1e-3", "Classifier learning rate",
  "Optimization", "num_epoch_pretrain", "Fixed", "50", "Pretraining loop iterations",
  "Optimization", "num_epoch", "Fixed", "200 (training loop uses range(num_epoch + 1))", "Training epoch argument",
  "Feature importance split", "test_size", "Fixed", "0.25", "Holdout proportion used by the feature-importance wrapper"
)

integrao <- tribble(
  ~component, ~parameter, ~treatment, ~search_space, ~function_,
  "Graph construction", "neighbor_size", "Fixed", "20", "Number of nearest neighbors",
  "Embedding", "embedding_dims", "Fixed", "64", "Embedding dimensionality",
  "Network fusion", "fusing_iteration", "Fixed", "30", "Fusion diffusion iterations",
  "Network fusion", "normalization_factor", "Fixed", "1.0", "Normalization factor",
  "Optimization", "alignment_epochs", "Fixed", "300 (CLI default passed by the entry point)", "Unsupervised alignment training duration",
  "Optimization", "finetune_epochs", "Fixed", "800", "Supervised fine-tuning duration",
  "Objective", "beta", "Fixed", "1.0", "Beta loss weight",
  "Objective", "mu", "Fixed", "0.5", "Mu loss weight",
  "Feature importance", "n_times", "Fixed", "5", "Repetitions with different seeds; not hyperparameter search"
)


# Add a new method by defining a tribble above and adding one named entry here.
method_tables <- list(
  "Logistic Regression" = logistic_regression,
  "Random Forest" = random_forest,
  "Gradient Boosting" = gradient_boosting,
  "MLP" = mlp,
  "DIABLO" = diablo,
  "RGCCA" = rgcca,
  "MOFA" = mofa,
  "Cooperative Learning" = cooperative_learning,
  "caretMultimodal" = caret_multimodal,
  "MOGONET" = mogonet,
  "IntegrAO" = integrao
)

parameter_table <- bind_rows(method_tables, .id = "method")

# The six-column presentation table keeps the schema from the question.
display_table <- parameter_table
names(display_table) <- c("Method", "Component", "Parameter", "Treatment",
                         "Search space / value", "Function")

# Optional export / rendering (uncomment what you need):
output_file <- "messi_parameter_catalog.csv"
write.csv(display_table, output_file, row.names = FALSE)
message("MESSI methods parameter table written to ", output_file)

writeLines(
  c(
    "# MESSI hyperparameter catalog",
    "",
    knitr::kable(display_table, format = "pipe", row.names = FALSE),
    ""
  ),
  "hyperparameter_table.md"
)


#knitr::kable(display_table, row.names = FALSE)
# gt::gt(display_table, groupname_col = "Method")

