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




get_method_custom_colors <- function() {
  c(
    # DIABLO family — blues (light → dark)
    "DIABLO-full_ncomp-1"       = "#9ECAE1",
    "DIABLO-full_ncomp-2"       = "#4292C6",
    "DIABLO-null_ncomp-1"       = "#2171B5",
    "DIABLO-null_ncomp-2"       = "#084594",
    # MOFA family — greens (light → dark)
    "MOFA-Factor1 + glmnet"     = "#74C476",
    "MOFA-Factor2 + glmnet"     = "#238B45",
    # Singletons
    "MOGONET"                   = "#FD8D3C",   # orange
    "multiview"                 = "#E377C2",   # pink
    "integrao"                  = "#D62728",   # red
    "caret_multimodal"          = "#17BECF",    # teal  ← recommended
    # "caret_multimodal"        = "#8C6D31",    # brown ← warm alternative
    # RGCCA family — purples (light → dark)
    "RGCCA-full_ncomp-1 + lda"  = "#BCBDDC",
    "RGCCA-null_ncomp-1 + lda"  = "#9E9AC8",
    "RGCCA-full_ncomp-2 + lda"  = "#756BB1",
    "RGCCA-null_ncomp-2 + lda"  = "#54278F"
  )
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

# ==============================================================================
# CONSTANTS TO USE


# ── Method colors (group by algorithm family) ─────────────────────────────────
method_colors <- c(
  # DIABLO — Blues (dark → light: null > full, ncomp2 > ncomp1)
  "DIABLO-null_ncomp-1"      = "#2166AC",
  "DIABLO-null_ncomp-2"      = "#4393C3",
  "DIABLO-full_ncomp-1"      = "#92C5DE",
  "DIABLO-full_ncomp-2"      = "#C6DBEF",

  # RGCCA — Purples
  "RGCCA-null_ncomp-1 + lda" = "#6A3D9A",
  "RGCCA-null_ncomp-2 + lda" = "#9970AB",
  "RGCCA-full_ncomp-1 + lda" = "#C2A5CF",
  "RGCCA-full_ncomp-2 + lda" = "#DEC9E9",

  # MOFA — Greens
  "MOFA-Factor1 + glmnet"    = "#1B7837",
  "MOFA-Factor2 + glmnet"    = "#5AAE61",

  # Singletons — distinct neutrals
  "integrao"                 = "#D6604D",   # muted red
  "caret_multimodal"         = "#F4A582",   # salmon
  "MOGONET"                  = "#E08214",   # amber
  "multiview"     = "#543005"    # dark brown
)

method_family_colors <- c(
  # DIABLO — Blues (dark → light: null > full, ncomp2 > ncomp1)
  "DIABLO"      = "#4393C3",

  # RGCCA — Purples
  "RGCCA" = "#6A3D9A",



  # MOFA — Greens
  "MOFA"    = "#5AAE61",

  # Singletons — distinct neutrals
  "INTEGRAO"                 = "#D6604D",   # muted red
  "CARET"         = "#F4A582",   # salmon
  "MOGONET"                  = "#E08214",   # amber
  "MULTIVIEW"     = "#543005"    # dark brown
)

# ── AUC dot plot — single neutral, shape encodes dataset ──────────────────────
auc_color <- "#4D4D4D"

# ── Heatmap scales ────────────────────────────────────────────────────────────
# Jaccard: sequential orange (use with circlize::colorRamp2)
jaccard_col <- colorRamp2(c(0, 0.5, 1), c("#FFF5EB", "#FD8D3C", "#7F2704"))

# Binary: stark 2-color categorical
binary_colors <- c("0" = "#F7F7F7", "1" = "#01665E")  # light grey + dark teal

