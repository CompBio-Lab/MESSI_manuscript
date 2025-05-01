library(dplyr)
library(tidyr)

source(here::here("src/fig_fgsea_analysis/_utils.R"))

all_results <- data.table::fread("data/processed/fgsea_part2_df.csv")


cutoff <- 0.2

# First filter those that match organ of study with the organ of celltype
filtered_results <- all_results %>%
  dplyr::mutate_if(is.character, tolower) %>%
  # Drop the kipan study
  filter(!str_detect(dataset, "kipan")) %>%
  add_manual_label() %>%
  # Now for each dataset only keep those where its organ is contained
  # in the annotated organ label
  filter(str_detect(organ_label, organ)) %>%
  group_by(method, dataset) %>%
  mutate(
    padj = p.adjust(pval, "BH"),
    cell_type = pathway,
    method_dataset = paste(method, dataset, sep="_")
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
    group_num = unique(group_num)
  ) %>%
  ungroup() %>%
  mutate(ratio = n / group_num) %>%
  pivot_wider(names_from = organ, values_from = ratio, values_fill=0)

# Lastly save this
data.table::fwrite(
  wide_n_sig_tab,
  file="data/processed/fgsea_part2_summary_df.csv")
