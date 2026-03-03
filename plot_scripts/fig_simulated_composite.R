# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(tibble)
library(here)
library(stringr)
library(tidyr)
library(ggplot2)

# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/retrieve_sim_params.R"))
source(here::here("plot_scripts/performance_evaluation_utils.R"))
source("src/common_helpers/standardize_data_funs.R")
source("src/common_helpers/save_plot_both.R")



wrangle_sim_data <- function(df) {
    wrangle_df <- df %>%
      dplyr::rename(method = method_name) %>%
      ungroup() %>%
      dplyr::select(
        method, dataset,
        auc, f1_score
      )

    return(wrangle_df)
}


wrangle_sim_feat_selection <- function(df) {
  df %>%
    dtplyr::lazy_dt() %>%  # Translates dplyr to fast data.table
    dplyr::rename(dataset = dataset_name) %>%

    # Fix mogonet feature naming
    mutate(feature = case_when(
      str_detect(method, "mogonet") ~ paste(view, feature, sep = "_"),
      TRUE ~ feature
    )) %>%
    # Append view-related info to method
    mutate(method = case_when(
      str_detect(view, "Factor") ~ paste0(method, "-", str_extract(view, "Factor.*")),
      str_detect(view, "ncomp")  ~ paste0(method, "_", str_extract(view, "ncomp.*")),
      TRUE ~ method
    )) %>%
    # Final renaming of method
    mutate(method = case_when(
      str_detect(method, "gcca")        ~ paste0(method, " + lda"),
      str_detect(method, "mofa")        ~ paste0(method, " + glmnet"),
      str_detect(method, "cooperative") ~ "multiview",
      TRUE ~ method
    )) %>%
    as_tibble()  # Materialize result (computed now)
}


# ==================================================
# First load data and clean it for plotting

input_path <- "data/raw/simulated_data/metrics.csv"

# First wrangle data
sim_perf_df <- data.table::fread(input_path) %>%
  wrangle_sim_data() %>%
  # TODO: Uggly fix here
  mutate(
    method = case_when(
      str_detect(tolower(method), "mofa") ~ "mofa-Factor1",
      TRUE ~ method
    )
  ) %>%
  retrieve_sim_params() %>%
  # Then only retain relevant cols
  dplyr::select(method, dataset,
                auc, f1_score,
                signal, corr, n, p)


plot_data_perf <- sim_perf_df %>%
  filter(signal %in% c(0,3,100)) %>%
  dplyr::select(method, dataset, auc, signal,corr) %>%
  # Capitalize or to upper the method names
  # HERE purposedly use "feature" to not remove the ncomps/factor
  mutate(method = standardize_method_names(method, "feature"))


# =============================================================================
clean_feat_sim <- function(feat_result_df) {
  all_counts_df <- feat_result_df %>%
    dplyr::count(method, dataset, view, feature_type, name = "n") %>%
    pivot_wider(names_from = feature_type, values_from = n, values_fill = 0) %>%
    dplyr::rename(n_real = real, n_noise = noise)

  # Step 2: Join this to feat_result_df
  feat_with_counts <- feat_result_df %>%
    left_join(all_counts_df, by = c("method", "dataset", "view")) %>%
    arrange(method, dataset, view, desc(abs(coef))) %>%
    group_by(method, dataset, view) %>%
    mutate(rank = row_number()) %>%
    mutate(category = case_when(
      rank <= dplyr::first(n_real) ~ "top_counts",
      rank > n() - dplyr::first(n_noise) ~ "bottom_counts",
      TRUE ~ NA_character_
    )) %>%
    ungroup() %>%
    filter(!is.na(category)) %>%
    dplyr::count(method, dataset, view, feature_type, category, name = "n_selected")

  # Step 3: Compute confusion matrix components
  flat_bin_metric_df <- feat_with_counts %>%
    pivot_wider(
      names_from = c(category, feature_type),
      values_from = n_selected,
      values_fill = 0
    ) %>%
    transmute(
      method, dataset, view,
      TP = top_counts_real,
      FP = top_counts_noise,
      FN = bottom_counts_real,
      TN = bottom_counts_noise,
      N = TP + FP + FN + TN
    )

  # Step 4: Calculate metrics and return it
  flat_bin_metric_df %>%
    group_by(method, dataset, view) %>%
    summarize(
      sensitivity = TP / (TP + FN),
      specificity = TN / (TN + FP),
      precision = TP / (TP + FP),
      accuracy = (TP + TN) / N
    ) %>%
    retrieve_sim_params()
}


feat_input_path <- "data/raw/simulated_data/all_feature_selection_results.csv"
feat_result_df <- data.table::fread(feat_input_path) %>%
    wrangle_sim_feat_selection() %>%
    # And additionally remove those extra info in view
    # Need additional standardizing of views
    mutate(view = case_when(
      str_detect(view, "-Factor") ~ str_remove(view, "-Factor.*"),
      str_detect(view, "-ncomp") ~ str_remove(view, "-ncomp.*"),
      TRUE ~ view
    ))



# Apply some wrangling / summarizing
plot_data_feat <- feat_result_df %>%
  clean_feat_sim()  %>%
  ungroup() %>%
  # Keep the relevant levels only
  filter(signal %in% c(0, 3, 100)) %>%
  group_by(method, dataset, signal, corr) %>%
  summarize(sensitivity = mean(sensitivity),
            specificity = mean(specificity),
            .groups = "drop") %>%
  dplyr::select(method:specificity, signal, corr) %>%
  # Capitalize or to upper the method names
  mutate(method = standardize_method_names(method))


# ==============================================================================
# Then join both and transform data for plotting
plot_data_df <- inner_join(
  plot_data_feat, plot_data_perf, by = c("method", "dataset", "signal", "corr")
) %>%
  tidyr::pivot_longer(sensitivity:auc, names_to = "metric")

# ==============================================================================
# Plotting stuff

# Use this function to create the individual panel
create_panel_plot <- function(data, metric_filter, metric_label, y_label_expr, text_size) {
  data |>
    filter(metric == metric_filter) |>
    mutate(metric = metric_label) |>
    ggplot(aes(x = method, y = value, fill = corr)) +
    # Original padding 0.4
    geom_bar(stat = "identity", position = position_dodge2(padding = 0.6), alpha=0.7) +
    ylab(y_label_expr) +
    theme_bw(base_size = text_size) +
    facet_grid(metric ~ signal) +
    # Calls on another theme in plot_utils
    custom_theme_for_sim_plot(text_size) +
    #scale_x_discrete(labels = function(x) stringr::str_wrap(x, width = 12)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.07))) +
    scale_fill_manual(
      values = c("0" = "#C6DBEF", "0.5" = "#6BAED6", "1" = "#2171B5"),
      labels = c("0" = "Low", "0.5" = "Medium", "1" = "High")
    ) +
    labs(fill="Correlation") +
    guides(
      fill = guide_legend(
        title.position = "left",
        label.position = "bottom",
        direction = "horizontal"
      )
    ) +
    # This is remove extra space after final arrangement
    theme(plot.margin = margin(6, 0, 0, 6))
}



# Additional theme to empty legend and ticks
theme_empty_legend_ticks <- function() {
  theme(
    legend.position="none",
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.title.x = element_blank(),
  )
}

# Additional theme to remove the ribbon text from grid.x
theme_empty_ribbon <- function() {
  theme(
    strip.background.x = element_blank(),
    strip.text.x = element_blank()
  )
}

# Correct order should be: mofa-F1, mogonet- multiview?
method_order <- plot_data_df |>
  filter(signal == "3", metric == "sensitivity") |>
  group_by(method) |>
  summarize(mean_value = mean(value, na.rm = TRUE)) |>
  arrange(mean_value) |>
  dplyr::pull(method)


final_plot_data <- plot_data_df |>
  dplyr::mutate(
    metric = as.factor(metric),
    signal = factor(signal, labels = c("Signal: None", "Signal: Low ", "Signal: High")),
    corr = as.factor(corr),
    method = factor(method, levels=method_order)
  )

text_size <- 9.5

# First create the independent panels
auc_panel <- create_panel_plot(
  data = final_plot_data,
  metric_filter = "auc",
  metric_label = "AUC",
  y_label_expr = "Mean AUC of 5-fold CV",
  text_size = text_size + 4
) +
  coord_flip()



sensitivity_panel <- create_panel_plot(
  data = final_plot_data,
  metric_filter = "sensitivity",
  metric_label = "True Variables",
  #y_label_expr = expression("Proportion of TP^* / TP^* + FN^*")
  #y_label_expr = expression("Proportion of " * TP^"*" / (TP^"*" + FN^"*"))
  y_label_expr = "Proportion of variables selected",
  text_size = text_size + 3
) +
  coord_flip()



specificity_panel <- create_panel_plot(
  data = final_plot_data,
  metric_filter = "specificity",
  metric_label = "Noise Variables",
  #y_label_expr = "Proportion of TN^* / TN^* + FP^*"
  #y_label_expr = expression("Proportion of " * TN^"*" / (TN^"*" + FP^"*"))
  y_label_expr = "Proportion of variables selected",
  text_size = text_size + 3
) +
  coord_flip()



# ==========================================================
# Merging the panels together
# First make the bottom row with patchwork
# Using cowplot is extremely due to alignment problems
library(patchwork)
bottom_row <- (sensitivity_panel + theme_empty_legend_ticks() + xlab(NULL)) /
  (specificity_panel +
     xlab(NULL))+
  plot_layout(axes = "collect")


# Load library
suppressPackageStartupMessages(library(dplyr))
# Load custom scripts
source("plot_scripts/computational_resources_utils.R")
source("src/common_helpers/save_plot_both.R")
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/retrieve_sim_params.R"))
# Custom theme to use
resource_panel_theme <- function(text_size) {
  # Remove the vertical lines in x-axis
  theme(
    legend.title = element_text(size = text_size + 2),  # Change title text size
    legend.text = element_text(size = text_size),    # Change label text size
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.background = element_rect(fill = "grey95", color = "grey70"),
    panel.spacing.y = unit(1, "lines"),     # Increase vertical spacing
    strip.text.x = element_text(size=text_size + 2, face = "bold"),
    strip.text.y = element_text(size=text_size)
    #strip.placement = "outside"             # Optional: keeps strip outside the panel
  )
}


# Load utils
trace_path <- "data/raw/simulated_data/execution_trace.txt"
# Read the trace in
trace_df <- readr::read_tsv(
  trace_path,
  col_types = readr::cols()
) |>
  # Get relevant cols
  dplyr::select(process,tag,realtime, peak_rss,peak_vmem, duration) |>
  mutate(process = chop_nf_core_prefix(process)) %>%
  # This takes long names from process to further apart as workflow and process
  separate_workflow_process(process) %>%
  # Further normalize the process after splitting names in it
  mutate(process = case_when(
    # If the workflow is from cv do something special
    workflow == "CROSS_VALIDATION" ~ str_extract(process, "[^:]+$"),
    # Add missing "label" for metrics
    workflow == "CALCULATE_METRICS" ~ "CALCULATE_METRICS",
    # Rest remain same
    TRUE ~ process
  )) %>%
  # Important step convert the strings to numeric values for metric cols
  mutate(
    realtime_sec = convert_to_seconds(realtime),
    duration_sec = convert_to_seconds(duration),
    peak_rss_mb = convert_to_mb(peak_rss),
    peak_vmem_mb = convert_to_mb(peak_vmem)
  ) %>%
  # And remove those redundant ones
  dplyr::select(-c("realtime", "peak_rss", "duration", "peak_vmem"))


# Also load dataset stuff
metadata_path <- "data/raw/simulated_data/parsed_metadata.csv"
metadata_df <- data.table::fread(metadata_path) |>
  dplyr::select(dataset_name, feat_dimensions, subject_dimensions) |>
  dplyr::mutate(
    dataset_name = str_remove(dataset_name, "_processed"),
    n_subjects = as.integer(sub(",.*", "", subject_dimensions)),  # take first value
    n_features = sapply(strsplit(feat_dimensions, ","),
                        function(x) sum(as.integer(x)))
  ) %>%
  dplyr::select(dataset_name, n_subjects, n_features)  %>%
  mutate(dataset_size = n_subjects * n_features)

known_dname <- metadata_df$dataset_name


plot_df  <- trace_df %>%
  filter(workflow %in%  c("CROSS_VALIDATION", "FEATURE_SELECTION")) %>%
  filter(!str_detect(process, "MERGE")) %>%
  # Change the label of multiview
  mutate(process = case_when(
    str_detect(process, "COOPERATIVE") ~ str_replace(
      process, "COOPERATIVE_LEARNING", "MULTIVIEW"
    ),
    TRUE ~ process
  )) %>%
  # Create a plot identifier for each workflow
  mutate(method = str_replace(process, "_.*", ""),
         action = str_replace(process, ".*_", "")) %>%
  filter(action != "DOWNSTREAM") %>%
  mutate(process = case_when(
    str_detect(tag, "null") ~ str_c(process, "NULL", sep="-"),
    str_detect(tag, "full") ~ str_c(process, "FULL", sep="-"),
    TRUE ~ process
  )) %>%
  dplyr::select(workflow, process, tag, method, action, realtime_sec, peak_rss_mb, peak_vmem_mb, duration_sec)  %>%
  # Change values for FEATURE
  mutate(
    action=str_replace(action, "FEATURE", "FEATURE_SELECT"),
    dataset_name=str_extract(tag, paste(known_dname, collapse = "|"))
  )


# Now combine both info
combined_df <- left_join(
  metadata_df, plot_df, by="dataset_name"
) %>%
  filter(action != "PREPROCESS") %>%
  mutate(
    action = case_when(
      action %in% c("TRAIN", "PREDICT") ~ "model_assessment",
      action == "FEATURE_SELECT" ~ "model_selection",
      TRUE ~ action
    )
  ) %>%
  dplyr::rename(dataset = dataset_name) %>%
  retrieve_sim_params() %>%
  group_by(method, dataset, n, p, signal, corr, action) %>%
  summarize(
    realtime_sec = sum(realtime_sec),
    peak_rss_mb = sum(peak_rss_mb),
    .groups = "drop"
  ) %>%
  filter(signal %in% c(0, 3, 100)) %>%
  group_by(method, action) %>%
  summarize(time = median(realtime_sec),
            space = median(peak_rss_mb),
            sd_time = sd(realtime_sec),
            sd_space = sd(peak_rss_mb),
            .groups = "drop") %>%
  pivot_longer(time:space, names_to="metric", values_to = "median_val") %>%
  filter(metric != "space") %>%
  mutate(metric = case_when(
  #  metric == "space" ~ "Peak RSS (MB)",
    metric == "time" ~ "Runtime in Seconds",
    TRUE ~ NA
  )) %>%
  mutate(metric = tools::toTitleCase(metric))

computation_usage_plot <- combined_df %>%
  ggplot(aes(reorder(method, median_val), y=median_val, fill=method)) +
  geom_bar(stat="identity") +
  labs(x="Method") +
  labs(y="Runtime (seconds)") +
  scale_y_log10(labels = scales::label_comma(),
                expand = expansion(mult = c(0, 0.07))) +
  scale_fill_manual(values=method_family_colors) +
  facet_wrap(
    scales="free_y",
    ~ action,
    labeller = labeller(
      action = as_labeller(
        c(
          model_assessment = "Model Assessment",
          model_selection  = "Model Selection"
        )),
      ncol=2
    )) +
  theme_bw() +
  theme(legend.position = "none",
        axis.text.x = element_text(angle=45, hjust=1))


# This is empty space ratio
panel_space <- 0.025
# Now stack top and bottom rows
top_plot <- cowplot::plot_grid(
  auc_panel +
    xlab(NULL) +
    theme(
      legend.position = "none",
      #axis.text.x = element_blank()
    ),
  #NULL, # spacer
  bottom_row,
  nrow = 2,
  rel_heights = c(0.9, 1.5),
  align="v",
  axis="lr",
  labels = c("A", "B"),
  label_size=text_size * 2.5
)

# Output plot
out_plot <- plot_grid(
  top_plot,
  computation_usage_plot + theme_bw(base_size=text_size+2) +
    theme(axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          legend.margin = margin(b=60),
          ) +
    xlab("Method") +
    labs(fill="Method"),
  nrow = 2,
  labels = c("", "C"),
  label_size = text_size * 2.5,
  vjust = -4,
  rel_heights = c(1.5, 0.3)
)



ggsave("fig3_simulated_data_performances.png", out_plot, width=8, height=10, bg="white")



