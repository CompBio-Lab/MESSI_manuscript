all_results <- data.table::fread("data/processed/fgsea_part1_df.csv")
cutoff <- 0.2


combined_summary <- all_results %>%
  filter(padj < cutoff) %>%
  group_by(method, dataset, gs_collection_name) %>%
  summarize(n_sig = n(), .groups = "drop") %>%
  group_by(method, gs_collection_name) %>%
  summarize(mean_n_sig = mean(n_sig),
            sd_n_sig = sd(n_sig),
            .groups = "drop")

data.table::fwrite(combined_summary, file="data/processed/fgsea_part1_summary_df.csv")





# ============================================
