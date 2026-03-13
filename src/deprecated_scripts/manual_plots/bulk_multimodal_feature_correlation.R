library(ComplexHeatmap)
library(circlize)
library(dplyr)
library(ggplot2)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source("src/common_helpers/save_plot_both.R")

# Load bulk feat
bulk_feat_df <- data.table::fread("data/raw/bulk_data/all_feature_selection_results.csv")
# Load multimodal feat
multimodal_feat_df <- data.table::fread("data/raw/multimodal_data/all_feature_selection_results.csv")
# Rbind the both and remove unnecessary columns
combined_df <- bind_rows(bulk_feat_df, multimodal_feat_df) |>
  dplyr::select(-feature_type, -dataset_type) |>
  dplyr::rename(dataset = dataset_name) |>
  # Skip standardize method names here, do it at the very end
  standardize_view_names()

#top_k <- 30

# Then from here filter to get top K = 30 features
sorted_top_k_df <- combined_df %>%
  # Drop the unwanted datasets
  filter(!tolower(dataset) %in% c("tcga-chol", "tcga-kipan")) %>%
  mutate(feature = case_when(
    # For integrao and mogonet ones add the view in front
    method == "mogonet" | method == "integrao" ~ paste0(view, "_", feature),
    TRUE ~ feature
  )) %>%
  mutate(abs_coef = abs(coef))
#group_by(method, dataset) %>%
#arrange(desc(abs_coef), .by_group = T) %>%
#slice_head(n=top_k) %>%
#mutate(method = standardize_method_names(method))


cor_mats <- sorted_top_k_df %>%
  group_by(dataset) %>%
  group_map(~ {
    wide <- .x %>%
      ungroup() %>%
      dplyr::select(feature, method, abs_coef) %>%
      tidyr::pivot_wider(names_from = method, values_from = abs_coef, values_fill = 0)
    mat <- as.matrix(wide[, -1])  # drop feature column
    message("\ndataset is: ", .y, " number of features: ", nrow(wide))
    # Lastly compute cor mat
    cor(mat, method = "spearman")
  }, .keep = TRUE)

mean_cor <- Reduce(`+`, cor_mats) / length(cor_mats) |> round(3)
# And lastly fix namings of colnames and rownames
rownames(mean_cor) <- rownames(mean_cor) |> standardize_method_names()
colnames(mean_cor) <- colnames(mean_cor) |> standardize_method_names()



cor_mat <- mean_cor
# Assuming your matrix is called `cor_mat`
# Mask the diagonal
diag(cor_mat) <- NA

# Color mapping — diverging palette centered at 0
col_fun <- colorRamp2(c(-0.1, 0, 0.25, 0.5), c("#2166AC", "white", "#FDDBC7", "#B2182B"))

text_size <- 26

#cor_mat[upper.tri(cor_mat, diag = TRUE)] <- NA
ht <- Heatmap(cor_mat,
        name = "Mean Spearman Correlation",
        col = col_fun,
        na_col = "grey90",            # diagonal cells
        cluster_rows = TRUE,
        cluster_columns = TRUE,
        row_dend_side = "left",
        column_dend_side = "top",
        row_dend_width = unit(2, "cm"),   # default is ~1cm
        column_dend_height = unit(2, "cm"),
        row_names_gp = gpar(fontsize = text_size),
        column_names_gp = gpar(fontsize = text_size),
        rect_gp = gpar(col = "white", lwd = 1),
        cell_fun = function(j, i, x, y, width, height, fill) {
          v <- cor_mat[i, j]
          if (!is.na(v)) {
            # Convert fill color to perceived brightness
            rgb_vals <- col2rgb(fill) / 255
            luminance <- 0.299 * rgb_vals[1] + 0.587 * rgb_vals[2] + 0.114 * rgb_vals[3]
            text_col <- ifelse(luminance < 0.5, "white", "black")
            grid.text(sprintf("%.2f", v), x, y,
                      gp = gpar(fontsize = text_size - 4 , col = text_col))
          }
        },
        heatmap_legend_param = list(
          title_gp = gpar(fontsize = text_size, fontface = "bold"),  # legend title
          labels_gp = gpar(fontsize = text_size-2),                    # legend labels
          legend_height = unit(8, "cm"),
          title_position = "lefttop-rot",
          grid_height = unit(2, "cm"), grid_width = unit(2, "cm"),
          legend_width = unit(18, "cm")# size of legend keys
        ),
        column_names_rot = 90
        )

out_plot <- grid.grabExpr(
  draw(ht, merge_legends = TRUE,
       #show_heatmap_legend = TRUE,
       show_heatmap_legend = FALSE,
       heatmap_legend_side = "left",
       align_heatmap_legend = "heatmap_top",
       padding = unit(c(50, 5, 5, 25), "mm")  # bottom, left, top, right
  )
)

the_plot <- out_plot

ggsave("aaa.svg", the_plot, width=18, height=18, dpi=1200, units="in")

#ggsave("aaa.png", out_plot,width=18, height=12,dpi=1200)

