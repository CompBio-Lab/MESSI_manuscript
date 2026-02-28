library(ggplot2)
library(dplyr)
#library(ggtext)

source("src/common_helpers/save_plot_both.R")
source("src/common_helpers/plot_utils.R")
source("src/common_helpers/standardize_data_funs.R")

# --- Data ---
df <- data.table::fread("data/raw/sc_data/htx_data/metrics.csv") |>
      dplyr::rename(method = method_name) |>
      mutate(
        dataset = str_replace_all(dataset, "_", " + ") |>
          tools::toTitleCase()
        ) |>
      dplyr::select(method, dataset, auc) %>%
      #standardize_method_names2() %>%
      mutate(color_label = str_remove(method, "-.*") |> toupper()) %>%
      mutate(color_label = case_when(
        color_label == "CARET_MULTIMODAL" ~ "CARET",
        TRUE ~ color_label)
      ) %>%
      standardize_method_names2() %>%
      filter(!str_detect(method, "-1"))



out_plot <- df %>%
  ggplot(aes(x=reorder(method, -auc), y=auc, fill=color_label)) +
  geom_bar(stat="identity", width=0.7) +
  theme_bw() +
  geom_hline(yintercept=0.5, linetype="dashed", linewidth=1.5, color="red") +
  scale_y_continuous(expand=expansion(mult = c(0, 0.12))) +
  scale_fill_manual(values=method_family_colors) +
  #coord_flip() +
  theme(
      plot.title         = element_text(hjust = 0.5),
      strip.background   = element_rect(fill = "grey95", color = "grey70"),
      strip.text         = element_text(face = "bold", size = 11),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      legend.position    = "bottom"
  ) +
  ggtitle("Performance Evaluation of scHTX data only") +
  labs(
    x="Method", y="Mean AUC (5-fold CV)"
  )


output_png_path <- "results/sc/fig6b1_sc_htx_auc_performance_bar_plot.png"
save_plot_both(out_plot, output_png_path, width=12, height=8)


