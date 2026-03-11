# ============================================================================
# Utility Functions for Saving Plots with Reusable Objects
# ============================================================================
# These functions ensure consistent saving of both PNG files and ggplot
# objects across all analysis steps.
#
# Usage in your plotting scripts:
#   source("src/utils/save_plot_with_object.R")
#   save_plot_both(plot_obj, "output.png", width=10, height=6)
# ============================================================================

#' Save both PNG and ggplot object
#'
#' @param plot_obj A ggplot2 object
#' @param png_path Path where PNG should be saved
#' @param width Width in inches
#' @param height Height in inches
#' @param dpi Resolution (default 300)
#' @param plot_obj_dir Optional directory for plot objects. If NULL, uses same
#'   directory as PNG but in results/plot_objects/ hierarchy
#' @return Invisible path to RDS file
save_plot_both <- function(plot_obj,
                           png_path,
                           width = 10,
                           height = 6,
                           dpi = 300,
                           plot_obj_dir = NULL) {

  # Ensure output directory exists
  png_dir <- dirname(png_path)
  if (!dir.exists(png_dir)) {
    dir.create(png_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Save PNG
  ggplot2::ggsave(
    filename = png_path,
    plot = plot_obj,
    width = width,
    height = height,
    dpi = dpi
  )
  message("Saved PNG:   ", png_path, "\n")

  # Determine RDS path
  if (is.null(plot_obj_dir)) {
    # Automatically mirror structure in plot_objects/
    # E.g., results/plots/qc/sample_qc.png
    #    -> results/plot_objects/qc/sample_qc.rds
    rds_path <- sub(
      "results/plots/",
      "results/plot_objects/",
      png_path
    )
    rds_path <- sub("\\.png$", ".rds", rds_path)
  } else {
    # Use specified directory
    base_name <- basename(png_path)
    rds_path <- file.path(
      plot_obj_dir,
      sub("\\.png$", ".rds", base_name)
    )
  }

  # Ensure RDS directory exists
  rds_dir <- dirname(rds_path)
  if (!dir.exists(rds_dir)) {
    dir.create(rds_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Save plot object
  saveRDS(plot_obj, rds_path)
  message("Saved plot object:  ", rds_path, "\n")

  invisible(rds_path)
}
