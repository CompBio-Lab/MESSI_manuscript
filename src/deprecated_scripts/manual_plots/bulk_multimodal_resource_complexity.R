# Load custom scripts
source("plot_scripts/computational_resources_utils.R")
source("src/common_helpers/save_plot_both.R")
source(here::here("src/common_helpers/plot_utils.R"))

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

# Load library
suppressPackageStartupMessages(library(dplyr))


# Need a function to run each data type separately
get_complexity <- function(data_dir=NULL) {
  if (is.null(data_dir)) stop("Need to supply directory of the data to load like: 'data/raw/some_data_dir'")

  # Load utils
  trace_path <- here::here(data_dir, "execution_trace.txt")
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
  metadata_path <- here::here(data_dir, "parsed_metadata.csv")
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
    # CHECK HERE
    group_by(method, dataset_name, action, tag, dataset_size) %>%
    summarize(
      realtime_sec = mean(realtime_sec),
      peak_rss_mb = mean(peak_rss_mb),
      .groups = "drop"
    ) %>%
    ungroup() %>%
    group_by(method, dataset_name, action, dataset_size) %>%
    summarise(
      across(c(realtime_sec, peak_rss_mb), median),
      .groups = "drop"
    ) %>%
    ungroup() |>
    mutate(data_type=basename(data_dir))
  return(combined_df)
}


plot_fig_join_bulk_multimodal_resource_complexity <- function(
    output_path=NULL,
    text_size=7) {

  if (is.null(output_path)) {
    output_path <- "results/join_bulk_multimodal/fig_join_bulk_multimodal_resource_complexity.png"
  }

  message("\nUsing text size of: ", text_size)

  bulk_complexity       <- get_complexity("data/raw/bulk_data/")
  multimodal_complexity <- get_complexity("data/raw/multimodal_data/")

  # ===============
  # Now combine both rowise
  combined_df <- bind_rows(bulk_complexity, multimodal_complexity) %>%
    # Drop the chol and kipan
    filter(!dataset_name %in% c("tcga-chol", "tcga-kipan")) %>%
    # Rename here
    mutate(method = str_replace(method, "CARET", "CARETMULTIMODAL")) |>
    mutate(color_label = method) %>%
    # Then fix the namings back
    mutate(method = case_when(
      method == "CARETMULTIMODAL" ~ "caretMultimodal",
      method == "INTEGRAO" ~ "IntegrAO",
      method == "MULTIVIEW" ~ "Multiview",
      TRUE ~ method
    ))

  # Extract method names
  method_names <- combined_df$method |> unique() |> sort()

  text_size <-  48 # 32

  out_plot <- combined_df %>%
    tidyr::pivot_longer(realtime_sec:peak_rss_mb, names_to = "metric") %>%
    ggplot(aes(x=dataset_size, y=value,color=color_label, group=method)) +
    geom_line(linewidth=1) +
    geom_point(size = 10) + # Size 3 ) +
    facet_grid(
      metric ~ action,
      scales = "free",
      labeller = labeller(
        action = as_labeller(
          c(
            model_assessment = "Model Assessment",
            model_selection  = "Model Selection"
          )
        ),
        metric = as_labeller(
          c(
            peak_rss_mb = "Memory (MB)",
            realtime_sec  = "Runtime (Seconds)"
          )
        )
      )
    ) +
    geom_text_repel(
      data = . %>%
        group_by(method, action, metric) %>%
        slice_max(dataset_size, n = 1),
      aes(label = method),
      direction = "y",
      nudge_x = 0.15,
      hjust = 0,
      segment.size = 0.3,
      size = 8,
      show.legend = FALSE
    ) +
    # add right margin so labels aren't clipped
    coord_cartesian(clip = "off") +
    theme_bw(base_size = text_size) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      panel.grid.minor.y = element_line(linewidth = 0.3, color = "grey85"),
      #plot.margin = margin(5, 40, 5, 5)
      #legend.position = "none"
    ) +
    scale_color_manual(values=method_family_colors, labels=method_names) +
    scale_x_log10(labels = scales::label_comma()) +
    scale_y_log10() +
    labs(x = "Dataset Size", y = NULL)

the_plot <- get_legend_35(
  out_plot +
    guides(
      color=guide_legend(nrow=1,title=NULL,
                        )
    )
) |> ggdraw()

  the_plot <- out_plot +
   theme(legend.position = "none")
  the_plot
  ggsave("aaa.svg", the_plot, width=24, height=10, bg="white", dpi=1200)
  #ggsave("aaa.png", the_plot, width=20, height=10, bg="white", dpi=1200)

  # Lastly save it
  save_plot_both(out_plot, output_path, width=8, height=10)

  return(out_plot)
}

plot_fig_join_bulk_multimodal_resource_complexity(
  output_path="results/join_bulk_multimodal/fig_join_bulk_multimodal_resource_complexity.png",
  text_size = 10
)

