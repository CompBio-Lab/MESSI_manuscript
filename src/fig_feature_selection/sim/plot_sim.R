doc <- "

This script is used to create figure 3 of feature selection for sim data.

Usage:
  plot_sim.R [options]

Options:
  --input_path=INPUT      Path to read in the feature selection result
  --output_path=OUTPUT    Path to write out output plot
  --width=WIDTH           Width of the graph [default: 7]
  --height=height         Height of the graph [default: 7]
  --device=DEVICE         Device to print out [default: png]
  --dpi=DPI               Dots per inch [default: 300]
  --show_title=ST         Show plot title [default: 1]
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
suppressPackageStartupMessages(library(ComplexHeatmap))
library(cowplot)

# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))



#dd <- readRDS("data/processed/fig_feature_selection_sim_plot_data.rds")


# Base grid plot for simulated dataset filter by cor
plot_corr_grid <- function(plot_data, cor, method_palette="Paired", text_size=12) {
  #title <- paste0("Feature Selection Sensitivity for simulated data with correlation = ", cor)
  title <- paste0("Correlation = ", cor)
  plot_data %>%
    filter(corr == cor) %>%
    ggplot(aes(x = signal, y = sensitivity, fill = method)) +
    geom_boxplot(
      alpha = 0.7,
      position = position_dodge(width = 0.8), # Adjust dodge width
      width = 0.6, # Box width
      outlier.size = 1.5 # Smaller outliers
    ) +
    theme_half_open(text_size) +
    panel_border() +
    background_grid() +
    labs(x = "Signal", y = "Sensitivity", fill = "Method") +
    # we set the left and right margins to 0 to remove
    # unnecessary spacing in the final plot arrangement.
    theme(
      plot.title = element_text(hjust = 0.5),
      plot.margin = margin(6, 0, 6, 0)
    ) +
    # remove extra space between panel and axis
    #scale_y_continuous(expand = c(1, 1)) +
    scale_fill_brewer(palette = method_palette) +
    facet_grid(p ~ n, labeller = label_both, scales = "free")
}

plot_sim <- function(input_data, method_palette, text_size) {
  # This fun depends on the plot_corr_grid
  # Need to manually fix the levels of some columns
  # Since bug with mutate across ?

  #n_order <- input_data$n %>% unique() %>% sort()
  #p_order <- input_data$p %>% unique() %>% sort()
  signal_order <- input_data$signal %>% unique() %>% sort()
  corr_order <- input_data$corr %>% unique() %>% sort()
  # Then transform it here
  plot_data <- input_data %>%
    # Fix: mofa factor uses - and not _ to delim
    mutate(
      method = case_when(
        stringr::str_detect(method, "Factor") ~ stringr::str_replace(method, "_", "-") ,
        TRUE ~ method
      )
    ) %>%
    mutate(
      #n = factor(n, levels = n_order),
      #p = factor(p, levels = p_order),
      signal = factor(signal, levels = signal_order),
      corr = factor(corr, levels = corr_order)
    )


  signal_labels <- paste0("Signal = ", plot_data$signal |> unique())
  names(signal_labels) <- plot_data$signal |> unique()
  corr_labels <- paste0("Cor = ", plot_data$corr |> unique())
  names(corr_labels) <- plot_data$corr |> unique()

  # Get the color palette for methods
  custom_method_palette <- get_method_custom_colors(method_palette)

  sim_plot <- plot_data %>%
    #group_by(method, dataset, signal, corr) %>%
    #summarize(mean_sensitivity = mean(sensitivity)) %>%
    # TODO: Note used a mean here
    #ggplot(aes(x = method, y = sensitivity, fill = method)) +
    ggplot(aes(x = method, y = sensitivity, color = method)) +
    #stat_boxplot(geom ='errorbar', width=0.25) +
    # geom_boxplot(
    #   alpha = 0.7,
    #   position = position_dodge(width = 0.8), # Adjust dodge width
    #   width = 0.6, # Box width
    #   outlier.size = 1.5 # Smaller outliers
    # ) +
    #geom_bar(stat="identity") +
    geom_point(aes(shape=view), size=3) +
    theme_half_open(text_size) +
    panel_border() +
    background_grid() +
    labs(x = "Method", y = "Mean sensitivity across views", fill = "Method") +
    # we set the left and right margins to 0 to remove
    # unnecessary spacing in the final plot arrangement.
    # remove extra space between panel and axis
    #scale_y_continuous(expand = c(1, 1)) +
    scale_color_manual(values = custom_method_palette) +
    facet_grid(
      corr ~ signal,
      #scales = "free",
      labeller = labeller(signal = signal_labels, corr = corr_labels)
    ) +
    #scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
    theme(
      plot.title = element_text(hjust = 0.5),
      #plot.margin = margin(6, 0, 6, 0),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      axis.title.x = element_blank(),
      legend.title = element_text(size = text_size + 2),
      legend.text = element_text(size = text_size),
      legend.position = "bottom",
      legend.justification = "center",
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      panel.grid.major.y = element_blank(),
      strip.background = element_rect(fill = "white", color = NA),
      strip.text = element_text(color = "black", face = "bold", size = text_size - 2),
    ) +
    guides(color = guide_legend(nrow = 3))


  # # KINDA useless here since I knew only 3 corr
  # # https://wilkelab.org/cowplot/articles/shared_legends.html
  # # Make the individual plots first
  # # p1 <- plot_corr_grid(plot_data, cor = corr_order[1],
  # #                      method_palette = method_palette,
  # #                      text_size=text_size) + xlab(NULL)
  # # p2 <- plot_corr_grid(plot_data, cor = corr_order[2],
  # #                      method_palette = method_palette,
  # #                      text_size=text_size) + ylab(NULL)
  # # p3 <- plot_corr_grid(plot_data, cor = corr_order[3],
  # #                      method_palette = method_palette,
  # #                      text_size=text_size) + xlab(NULL) + ylab(NULL)
  # # # arrange the three plots in a single row
  # # prow <- plot_grid(
  # #   p1 + theme(legend.position="none"),
  # #   p2 + theme(legend.position="none"),
  # #   p3 + theme(legend.position="none"),
  # #   align = 'vh',
  # #   labels = c("i", "ii", "iii"),
  # #   hjust = -1,
  # #   nrow = 1
  # # )
  # # extract the legend from one of the plots
  # # legend <- get_legend(
  # #   # create some space to the left of the legend
  # #   p1 + theme(legend.box.margin = margin(0, 0, 0, 12))
  # # )
  #
  # # now add the title
  # title <- ggdraw() +
  #   draw_label(
  #     "Feature Selection Sensitivity for simulated data with varied n, p, signal and correlation",
  #     #fontface = 'bold',
  #     x = 0.5,
  #     hjust = 0.5
  #   ) +
  #   theme(
  #     # Possible themes to add on later
  #   )
  # # add the legend to the row we made earlier. Give it one-third of
  # # the width of one plot (via rel_widths).
  # # the height via rel_heights
  # prow <- plot_grid(
  #   title, prow,
  #   ncol = 1,
  #   # rel_heights values control vertical title margins
  #   rel_heights = c(0.1, 1)
  # )
  #
  #
  # # extract a legend that is laid out horizontally
  # legend <- get_legend_35(
  #   p1 +
  #     guides(fill = guide_legend(nrow = 1)) +
  #     theme(
  #       legend.direction = "horizontal",
  #       legend.justification="center" ,
  #       legend.box.just = "bottom"
  #     )
  # )
  #
  # # Add legend
  # sim_plot <- plot_grid(prow, legend, nrow = 2, rel_heights = c(1, 0.2))

  return(sim_plot)
}

# ==============================================================================
# Parse the cli

opt <- docopt::docopt(doc)

# Convenient vars
input_path <- opt$input_path
if (is.null(input_path)) {
  input_path <- "data/processed/fig_feature_selection_sim_plot_data.rds" |>
    here::here()
}
output_path <- opt$output_path
if (is.null(output_path)) {
  output_path <- "results/figures/fig_feature_selection_sim.png" |>
    here::here()
}
# Plot params
text_size <- 8
width <- as.numeric(opt$width)
height <- as.numeric(opt$height)
device <- opt$device
dpi <- as.numeric(opt$dpi)
method_palette <- "Paired"
show_title <- opt$show_title |> as.integer() |> as.logical()

# ==============================================================================
input_data <- readRDS(input_path)
# Plot it
#out_plot <- ggplot() + ggtitle("Fake plot placeholder for feature selection (sim)")
const <- 2
text_size <- text_size + 6
width <- width + (const * 1.8)
height <- height + const
out_plot <- plot_sim(input_data, method_palette, text_size=text_size)

if (!show_title) {
  out_plot <- out_plot + theme(legend.title = element_blank())
}


# TODO: making a placeholder now for sim data

ggsave(output_path, plot = out_plot,
      width = width, height = height, device=device, dpi=dpi, bg="white")


saveRDS(out_plot,
        file = here::here("data/processed/feature_selection_sim.rds")
)
message("Saved image of ", width, " x ", height, " to ", output_path)



