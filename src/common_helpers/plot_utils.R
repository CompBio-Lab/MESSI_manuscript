# ==============================================================================
# GGPLOT2 USAGE
# ==============================================================================

# The theme for simulation data plot
custom_theme_for_sim_plot <- function() {
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, vjust = 1, size = 11),
    #axis.title = element_text(size = 12),
    axis.ticks.length.x = unit(0.2, "cm"),
    strip.background = element_rect(fill = "gray95", color = "gray70"),
    strip.text = element_text(face = "bold"),
    panel.grid.major.y = element_line(color = "gray90", linewidth = 0.4),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.background = element_rect(fill = "white"),
    legend.position = "bottom",
    legend.title = element_text(size = 20),
    legend.text = element_text(size = 15),
    legend.key.width = unit(1.2, "cm"),
    plot.margin = margin(10, 10, 10, 10),
    panel.spacing = unit(1, "lines"),
  )
}



# Custom palette for the methods
get_method_custom_colors <- function(method_palette="Paired") {
  # This fun is to match the color choices used for the methods
  custom_method_palette <-  RColorBrewer::brewer.pal(n=12, name=method_palette)
  method_order_names <- c(
    "DIABLO-full_ncomp-1",
    "DIABLO-full_ncomp-2",
    "DIABLO-null_ncomp-1",
    "DIABLO-null_ncomp-2",
    "MOFA-Factor1 + glmnet",
    "MOFA-Factor2 + glmnet",
    "MOGONET",
    "multiview",
    "RGCCA-full_ncomp-1 + lda",
    "RGCCA-null_ncomp-1 + lda",
    "RGCCA-full_ncomp-2 + lda",
    "RGCCA-null_ncomp-2 + lda"
  )
  names(custom_method_palette) <- method_order_names
  return(custom_method_palette)
}

# Extract legend
get_legend_35 <- function(plot) {
  # return all legend candidates
  legends <- cowplot::get_plot_component(plot, "guide-box", return_all = TRUE)
  # find non-zero legends
  nonzero <- vapply(legends, \(x) !inherits(x, "zeroGrob"), TRUE)
  idx <- which(nonzero)
  # return first non-zero legend if exists, and otherwise first element (which will be a zeroGrob)
  if (length(idx) > 0) {
    return(legends[[idx[1]]])
  } else {
    return(legends[[1]])
  }
}

# ==============================================================================
# COMPLEX HEATMAP USAGE
# ==============================================================================

# Function to determine text color based on background color for heatmap
get_text_color <- function(fill_color) {
  # Convert the input color (e.g., "red", "#FF0000") to RGB components (0–255 scale)
  rgb <- grDevices::col2rgb(fill_color)

  # Calculate perceived luminance using the standard formula from ITU-R BT.601:
  # Luminance = 0.299 * R + 0.587 * G + 0.114 * B
  # These weights reflect human sensitivity: we see green most strongly, then red, then blue.
  # The result is then normalized to a 0–1 scale by dividing by 255.
  luminance <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) / 255

  # Choose text color based on luminance:
  # If the background is dark (luminance < 0.5), use white text for contrast.
  # Otherwise, use black text.
  ifelse(luminance < 0.5, "white", "black")
}

