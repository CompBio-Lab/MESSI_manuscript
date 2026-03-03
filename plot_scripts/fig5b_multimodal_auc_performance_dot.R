library(ggplot2)
library(dplyr)
library(circlize)
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
  mutate(method=standardize_method_names(method)) %>%
  # Update the name of datasets
  mutate(dataset = str_remove(dataset, " \\+ Omics")) %>%
  # For performance plot, only retain biggest ncomp/factor
  filter(!str_detect(method, "-1"))


# Order methods by mean AUC across datasets
method_order <- df |>
  group_by(method, dataset) |>
  summarise(mean_auc = mean(auc), .groups = "drop") |>
  filter(dataset == "Electrical") |>
  arrange(desc(mean_auc)) |>
  pull(method)


# --- Plot ---

text_size = 40

out_plot <- df |>
  mutate(
    method  = factor(method, levels = rev(method_order))
    ) %>%  # rev so top = highest on y-axis) |>
  ggplot(aes(x = auc, y = method, shape = dataset)) +
  # Ceiling zone shading
  annotate("rect",
           xmin = 0.95, xmax = 1.005, ymin = -Inf, ymax = Inf,
           fill = "grey85", alpha = 0.5) +

  # Lollipop sticks from 0.5 to the dot
  geom_linerange(aes(xmin = 0.5, xmax = auc),
                 linewidth = 0.4, alpha = 0.3) +

  # Dots
  geom_point(size = 6, color=auc_color) +

  # Optional: value labels only for Electrical (most informative spread)
  geom_text(
    data = ~filter(.x, dataset == "Electrical"),
    aes(label = round(auc, 3)),
    nudge_y = 0.4, size = 7
  ) +
  scale_shape_manual(values = c(
    "Electrical" = 17,  # triangle
    "Imaging" = 18,  # diamond
    "Clinical" = 15),   # square,
    labels = c("Eletrical Omics", "Imaging Omics", "Clinical Omics")
  ) +
  scale_x_continuous(limits = c(0.5, 1.01),
                     breaks = seq(0.5, 1.0, 0.1)) +
  labs(
    x        = "AUC",
    y        = NULL
    #title    = "Multimodal integration performance",
    #subtitle = "Grey band marks ceiling zone (AUC > 0.95)"
  ) +
  theme_bw(base_size = text_size) +
  theme(
    strip.text         = element_text(face = "bold"),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_line(colour = "grey90")
  )



#library(patchwork)
# out_plot  <- p_bar / dot_plot +
#   plot_layout(heights = c(1, 4))


output_png_path <- "results/multimodal/fig5b_multimodal_auc_performance_dot.png"

the_plot <- get_legend_35(out_plot +
  ggtitle(NULL) +
  guides(shape=guide_legend(title=NULL,nrow=2))
  )

#the_plot %>% ggdraw()
ggsave("aaaa.png", the_plot, width=12, height=9, dpi=1200, units="in", bg="white")
#save_plot_both(out_plot, output_png_path, width=9, height=)

