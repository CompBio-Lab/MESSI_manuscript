# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(tibble)
library(here)
library(stringr)
library(tidyr)
library(ggplot2)
library(cowplot)

# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/standardize_data_funs.R"))
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/fig_simulated_data/_simulated_data_utils.R"))


plot_simulated_panel_C_computational_resources_bar <- function(input_path=NULL,
                                           output_png_path=NULL,
                                           text_size=9.5) {
  if (is.null(input_path)) {
    input_path <- "data/processed/simulated/simulated_panel_C_plot_data.rds"
  }

  if (is.null(output_png_path)) {
    output_png_path <- "results/simulated/fig_simulated_panel_C_computational_resources_bar.png"
  }

  # Load the plot data, all plot adata that is not auc
  df <- readRDS(input_path)
  # ================================
  # The main plot code here
  # Use this order to make colors
  method_color_order <- df$method |> unique() |> sort()
  # And the rest of plot
  computation_usage_plot <- df %>%
    mutate(color_label = method |> str_replace_all("_", "") |> toupper()) %>%
    ggplot(aes(
      x = tidytext::reorder_within(method, median_val, action),
      y=median_val, fill=color_label)) +
    geom_bar(stat="identity") +
    labs(x="Method") +
    labs(y="Runtime (seconds)") +
    tidytext::scale_x_reordered() +
    scale_y_log10(labels = scales::label_comma(),
                  expand = expansion(mult = c(0, 0.07))) +
    # This method_family_colors is global variable in src/common_helpers/plot_utils.R
    scale_fill_manual(values=method_family_colors,
                      labels=method_color_order) +
    facet_wrap(
      scales="free",
      action ~ .,
      labeller = labeller(
        action = as_labeller(
          c(
            model_assessment = "Model Assessment",
            model_selection  = "Model Selection"
          )),
        ncol=2
      )) +
    theme_bw(text_size) +
    theme(legend.position = "none",
          axis.text.x = element_text(angle=45, hjust=1),
          panel.grid.major.x = element_blank()
          )


  # Lastly saving this
  save_plot_both(computation_usage_plot, output_png_path)
  return(computation_usage_plot)
}

plot_simulated_panel_C_computational_resources_bar(
  input_path="data/processed/simulated/simulated_panel_C_plot_data.rds",
  output_png_path="results/simulated/fig_simulated_panel_C_computational_resources_bar.png",
  text_size=12
)




