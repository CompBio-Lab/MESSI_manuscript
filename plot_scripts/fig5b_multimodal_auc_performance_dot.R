library(ggplot2)
library(dplyr)
#library(ggtext)

source("src/common_helpers/save_plot_both.R")
source("src/common_helpers/plot_utils.R")
source("src/common_helpers/standardize_data_funs.R")

# --- Data ---
df <- data.table::fread("data/raw/multimodal_data/metrics.csv") |>
  dplyr::rename(method = method_name) |>
  mutate(
    dataset = str_replace_all(dataset, "_", " + ") |>
      tools::toTitleCase()
  ) %>%
  # Standardize the method names
  standardize_method_names2() %>%
  # For performance plot, only retain biggest ncomp/factor
  filter(!str_detect(method, "-1"))



# Order methods by mean AUC across datasets
method_order <- df |>
  group_by(method, dataset) |>
  summarise(mean_auc = mean(auc), .groups = "drop") |>
  filter(dataset == "Electrical + Omics") |>
  arrange(desc(mean_auc)) |>
  pull(method)



# --- Plot ---

out_plot <- df |>  mutate(
  method  = factor(method, levels = rev(method_order)),  # rev so top = highest on y-axis
) |>
  ggplot(aes(x = auc, y = method, shape = dataset)) +
  # Ceiling zone shading
  annotate("rect",
           xmin = 0.95, xmax = 1.005, ymin = -Inf, ymax = Inf,
           fill = "grey85", alpha = 0.5) +

  # Lollipop sticks from 0.5 to the dot
  geom_linerange(aes(xmin = 0.5, xmax = auc),
                 linewidth = 0.4, alpha = 0.3) +

  # Dots
  geom_point(size = 4, color=auc_color) +

  # Optional: value labels only for Electrical (most informative spread)
  geom_text(
    data = ~filter(.x, dataset == "Electrical + Omics"),
    aes(label = round(auc, 3)),
    nudge_y = 0.4, size = 2.5
  ) +
  # scale_color_manual(values = c(
  #   "Clinical + Omics"   = "#2166ac",
  #   "Imaging + Omics"    = "#4dac26",
  #   "Electrical + Omics" = "#d6604d"
  # )) +

  # Facet — one panel per dataset, shared y-axis
  #facet_wrap(~ dataset, ncol = 3) +

  scale_x_continuous(limits = c(0.5, 1.01),
                     breaks = seq(0.5, 1.0, 0.1)) +
  labs(
    x        = "AUC",
    y        = NULL,
    title    = "Multimodal integration performance",
    subtitle = "Grey band marks ceiling zone (AUC > 0.95)"
  ) +

  theme_bw(base_size = 11) +
  theme(
    strip.text         = element_text(face = "bold"),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_line(colour = "grey90")
  )




#library(patchwork)
# out_plot  <- p_bar / dot_plot +
#   plot_layout(heights = c(1, 4))


output_png_path <- "results/multimodal/fig5b_multimodal_auc_performance_dot.png"
save_plot_both(out_plot, output_png_path, width=12, height=8)

