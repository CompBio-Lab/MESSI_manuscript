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



# Load the plot data for fig simulated panel AB, auc panel and
# sensitivity  + specicificy panel
simulated_panel_AB_plot_data <- readRDS(
  here::here("data/processed/simulated/simulated_panel_AB_plot_data.rds")
)

plot_simulated_panel_AB <- function(plot_data, text_size=9.5) {
  # First create the independent panels
  auc_panel <- create_panel_plot(
    data = simulated_panel_AB_plot_data,
    metric_filter = "auc",
    metric_label = "AUC",
    y_label_expr = "AUC",
    text_size = text_size + 4
  ) +
    coord_flip()

  sensitivity_panel <- create_panel_plot(
    data = simulated_panel_AB_plot_data,
    metric_filter = "sensitivity",
    metric_label = "True Variables",
    #y_label_expr = expression("Proportion of TP^* / TP^* + FN^*")
    #y_label_expr = expression("Proportion of " * TP^"*" / (TP^"*" + FN^"*"))
    y_label_expr = "Proportion of variables selected",
    text_size = text_size + 3
  ) +
    coord_flip()

  specificity_panel <- create_panel_plot(
    data = simulated_panel_AB_plot_data,
    metric_filter = "specificity",
    metric_label = "Noise Variables",
    #y_label_expr = "Proportion of TN^* / TN^* + FP^*"
    #y_label_expr = expression("Proportion of " * TN^"*" / (TN^"*" + FP^"*"))
    y_label_expr = "Proportion of variables selected",
    text_size = text_size + 3
  ) +
    coord_flip()
  # ==========================================================
  # Merging the panels together
  # First make the bottom row with patchwork
  # Using cowplot is extremely hard due to alignment problems
  library(patchwork)
  bottom_row <- (sensitivity_panel + theme_empty_legend_ticks() + xlab(NULL)) /
    (specificity_panel +
       xlab(NULL))+
    plot_layout(axes = "collect")
}


computation_usage_plot <- combined_df %>%
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
  scale_fill_manual(values=method_family_colors,
                    labels=combined_df$method|> unique() |> sort()) +
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
  theme_bw() +
  theme(legend.position = "none",
        axis.text.x = element_text(angle=45, hjust=1))

computation_usage_plot

# This is empty space ratio
panel_space <- 0.025
# Now stack top and bottom rows
top_plot <- cowplot::plot_grid(
  auc_panel +
    xlab(NULL) +
    theme(
      legend.position = "none",
      #axis.text.x = element_blank()
    ),
  #NULL, # spacer
  bottom_row,
  nrow = 2,
  rel_heights = c(0.9, 1.5),
  align="v",
  axis="lr",
  labels = c("A", "B"),
  label_size=text_size * 2.5
)

# Output plot
out_plot <- plot_grid(
  top_plot,
  computation_usage_plot + theme_bw(base_size=text_size+2) +
    theme(axis.text.x = element_blank(),
          axis.ticks.x = element_blank(),
          panel.grid.major.x = element_blank(),
          legend.margin = margin(b=60, r=20),
          ) +
    xlab(NULL) +
    labs(fill="Method"),
  nrow = 2,
  labels = c("", "C"),
  label_size = text_size * 2.5,
  vjust = -4,
  rel_heights = c(1.5, 0.3)
)




#ggsave("fig3_simulated_data_performances.png", out_plot, width=8, height=10, bg="white")
ggsave("fig3_simulated_data_performances.pdf", out_plot, width=12, height=14,
       bg="white", dpi=1200)
