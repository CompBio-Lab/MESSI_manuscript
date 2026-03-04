# Combined all plots from multimodal


src_scripts <- list.files("plot_scripts/", pattern = "fig5.*.R", full.names = T)
for (script in src_scripts) {
  source(script)
}


library(cowplot)

htx_auc <- readRDS("results/sc/fig6b1_sc_htx_auc_performance_bar_plot.rds")
covid_mul_auc <- readRDS("results/sc/fig6c1_sc_covid_multiomics_auc_performance_bar_plot.rds")
covid_org_auc <- readRDS("results/sc/fig6d1_sc_covid_organ_auc_performance_bar_plot.rds")
# Now read in the complexity ones
htx_complexity        <- readRDS("results/sc/fig6gh_sc_time_vs_space_complexity_htx_only.rds")
covid_mul_complexity  <- readRDS("results/sc/fig6i_sc_time_vs_space_complexity_covid_multiomics.rds")
covid_org_complexity  <- readRDS("results/sc/fig6j_sc_time_vs_space_complexity_covid_organ.rds")

# ================================================================================================
base_size <- 7

# Helper to make a ribbon title
ribbon_title <- function(bg_color = "#2c3e50") {
  theme(
    plot.title = ggtext::element_textbox_simple(
      size = 14, face = "bold", color = "white",
      fill = bg_color, padding = margin(5, 5, 5, 5),
      margin = margin(0, 0, 2, 0),
      halign = 0.5, width = unit(1, "npc"),
      r = unit(0, "pt")              # no rounded corners
    )
  )
}




# Panel plots
top_panel <- plot_grid(
  htx_auc + ylab(NULL) +
    xlab(NULL) +
    coord_cartesian(ylim = c(0, 1)) +
    theme_bw(base_size) +
    theme(legend.position = "none") +
    ggtitle("sc-HTX") +
    ribbon_title(),
  # Second plot
  covid_mul_auc + xlab(NULL) + #+ ylab(NULL)  +
    coord_cartesian(ylim = c(0, 1)) +
    theme_bw(base_size) +
    theme(legend.position = "none") +
    ggtitle("sc-COVID multiomics") +
    ribbon_title(),
  # Third plot
  covid_org_auc + xlab(NULL) + ylab(NULL) +
    coord_cartesian(ylim = c(0, 1)) +
    theme_bw(base_size) +
    theme(legend.position = "none") +
    ggtitle("sc-COVID organ") +
    ribbon_title(),
  align="v",
  nrow=3
)


bottom_panel <- plot_grid(
  htx_complexity + #ylab(NULL) + #+ ggtitle("HTX") +
    xlab(NULL) +
    theme_bw(base_size + 2) +
    theme(legend.position = "none"),

  covid_mul_complexity + ylab(NULL)  + #+ ggtitle("COVID-multimoics") +
    theme_bw(base_size + 2) +
    theme(legend.position = "none",
          axis.text.y = element_blank(),
          axis.ticks.y = element_blank()),
  covid_org_complexity + ylab(NULL) + #+ ggtitle("COVID-organ") +
    xlab(NULL) +
    theme_bw(base_size + 2) +
    theme(legend.position = "none",
          axis.text.y = element_blank(),
          axis.ticks.y = element_blank()),
  align="h",
  ncol=3
  #rel_heights = c(0.7, 0.3)
)

# ==============================================================================
# Now merge all
img_plot <- ggdraw() +
  draw_image("sc_design.png")

comp_plots <- plot_grid(
  top_panel,
  bottom_panel,
  nrow=2,
  align="h",
  labels=c("B", "C"),
  rel_heights = c(0.7, 0.3)
)

all_plot <- plot_grid(
  img_plot,
  comp_plots,
  nrow=2,
  rel_heights = c(0.45, 1),
  align="hv",
  labels=c("A", "")
)

ggsave("fig6_sc_data_performances.png", all_plot, bg="white",width=8, height=12)

