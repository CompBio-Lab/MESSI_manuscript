# --------
#
# --------
# load data
trace_path <- "data/raw/execution_trace.txt"
workflow_prefix="NFCORE_MESSI_BENCHMARK:MESSI_BENCHMARK:"
# Function to convert size strings to megabytes
convert_to_mb <- function(size_vec) {
  sizes <- as.numeric(stringr::str_extract(size_vec, "\\d+\\.?\\d*"))
  units <- stringr::str_extract(size_vec, "(KB|MB|GB)")

  # Convert sizes to megabytes based on the unit
  sizes * dplyr::case_when(
    units == "GB" ~ 1024,
    units == "MB" ~ 1,
    units == "KB" ~ 1 / 1024,
    TRUE ~ NA_real_
  )
}


dd <- readr::read_tsv(trace_path, col_types = readr::cols())


trace_df_pre <- dd |>
  select(process, tag, rss, peak_rss, peak_vmem) %>%
  mutate(raw_rss = convert_to_mb(rss),
         raw_peak_rss = convert_to_mb(peak_vmem)) %>%
  select(-rss, -peak_rss) %>%
  mutate(
    process = str_replace(process, workflow_prefix, "") |> tolower()
  ) %>%
  # Need to fix the cooperative learning name for regex matching later
  mutate(process = str_replace_all(process, "cooperative_learning", "multiview")) %>%
  mutate(process = strsplit(as.character(process), ":")) %>%
  unnest_wider(process, names_sep = "_") %>%
  mutate(process_combined = apply(select(., starts_with("process")), 1, function(x) last(na.omit(x)))) %>%
  dplyr::rename(process = process_combined) %>%
  select(process, tag, raw_rss, raw_peak_rss) %>%
  mutate(is_simulated = ifelse(str_detect(tag, "sim-data"), 1, 0)) %>%
  # Get the method from the process
  mutate(method = if_else(
    str_detect(process, "train|predict|downstream|preprocess|select_feature"),
    process,
    "other_method"
  ))
  # separate_wider_delim(process, delim = ":",
  #                      names = c("worfklow", "module"),
  #                      too_few = "align_start", too_many = "merge")
  # Get the ones of select feature and cross validation only
  # Since there are other jobs like prepare metadata
  # Then just replace long prefixes in front of the process
  # Now split the <method>_<action> to more columns
  #separate(process, into = c("method", "action"), sep = "_", extra = "merge") %>%
  # Now for diablo, check if tag contains null or full (which is its design)
  # mutate(
  #   method = case_when(
  #     str_detect(method, "diablo") & str_detect(tag, "-(null|full)") ~ paste0(
  #       method, str_extract(tag, "-(null|full)")
  #     ),
  #     str_detect(method, "mofa") ~ "mofa + glmnet",
  #     TRUE ~ method
  #   ),
  #   dataset = str_replace(tag, "-fold.*", ""),
  #   tag = str_replace(tag, "-(null|full)", "") # Clean up tag column
  # )

trace_df_pre$process %>%
  table() %>%
  enframe() %>%
  mutate(value = as.numeric(value)) %>%
  ggplot(aes(x=value, y=reorder(name, value))) +
  geom_bar(stat="identity") +
  labs(x = "Count", y = "Process") +
  theme_bw()


# trace_df_pre %>%
#   filter(!str_detect(process, "diablo")) %>%
#   filter(!str_detect(process, "rgcca")) %>%
#   ggplot(aes(x=log2(raw_peak_rss), y=reorder(process, -log2(raw_peak_rss)))) +
#   geom_bar(stat="identity") +
#   theme_bw()


# diablo_null_copy <- trace_df_pre %>%
#   filter(method == "diablo") %>%
#   mutate(method = "diablo-null")
#
#
#
#
# diablo_full_copy <- trace_df_pre %>%
#   filter(method == "diablo") %>%
#   mutate(method = "diablo-full")

# TODO: this might not be too readable?
sgcca_copy <- trace_df_pre %>%
  filter(method == "rgcca",
         !str_detect(tag, "rgcca")) %>%
  mutate(method = "sgcca + lda") %>%
  distinct(tag, action, .keep_all=TRUE)


# And also need to handle those of rgcca vs sgcca

# Lastly combine these anad output it
output_df <- trace_df_pre %>%
  # This remove the diablo "preprocess" step, and add in from our aside copy
  filter(method != "diablo", method != "rgcca") %>%
  bind_rows(diablo_null_copy, diablo_full_copy, sgcca_copy)

output_df

# =================
new_dd <- read.csv("sssf/ccle_vs_gdsc/train/clin.csv") |>
  as_tibble()


new_dd$




