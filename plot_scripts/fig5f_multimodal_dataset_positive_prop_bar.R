library(ggplot2)
library(dplyr)
#library(ggtext)

source("src/common_helpers/save_plot_both.R")
source("src/common_helpers/plot_utils.R")


pos_prop <- data.table::fread("data/raw/multimodal_data/parsed_metadata.csv") |>
  dplyr::select(dataset_name, positive_prop) |>
  dplyr::rename(dataset = dataset_name, prop = positive_prop) |>
  dplyr::mutate(
    dataset = str_remove(dataset, "_processed") |>
      str_replace_all("_", " + ") |>
      tools::toTitleCase()
  )


out_plot <- ggplot(
  pos_prop,
  aes(x = reorder(dataset, -prop), y = prop)) +
  geom_col(width = 0.6, fill=auc_color) +
  geom_text(aes(label = round(prop, 2)),
            vjust = -0.4, size = 3) +
  scale_y_continuous(limits = c(0, 0.8),
                     labels = scales::label_percent()) +
  labs(x = NULL, y = "P(Y = 1)", title = "Positive proportion") +
  theme_bw(base_size = 10) +
  theme(
    axis.text.x  = element_text(angle = 30, hjust = 1),
    panel.grid   = element_blank(),
    plot.title   = element_text(size = 9, face = "bold")
  )



output_png_path <- "results/multimodal/fig5f_multimodal_dataset_positive_prop_bar.png"
save_plot_both(out_plot, output_png_path, width=12, height=8)

