doc <- "

This script is used to plot fgsea part 1 results

Usage:
  03a_plot_fgsea_part1.R [options]

Options:
  --input_path=INPUT_PATH       File to load fgsea part1 summary
  --output_path=OUTPUT_PATH     File to output the plot data
  --width=WIDTH                 Width of the figure [default: 10]
  --height=HEIGHT               Height of the figure [default: 8]
"


library(ggplot2)
library(tidytext)
library(data.table)
suppressPackageStartupMessages(library(dplyr))

# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))


plot_bar <- function(data, custom_method_palette) {
  significant_pathways_method_gs_plot_obj <- data %>%
    # And reorder it for plotting
    dplyr::mutate(label_reordered = reorder_within(method, mean_n_sig, gs_collection_name)) %>%
    ggplot(aes(x = label_reordered, y = mean_n_sig, fill = method)) +
    geom_errorbar(aes(ymin = mean_n_sig, ymax = mean_n_sig + sd_n_sig),
                  width = 0.2, position = position_dodge(0.9)) +
    geom_bar(stat = "identity") +
    facet_wrap(~ gs_collection_name, scales = "free") +
    labs(x = "Method", y = "Mean # Significant Pathways",
         title = "Significant Pathways by Method and Gene Set Collection") +
    theme_bw() +
    tidytext::scale_x_reordered() +
    scale_y_log10(expand = expansion(mult = c(0, 0.1))) +
    coord_flip() +
    scale_fill_manual(values = custom_method_palette) +
    theme(
      plot.title = element_text(hjust = 0.5),
      panel.grid.major.y = element_blank()
    )

  return(significant_pathways_method_gs_plot_obj)
}

main <- function(input_path, output_path, width, height, method_palette="Paired") {
  if (is.null(input_path)) {
    input_path <- "data/processed/fgsea_part1_summary_df.csv"
  }

  if (is.null(output_path)) {
    output_path <- "data/processed/fig_fgsea_panel_a_plot_data.rds"
  }

  combined_summary <- fread(here::here(input_path))
  # Get the color palette for methods
  custom_method_palette <- get_method_custom_colors(method_palette)
  # Get the plot object
  significant_pathways_method_gs_plot_obj <- plot_bar(combined_summary, custom_method_palette)

  # Save the figure
  ggsave(
    filename = "results/figures/fig_fgsea_panel_a.png",
    plot = significant_pathways_method_gs_plot_obj,
    width = width,
    height = height
  )

  # And save the plot data as rds
  saveRDS(significant_pathways_method_gs_plot_obj,
          file = here::here(output_path))
  message("\nSaved plot data for fgsea part 1 into ", output_path)

}

palette <- "Paired"

opt <- docopt::docopt(doc)
main(input_path=opt$input_path, output_path=opt$output_path,
     width=as.numeric(opt$width),
     height=as.numeric(opt$height),
     method_palette=palette)


# =====================================
# Then in a summarized way, on average for each method

# ==============================================
# THIS IS C2

#
# c2_summarized_n_sig_plot <- c2_summarized_method %>%
#   ggplot(
#     aes(x = reorder(method, -mean_n_sig),
#         y = mean_n_sig,
#         fill = method)
#   ) +
#   geom_errorbar(aes(
#     ymin = mean_n_sig, ymax = mean_n_sig + sd_n_sig, width = 0.6)
#   ) +
#   geom_bar(stat = "identity") +
#   labs(x = "Method", y = "Mean Number of Pathways per Dataset",
#        title = "Mean Number of Pathways Detected per Method") +
#   theme_bw() +
#   scale_y_log10() +
#   theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#   scale_fill_brewer(palette = palette)
#
# c2_summarized_n_sig_plot
#
#
#
# ggsave("c2_summarized_n_sig.png",
#        plot = c2_summarized_n_sig_plot,
#        width=width, height=height)
#
# # =================================================
# # THIS IS C6
#
# c6_summarized_n_sig_plot <- c6_summarized_method %>%
#   ggplot(
#     aes(x = reorder(method, -mean_n_sig),
#         y = mean_n_sig,
#         fill = method)
#   ) +
#
#   geom_errorbar(aes(ymin = mean_n_sig, ymax = mean_n_sig + sd_n_sig, width=0.6)) +
#   geom_bar(stat = "identity") +
#
#
#   labs(x = "Method", y = "Mean Number of Pathways per Dataset",
#        title = "Mean Number of Pathways Detected per Method") +
#   theme_bw() +
#   scale_y_log10() +
#   theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#   scale_fill_brewer(palette = palette)
#
# c6_summarized_n_sig_plot
#
# ggsave("c6_summarized_n_sig.png",
#        plot = c6_summarized_n_sig_plot,
#        width=width, height=height)
