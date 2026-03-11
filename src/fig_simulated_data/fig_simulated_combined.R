# ==============================================================================
# Figure 3: Simulated Data Performance Assembly
# Description: Load pre-built plot panels and assemble them into a multi-panel
#              publication figure using cowplot.
# ==============================================================================

# --- Libraries ----------------------------------------------------------------
suppressPackageStartupMessages({
  library(ggplot2)
  library(cowplot)
})

# --- Custom sources -----------------------------------------------------------
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/standardize_data_funs.R"))
source(here::here("src/common_helpers/save_plot_both.R"))


# ==============================================================================
# 1. Load pre-built panels
# ==============================================================================
# Load saved ggplot panel objects from RDS files.
load_sim_panels <- function(panel_dir = "results/simulated") {
  paths <- list(
    auc           = file.path(panel_dir, "fig_simulated_panel_A_auc_bar.rds"),
    feat          = file.path(panel_dir, "fig_simulated_panel_B_feat_sensitivity_specificity_bars.rds"),
    computational = file.path(panel_dir, "fig_simulated_panel_C_computational_resources_bar.rds")
  )

  message("[load_sim_panels] Loading panels from: ", panel_dir)
  panels <- lapply(paths, function(p) {
    if (!file.exists(p)) stop("Panel file not found: ", p)
    message("[load_sim_panels]   ", basename(p))
    readRDS(p)
  })

  message("[load_sim_panels] All ", length(panels), " panels loaded successfully")
  return(panels)
}


# ==============================================================================
# 2. Assemble the top row (A + B)
# ==============================================================================
# Stack the AUC bar panel (A) and feature sensitivity/specificity panel (B).
assemble_top_row <- function(auc_panel, feat_panel, label_size) {
  message("[assemble_top_row] Stacking panels A and B...")

  top_plot <- plot_grid(
    auc_panel +
      xlab(NULL) +
      theme(legend.position = "none"),
    feat_panel,
    nrow        = 2,
    rel_heights = c(0.9, 1.5),
    align       = "v",
    axis        = "lr",
    labels      = c("A", "B"),
    label_size  = label_size
  )

  message("[assemble_top_row] Done")
  return(top_plot)
}


# ==============================================================================
# 3. Assemble the full figure (top + C)
# ==============================================================================
# Combine the top row with the computational resources panel (C).
assemble_full_figure <- function(top_plot,
                                 computational_panel,
                                 label_size,
                                 base_text_size) {
  message("[assemble_full_figure] Combining top row with panel C...")

  styled_panel_c <- computational_panel +
    theme_bw(base_size = base_text_size) +
    theme(
      axis.text.x        = element_blank(),
      axis.ticks.x       = element_blank(),
      panel.grid.major.x = element_blank(),
      legend.margin       = margin(b = 60, r = 20)
    ) +
    xlab(NULL) +
    labs(fill = "Method")

  full_figure <- plot_grid(
    top_plot,
    styled_panel_c,
    nrow        = 2,
    labels      = c("", "C"),
    label_size  = label_size,
    vjust       = -4,
    rel_heights = c(1.5, 0.3)
  )

  message("[assemble_full_figure] Done")
  return(full_figure)
}


# ==============================================================================
# 4. Save the figure
# ==============================================================================
# Save the assembled figure to disk.
save_figure <- function(figure,
                        out_path = "fig3_simulated_data_performances.pdf",
                        width    = 12,
                        height   = 14,
                        dpi      = 1200) {
  message("[save_figure] Saving to: ", out_path,
          " (", width, "x", height, " in, ", dpi, " dpi)")

  ggsave(
    filename = out_path,
    plot     = figure,
    width    = width,
    height   = height,
    bg       = "white",
    dpi      = dpi
  )

  message("[save_figure] Done")
}


# Run the full fig 3 simulated data performances
plot_fig_simulated_data_performances_main <- function(panel_dir = "results/simulated",
                 out_path  = "fig3_simulated_data_performances.pdf",
                 text_size = 12) {

  message("=== Figure 3: Simulated Data Performance Assembly ===")

  # Load panels

  panels <- load_sim_panels(panel_dir)

  # Layout parameters — text_size is expected from plot_utils.R
  label_size     <- text_size * 2.5
  base_text_size <- text_size + 2

  # Assemble
  top_plot <- assemble_top_row(panels$auc, panels$feat, label_size)
  full_fig <- assemble_full_figure(top_plot, panels$computational,
                                   label_size, base_text_size)

  # Save
  save_figure(full_fig, out_path)

  message("=== Figure assembly complete ===")
  return(invisible(full_fig))
}


# =============================================================================
# Execute it
plot_fig_simulated_data_performances_main(
  panel_dir = "results/simulated",
  out_path = "fig_simulated_data_performances.pdf",
  text_size = 12
)
