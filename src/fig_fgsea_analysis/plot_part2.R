library(data.table)
library(ComplexHeatmap)
library(ggplot2)
library(circlize)
library(cowplot)

# Load other utilities
source(here::here("src/fig_fgsea_analysis/_utils.R"))

# Custom function for plotting

get_text_color <- function(fill_color) {
  rgb <- col2rgb(fill_color)
  luminance <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) / 255
  ifelse(luminance < 0.5, "white", "black")
}


wide_n_sig_tab <- fread("data/processed/fgsea_part2_summary_df.csv")
wide_n_sig_mat <- wide_n_sig_tab %>%
  dplyr::select(-c("method", "dataset", "n", "group_num")) %>%
  as.matrix()
# All methods labels


methods <- wide_n_sig_tab$method |> unique() |> sort()

# Get a pastel color palette with the same number of colors as your methods
n_methods <- length(methods)
# RColorBrewer's Pastel1 has up to 9 colors; use Pastel2 if you need more variation
pastel_colors <- RColorBrewer::brewer.pal(n = n_methods, name = "Paired")

# Create a named vector of colors for each method
method_colors <- setNames(pastel_colors, methods)

# =========================================================
# Then the annotations here
row_ha <- rowAnnotation(
  Method = factor(
    wide_n_sig_tab$method,
    levels = unique(wide_n_sig_tab$method)
    ),
  col = list(Method = method_colors),
  annotation_legend_param = list(
    Method = list(
      #title_gp = gpar(fontsize = 16),
      #labels_gp = gpar(fontsize = 8),
      nrow=2
    )
  ),
  show_annotation_name = FALSE
  #Dataset = factor(wide_n_sig_tab$dataset, levels = unique(wide_n_sig_tab$dataset))
)

col_ha <- columnAnnotation(
  Organ = factor(wide_n_sig_tab[5:ncol(wide_n_sig_tab)] %>%
                   colnames()),
  show_annotation_name = FALSE
)

# Add number into the heatmap to show the actual ratio
# Function of color
col_fun <- colorRamp2(c(0, 0.5, 1), c("white", "steelblue1", "blue"))
#col_fun <- colorRamp2(c(0, 0.5, 1), c("white", "gainsboro", "lightgrey"))
# Leave this as is, if not then go back to patchy problem
# Y-axis to actual name of the dataset
# Add own labelling vector to "link" dataset, since
# they could be colated
# Row split could be customized
htmp <- Heatmap(
  wide_n_sig_mat,
  name = "Proportion of significant cells",
  col = col_fun,
  right_annotation = row_ha,
  row_split = wide_n_sig_tab$dataset %>% map_name(),
  cluster_rows = TRUE,
  #column_split = wide_n_sig_tab$method,
  border = TRUE,
  row_title_rot = 0,
  row_gap = unit(2, "mm"),
  column_names_rot = 45,
  row_names_gp = gpar(fontsize = 10),
  row_title_gp = gpar(fontsize = 10),
  show_row_names = FALSE,
  cluster_columns = TRUE,
  #cluster_rows = FALSE,
  row_dend_width = unit(1.5, "cm"),
  cell_fun = function(j, i, x, y, width, height, fill) {
    text_color <- get_text_color(fill)
    grid.text(sprintf("%.2f", wide_n_sig_mat[i, j]), x, y,
              gp = gpar(col = text_color, fontsize = 10))
  },
  # Assign legend
  heatmap_legend_param = list(
    at = c(0, 0.5, 1),
    labels = c("Low", "", "High"),
    grid_height = unit(0.3, "cm"), grid_width = unit(0.3, "cm"),
    legend_width = unit(5, "cm"),
    #labels_gp = gpar(fontsize = text_size - 5),
    legend_direction = "horizontal"
    #legend_direction = "vertical"
  ),

)

# And its frequency plot
annot_bar_plot <- wide_n_sig_tab$method %>%
  table() %>%
  enframe(name="method", value="n") %>%
  mutate(n = as.integer(n)) %>%
  ggplot(aes(x=reorder(method, n), y=n, fill=method)) +
  geom_bar(stat="identity", width=0.7) +
  labs(x="Method", y="Frequency", fill="Method")+
  scale_fill_manual(values = method_colors) +
  theme_bw() +
  # And remove horizontal lines
  theme(
    panel.grid.major.y = element_blank()
  ) +
  coord_flip()


# Draw heatmap and convert to grob
ht_grob <- grid.grabExpr(
  #draw(ht, heatmap_legend_side="bottom", annotation_legend_side="right",
  #     legend_grouping = "original")
  draw(htmp, merge_legends = TRUE,
       heatmap_legend_side = "bottom",
       annotation_legend_side = "bottom")
  )


htmp

# And combine them together
output_plot <- plot_grid(
  ggdraw() +
    ggdraw() +
    draw_grob(ht_grob, x = 0.5, y = 0.5, width = 1, height = 1,
              hjust = 0.5, vjust = 0.5),
  annot_bar_plot +
    xlab(NULL) +
    guides(fill="none"),
  ncol = 2,
  rel_widths = c(2, 1)
)

ggsave("results/figures/fig_fgsea_panelB.png", plot=output_plot, width=12, height=9)


saveRDS(output_plot, "data/processed/fig_fgsea_panel_b_plot_data.rds")


