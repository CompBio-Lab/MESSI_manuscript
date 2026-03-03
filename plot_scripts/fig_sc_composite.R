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
complexity <- readRDS("results/sc/fig6k_sc_time_vs_space_complexity_faceted_study_action.rds")
# And the biological ones
htx_biol <- readRDS("results/sc/fig6o_sc_htx_pathways.rds")
covid_mul_biol <- readRDS("results/sc/fig6n_sc_covid_multiomics_pathways.rds")
covid_org_biol <- readRDS("results/sc/fig6m_sc_covid_organ_pathways.rds")
# ================================================================================================
base_size <- 7

# Helper to make a ribbon title
ribbon_title <- function(bg_color = "#2c3e50") {
  theme(
    plot.title = ggtext::element_textbox_simple(
      size = base_size+1, face = "bold", color = "white",
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
    coord_flip() +
    #coord_cartesian(ylim = c(0, 1)) +
    theme_bw(base_size) +
    theme(legend.position = "none") +
    ggtitle("sc-HTX") +
    ribbon_title(),
  # Second plot
  covid_mul_auc + xlab(NULL) + #+ ylab(NULL)  +
    xlab(NULL) +
    coord_flip() +
    #coord_cartesian(ylim = c(0, 1)) +
    theme_bw(base_size) +
    theme(legend.position = "none") +
    ylab("AUC") +
    ggtitle("sc-COVID multiomics") +
    ribbon_title(),
  # Third plot
  covid_org_auc + xlab(NULL) + ylab(NULL) +
    xlab(NULL) +
    coord_flip() +
    #coord_cartesian(ylim = c(0, 1)) +
    theme_bw(base_size) +
    theme(legend.position = "none") +
    ggtitle("sc-COVID organ") +
    ribbon_title(),
  align="v",
  nrow=3,
  rel_heights = c(0.3, 0.3, 0.3)
)



covid_panel <- plot_grid(
  covid_org_biol + theme_bw(base_size = base_size) + theme(legend.position = "none"),
  covid_mul_biol + theme_bw(base_size = base_size) + theme(
    legend.position = "bottom",
    legend.margin = margin(t = 0, r = 50, b = 0, l = 0)
    ) +
    guides(
    fill=guide_legend(nrow=4)
  ),
  nrow=2,
  labels=c("D", "E")
)



biol_panel <- plot_grid(
  htx_biol + theme_bw(base_size=base_size) +
    theme(axis.text.x = element_text(angle=90, hjust=1)) +
    xlab("Celltype"),
  covid_panel,
  ncol=2,
  labels=c("C", "")
)



top_top <- plot_grid(
  top_panel,
  biol_panel,
  ncol=2,
  rel_widths = c(0.6, 1.5)
)



# ==============================================================================
# Now merge all
img_plot <- ggdraw() +
  draw_image("sc_design.png")

comp_plots <- plot_grid(
  top_top,
  complexity + theme_bw(base_size = base_size) + theme(legend.position="none"),
  nrow=2,
  axis="b",
  align="h",
  labels=c("B", "F"),
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

