library(ggplot2)
library(tidytext)

width <- 10
height <- 8
palette <- "Paired"

combined_summary <- fread("data/processed/fgsea_part1_summary_df.csv")



significant_pathways_method_gs_plot_obj <- combined_summary %>%
  # And reorder it for plotting
  dplyr::mutate(label_reordered = reorder_within(method, mean_n_sig, gs_collection_name)) %>%
  ggplot(aes(x = label_reordered, y = mean_n_sig, fill = method)) +
  geom_errorbar(aes(ymin = mean_n_sig, ymax = mean_n_sig + sd_n_sig),
                width = 0.2, position = position_dodge(0.9)) +
  geom_bar(stat = "identity") +
  facet_wrap(~ gs_collection_name, scales = "free") +
  labs(x = "Method", y = "Mean # Significant Pathways",
       title = "Significant Pathways by Method and Gene Set Collection") +
  theme_bw() +
  tidytext::scale_x_reordered() +
  scale_y_log10(expand = expansion(mult = c(0, 0.1))) +
  coord_flip() +
  scale_fill_brewer(palette = palette) +
  theme(
    plot.title = element_text(hjust = 0.5),
    panel.grid.major.y = element_blank()
  )


ggsave(
  filename = "results/figures/fig_fgsea_panel_a.png",
  plot = significant_pathways_method_gs_plot_obj,
  width = width,
  height = height
  )

saveRDS(significant_pathways_method_gs_plot_obj,
        file = "data/processed/fig_fgsea_panel_a_plot_data.rds")


# =====================================
# Then in a summarized way, on average for each method

# ==============================================
# THIS IS C2

#
# c2_summarized_n_sig_plot <- c2_summarized_method %>%
#   ggplot(
#     aes(x = reorder(method, -mean_n_sig),
#         y = mean_n_sig,
#         fill = method)
#   ) +
#   geom_errorbar(aes(
#     ymin = mean_n_sig, ymax = mean_n_sig + sd_n_sig, width = 0.6)
#   ) +
#   geom_bar(stat = "identity") +
#   labs(x = "Method", y = "Mean Number of Pathways per Dataset",
#        title = "Mean Number of Pathways Detected per Method") +
#   theme_bw() +
#   scale_y_log10() +
#   theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#   scale_fill_brewer(palette = palette)
#
# c2_summarized_n_sig_plot
#
#
#
# ggsave("c2_summarized_n_sig.png",
#        plot = c2_summarized_n_sig_plot,
#        width=width, height=height)
#
# # =================================================
# # THIS IS C6
#
# c6_summarized_n_sig_plot <- c6_summarized_method %>%
#   ggplot(
#     aes(x = reorder(method, -mean_n_sig),
#         y = mean_n_sig,
#         fill = method)
#   ) +
#
#   geom_errorbar(aes(ymin = mean_n_sig, ymax = mean_n_sig + sd_n_sig, width=0.6)) +
#   geom_bar(stat = "identity") +
#
#
#   labs(x = "Method", y = "Mean Number of Pathways per Dataset",
#        title = "Mean Number of Pathways Detected per Method") +
#   theme_bw() +
#   scale_y_log10() +
#   theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#   scale_fill_brewer(palette = palette)
#
# c6_summarized_n_sig_plot
#
# ggsave("c6_summarized_n_sig.png",
#        plot = c6_summarized_n_sig_plot,
#        width=width, height=height)
