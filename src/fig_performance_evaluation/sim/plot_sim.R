doc <- "

This script is used to create figure of performance evaluation for sim data

Usage:
  plot_sim.R [options]

Options:
  --input_path=INPUT      Path to load input data
  --output_path=OUTPUT    Path to write out plot
  --width=WIDTH           Width of the graph [default: 7]
  --height=height         Height of the graph [default: 7]
  --device=DEVICE         Device to print out [default: png]
  --dpi=DPI               Dots per inch [default: 300]
  --show_title=ST         Show plot title [default: 1]
"

# Parse doc
opt <- docopt::docopt(doc)

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))

# ==============================================================================
# BOXPLOT DISTRIBUTION (DEPRECATED FOR NOW)
# plot_box_dist <- function(sim_df, custom_method_palette, text_size, signal_labels, corr_labels, x_lab, y_lab) {
#   p <- sim_df %>%
#     ggplot(aes(x=method, y=auc, fill=method)) +
#     stat_boxplot(geom ='errorbar', width=0.25) +
#     geom_boxplot()+
#     #scale_fill_brewer(palette = method_palette) +
#     # TODO: use manual colors now to match everywhere
#     scale_fill_manual(values = custom_method_palette) +
#     facet_grid(
#       corr ~ signal,
#       #scales = "free",
#       labeller = labeller(signal = signal_labels, corr = corr_labels)
#     ) +
#     theme_bw() +
#     ggtitle("Performance evaluation on simulated datasets") +
#     # And change Grid label names
#     theme(
#       # Rotate text of methods names
#       #axis.text.x = element_text(angle = 45, hjust=1),
#       axis.text.y = element_text(
#         size = text_size
#       ),
#       axis.title.y = element_text(size = text_size + 2),
#       axis.title.x = element_blank(),
#       axis.text.x = element_blank(),
#       axis.ticks.x = element_blank(),
#       strip.text.x = element_text(
#         size = text_size, color = "red", face = "bold.italic"
#       ),
#       # TODO: Maybe consider changing color of the grid ribbon color?
#       #strip.background.x = element_rect(fill="blue"),
#       strip.text.y = element_text(
#         size = text_size, color = "red", face = "bold.italic"
#       ),
#       plot.title = element_text(hjust = 0.5),
#       legend.title = element_text(size = text_size + 2),
#       legend.text = element_text(size = text_size),
#       legend.position = "bottom"
#     ) +
#     guides(fill = guide_legend(nrow = 3)) +
#     # Lastly the labels
#     labs(x=x_lab, fill=x_lab, y = y_lab)
#   return(p)
# }
# ==============================================================================
# BAR PLOT
plot_bar_dist <- function(sim_df, custom_method_palette, text_size, signal_labels, corr_labels, x_lab, y_lab) {
  p <- sim_df %>%
    ggplot(aes(x=method, y=auc, fill=method)) +
    geom_bar(stat="identity")+
    #scale_fill_brewer(palette = method_palette) +
    # TODO: use manual colors now to match everywhere
    scale_fill_manual(values = custom_method_palette) +
    facet_grid(
      corr ~ signal,
      #scales = "free",
      labeller = labeller(signal = signal_labels, corr = corr_labels)
    ) +
    theme_bw() +
    ggtitle("Performance evaluation on simulated datasets") +
    # And change Grid label names
    theme(
      # Rotate text of methods names
      #axis.text.x = element_text(angle = 45, hjust=1),
      axis.text.y = element_text(
        size = text_size
      ),
      axis.title.y = element_text(size = text_size + 2),
      axis.title.x = element_blank(),
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank(),
      strip.text.x = element_text(
        size = text_size, color = "red", face = "bold.italic"
      ),
      # TODO: Maybe consider changing color of the grid ribbon color?
      #strip.background.x = element_rect(fill="blue"),
      strip.text.y = element_text(
        size = text_size, color = "red", face = "bold.italic"
      ),
      plot.title = element_text(hjust = 0.5),
      legend.title = element_text(size = text_size + 2),
      legend.text = element_text(size = text_size),
      legend.position = "bottom"
    ) +
    guides(fill = guide_legend(nrow = 3)) +
    # Lastly the labels
    labs(x=x_lab, fill=x_lab, y = y_lab)
  return(p)
}

# ==============================================================================
# For sim data, boxplot stratify by params
# This function has details of showing boxplot facet by correlation and
# effect combination in intersim strategy simulated data
plot_fig1_sim <- function(
    input_data, text_size=12,
    x_lab = "Method", y_lab="Mean Auc Score from 5-fold CV",
    method_palette="Paired") {

  if (!is.data.frame(input_data)) stop("Plot data for simulated data should be dataframe")
  sim_df <- input_data

  # Get the color palette for methods
  custom_method_palette <- get_method_custom_colors(method_palette)

  # Labeller for facetting
  signal_labels <- paste0("Signal = ", sim_df$signal |> unique())
  names(signal_labels) <- sim_df$signal |> unique()
  corr_labels <- paste0("Cor = ", sim_df$corr |> unique())
  names(corr_labels) <- sim_df$corr |> unique()
  # Then the plotting
  p <- plot_bar_dist(
    sim_df, custom_method_palette = custom_method_palette,
    text_size = text_size, signal_labels, corr_labels = corr_labels,
    x_lab = x_lab, y_lab = y_lab
  )
  return(p)


}




# ==============================================================================
# Plot here
# Load the variables from cli
input_path <- opt$input_path
if (is.null(input_path)) {
  input_path <- "data/processed/fig_performance_evaluation_sim_plot_data.rds" |>
    here::here()
}
output_path <- opt$output_path
if (is.null(output_path)) {
  output_path <- "results/figures/fig_performance_evaluation_sim.png" |>
    here::here()
}

# Plot params
method_palette <- "Paired"
dataset_palette <- "Pastel1"
text_size <- 7
width <- as.numeric(opt$width)
height <- as.numeric(opt$height)
device <- opt$device
dpi <- as.numeric(opt$dpi)
show_title <- opt$show_title |> as.integer() |> as.logical()


# ================================
# And load the input data
input_data <- readRDS(input_path)


# Verbose message
message("\nRendering figure of performance evaluation of classification")
message("\nInput path: ", input_path)

out_plot <- plot_fig1_sim(
  input_data = input_data,
  text_size = text_size,
  method_palette = method_palette
)





if (!show_title) {
  out_plot <- out_plot + theme(legend.title = element_blank())
}

# Lastly save it to output
ggsave(output_path, plot = out_plot, width = width, height = height,
       device = device, dpi = dpi, create.dir = TRUE)

saveRDS(out_plot,
        file = here::here("data/processed/perf_evaluation_sim.rds")
)

message("Saved image of ", width, " x ", height, " to ", output_path)



