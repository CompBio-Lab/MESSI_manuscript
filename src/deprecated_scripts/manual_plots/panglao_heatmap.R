# Figure 4 Bulk Enrichment signif pathways by method and gene set collection
library(ComplexHeatmap)
library(ggplot2)
library(circlize)
library(cowplot)
library(dplyr)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
# Load common util
source(here::here("src/common_helpers/map_disease_name.R"))
source(here::here("plot_scripts/fgsea_utils.R"))
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))





df <- data.table::fread("data/processed/bulk/bulk_panglao_fgsea.csv")
panglao_pathways <- readRDS("data/processed/pathways_db/panglao_pathways_collection.rds")
# Now combine the pathways collection name into one df
bulk_panglao_df <- inner_join(
  df, panglao_pathways,
  by = c("pathway" = "gs_name")
) %>%
  # Then in this one, need to readjust the pval later, so
  # rename its existing padj to another name
  dplyr::rename(old_padj = padj) %>%
  tidyr::separate_wider_delim(
    group, delim = " | ",
    names = c("method", "dataset", "view"),
    too_many = "merge", too_few = "align_start"
  ) %>%
  # Drop extra dataset
  #filter(!(dataset %in% c("tcga-chol", "tcga-kipan"))) %>%
  group_by(method, dataset, view) %>%
  mutate(padj = p.adjust(pval, method="BH"))

# Should use a common cutoff
cutoff <- 0.2
message("\nUsing cutoff of: ", cutoff)

# First filter those that match organ of study with the organ of celltype
filtered_results <- bulk_panglao_df %>%
  # Make everything lowercase first
  mutate(across(where(is.character), tolower)) %>%
  # Drop unwanted dataset early
  filter(!str_detect(dataset, "kipan")) %>%
  add_manual_label() %>%
  # Clean up method names
  mutate(
    method = method |>
      str_replace("-ncomp", "_ncomp") |>
      str_replace("-factor", "-Factor")
  ) %>%
  # Capitalize or to upper the method names
  mutate(method = standardize_method_names(method)) %>%
  # Filter rows where organ matches label
  filter(str_detect(organ_label, organ)) %>%
  # Add columns in one mutate block
  group_by(method, dataset) %>%
  mutate(
    padj = p.adjust(pval, method="BH"),
    cell_type = pathway,
    method_dataset = paste(method, dataset, sep = "_")
  ) %>%
  ungroup()


# Then make this wider data
wide_n_sig_tab <- filtered_results %>%
  filter(!organ == "immune-system") %>%
  group_by(method, dataset, organ) %>%
  mutate(group_num = n()) %>%
  filter(padj < cutoff) %>%
  summarize(
    n = n(),
    group_num = unique(group_num),
    .groups = "drop"
  ) %>%
  ungroup() %>%
  mutate(ratio = n / group_num) %>%
  pivot_wider(names_from = organ, values_from = ratio, values_fill=0)


  # Param of the cutoff
  pval <- 0.2
  # =========================================================
  # UGGLY FIX HER

  #text_size=8 # 24
  text_size <- 19
  annotation_table <- wide_n_sig_tab %>%
    mutate(color_label = str_remove(method, "-.*") |> toupper()) %>%
    mutate(color_label = case_when(
      color_label == "CARET_MULTIMODAL" ~ "CARET",
      TRUE ~ color_label
    )) %>%
    mutate(dataset = map_disease_name(tolower(dataset)))

  #nnotation_table$dataset

  # =========================================================
  # Then the annotations here
  row_ha <- rowAnnotation(
    Method = factor(
      annotation_table$color_label,
      levels = names(method_family_colors)  # ensure order and completeness
    ),
    col = list(Method = method_family_colors),
    annotation_legend_param = list(
      Method = list(
        labels_gp = gpar(fontsize = text_size - 1.5),
        title_gp = gpar(fontsize=  text_size - 1.5, fontface="bold"),
        nrow=4
      )
    ),
    show_annotation_name = FALSE,
    show_legend=FALSE

  )



  col_ha <- columnAnnotation(
    # First 4 columns are "method", "dataset", "n", "group_num", so that's why
    # start from 5
    Organ = factor(annotation_table[5:ncol(annotation_table)] %>%
                     colnames()),
    annotation_legend_param = list(
      Organ = list(
        title_gp = gpar(fontsize = text_size - 1.5),
        labels_gp = gpar(fontsize = text_size - 1.5)
      )
    ),
    show_annotation_name = FALSE
  )
  plot_matrix <- wide_n_sig_tab %>%
    dplyr::select(-c("method", "dataset", "n", "group_num")) %>%
    as.matrix()

  # plot_matrix |>
  #   saveRDS("plot_matrix.rds")
  # Get the disease name of dataset from the src/common_helpers/map_disease_name.R
  #mapped_disease_name <- tolower(annotation_table$dataset) %>% map_disease_name()
  mapped_disease_name <- annotation_table$dataset


  #plot_matrix <- plot_matrix[, c(1,2,5,4,3,6)]
  # 2. Define the row split level order to match columns top-to-bottom
  # Map each disease to its "primary" organ so the diagonal emerges


  mapped_disease_name <- factor(mapped_disease_name, levels=c(
    "Skin Cancer",
    "Bile Duct Cancer",
    "Kidney Cancer (kirc)",
    "Kidney Cancer (kich)",
    "Pleura Cancer",
    "Bladder Cancer (GSE)",
    "Autism",
    "Thyroid Cancer"))


  colnames(plot_matrix) <- colnames(plot_matrix) |> tools::toTitleCase()
  col_fun <- colorRamp2(c(0, 0.5, 1), c("white", "steelblue1", "blue"))
  # 1. Define column order matching disease-to-organ mapping
  #col_order <- c("Skin", "Liver", "Kidney", "Lungs", "Brain", "Thyroid")
  #col_order <- c("Skin", "Kidney", "Lungs", "Brain", "Liver", "Thyroid")
  col_order <- c("Skin",  "Lungs", "Brain", "Kidney", "Liver", "Thyroid")
  plot_matrix <- plot_matrix[, col_order]

  set.seed(1) # use a seed to let cluster rows from row split be consitent
  htmp <- Heatmap(
    plot_matrix,
    name = "Proportion of significant cells",
    col = col_fun,
    right_annotation = row_ha,
    # This map_name is custom function found in _utils.R of the same dir
    row_split = mapped_disease_name,
    cluster_rows = TRUE,
    #row_split = row_split_factor,
    cluster_row_slices = TRUE,   # respect the factor level order
    cluster_columns = FALSE,
    #column_order = match(col_order, colnames(plot_matrix)),
    #column_split = annotation_table$method,
    border = TRUE,
    row_title_rot = 0,
    row_gap = unit(1, "mm"),
    column_names_rot = 45,
    row_title_gp = gpar(fontsize = text_size + 10),
    column_names_gp = gpar(fontsize = text_size + 10),
    row_names_gp = gpar(fontsize = text_size + 10),
    show_row_names = FALSE,
    show_column_dend = FALSE,
    #cluster_rows = FALSE,
    row_dend_width = unit(1.5, "cm"),
    use_raster = TRUE,
    raster_quality = 5,
    cell_fun = function(j, i, x, y, width, height, fill) {
      #text_color <- get_text_color(fill)
      #grid.text(sprintf("%.2f", plot_matrix[i, j]), x, y,
      #          gp = gpar(col = text_color, fontsize = 10))
      value <- plot_matrix[i, j]

      # If value is 0, override fill to light grey and don't draw text
      if (value == 0) {
        grid.rect(x, y, width, height, gp = gpar(fill = "grey90", col = NA))
      } else {
        # Draw the text for non-zero values
        text_color <- get_text_color(fill)
        grid.text(sprintf("%.2f", value), x, y,
                  gp = gpar(col = text_color, fontsize = text_size + 4))
      }
    },
    # Assign legend
    heatmap_legend_param = list(
      at = c(0, 0.5, 1),
      labels = c("Low", "", "High"),
      #title = bquote(bold("Proportion of significant cells at ") * italic("p") < .(pval)),
      #grid_height = unit(0.3, "cm"), grid_width = unit(0.3, "cm"),
      #legend_width = unit(5, "cm"),
      #labels_gp = gpar(fontsize = text_size - 5),
      #title = bquote("Proportion of significant cells at " * italic("p") < .(pval)),
      grid_height = unit(1.25, "cm"), grid_width = unit(1.25, "cm"),
      legend_width = unit(18, "cm"),
      labels_gp = gpar(fontsize = text_size + 8),
      title_gp = gpar(fontsize=  text_size + 8, fontface="bold"),
      legend_direction = "horizontal"
      #legend_direction = "vertical"
    ),

  )

  htmp
  # Draw heatmap and convert to grob
  #ht_opt(legend_gap = unit(3, "cm"))  # gap between legend and heatmap
  out_plot <- grid.grabExpr(
    draw(htmp, merge_legends = TRUE,
         show_heatmap_legend = TRUE,
         heatmap_legend_side = "bottom",
         #legend_gap = unit(10, "cm"),
         padding = unit(c(5, 5, 10, 5), "cm"),  # bottom, left, top, right
         annotation_legend_side = "bottom"
    )
  )

  #ggdraw(out_plot)
  ggsave("aaa.svg", out_plot, width=16, height=24,dpi=1200)
