trace_df <- readr::read_tsv(trace_path, col_types = readr::cols())


keep_relevant_process <- function(df) {
  df %>%
    # Keep those that belongs to feature selection or
    # cross validation only
    filter(
      str_detect(process, "^feature_selection:") |
      str_detect(process, "^cross_validation:")
    ) %>%
    # Also from cv, dont need downstream or merge result table part
    filter(
      !str_detect(process, "downstream|merge.*")
    )
}

expand_process_col <- function(df) {
  # Expand the process column based on the tag
  df %>%
    # Add a dummy column to identify pattern in the process
    mutate(pattern = case_when(
      str_detect(process, "feature_selection.*") ~ "fs",
      TRUE ~ "cv"
    )) %>%
    group_split(pattern) %>%
    map_dfr(function(group_df) {
      pattern <- unique(group_df$pattern)

      # Separate based on pattern
      if (pattern == "cv") {
        # When its cv should be
        # cross_validation:cv_language:method:method_action
        tidyr::separate_wider_delim(
          group_df, cols = process, delim = ":",
          names = c(NA, NA, "method", "method_action"))
      } else if (pattern == "fs") {
        # When its feature seecltion should be
        # feature_selection:method_select_feature
        tidyr::separate_wider_delim(group_df, cols = process, delim = ":",
                                    names = c(NA, "method_select_feature"))
      } else {
        message("This should not be executed")
      }
    }) %>%
    select(-c("pattern")) %>%
    tidyr::separate_wider_delim(
      method_action, delim = "_", names = c(NA, "action"), too_many = "merge"
    ) %>%
    tidyr::separate_wider_delim(
      method_select_feature, delim = "_", names = c("method_dummy", "select_feature"), too_many = "merge"
    )%>%
    mutate(
      action = case_when(
        !is.na(select_feature) ~ select_feature,
        TRUE ~ action),
      method = case_when(
        !is.na(method_dummy) ~ method_dummy,
        TRUE ~ method)
      ) %>%
    select(-c(select_feature, method_dummy))
}



kkk <- ddd %>%
  select(method:tag)





# First create the ncomp names
ncomp_based_meta_df <- kkk %>%
  filter(
    str_detect(method, "rgcca|diablo|sgcca") & action == "train"
  ) %>%
  mutate(
    ncomp = str_extract(tag, "ncomp_\\d+") |> str_remove("ncomp_") |> as.integer(),
    design = str_extract(tag, "design_(full|null)") %>% str_remove("design_")) %>%
  tidyr::separate_wider_delim(tag, delim="-", names = c("dataset", "fold", NA), too_many = "merge")

mofa_meta_df <- kkk %>%
  filter(method == "mofa", action == "preprocess") %>%
  mutate(
    tag = case_when(
      # For mofa change its num_factor_2 to ncomp
      str_detect(method, "mofa") ~ str_replace(tag, "num_factor", "ncomp"),
      TRUE ~ tag
    )
  ) %>%
  mutate(
    ncomp = str_extract(tag, "ncomp_\\d+") |> str_remove("ncomp_") |> as.integer()
  ) %>%
  tidyr::separate_wider_delim(tag, delim="-", names = c("dataset", NA), too_many="merge")




aside_meta <- bind_rows(ncomp_based_meta_df, mofa_meta_df)


common_preprocessing <- function(df) {
  workflow_prefix <- "NFCORE_MESSI_BENCHMARK:MESSI_BENCHMARK:"
  df  %>%
  # First remove workflow prefixes
  mutate(
    process = str_replace(process, workflow_prefix, "") |> tolower()
  ) %>%
  # Need to fix the cooperative learning name for regex matching later
  mutate(process = str_replace_all(process, "cooperative_learning", "multiview")) %>%
  # Second keep the cross validation workflows and select feature only
  keep_relevant_process() %>%
  # Third expand process into workflow/subworkflow/process action
  expand_process_col() %>%
  mutate(
    method = case_when(
      str_detect(tag, "sgcca") ~ "sgcca",
      str_detect(tag, "rgcca") ~ "rgcca",
      TRUE ~ method
    )
  ) %>%
  # For the tcga ones use _ to replace it
  mutate(
    tag = case_when(
      # Only replace the first - to _ for tcga
        str_detect(tag, "tcga") ~ str_replace(tag, "-", "_"),
        TRUE ~ tag
      )
  )
}

ddd <- trace_df %>%
  common_preprocessing()


sss <- ddd %>%
  select(method, action, tag) %>%
  tidyr::separate_wider_delim(tag, delim="-", names = c("dataset", "fold", NA),
                              too_many="merge", too_few = "align_start") %>%
  # Fix the fold column
  mutate(fold = case_when(
    action == "preprocess" ~ "empty",
    action == "train" ~ fold,
    action == "predict" ~ fold,
    action == "select_feature" ~ "empty",
    TRUE ~ NA
  ))  %>%
  left_join(aside_meta, by = c("method", "action", "dataset", "fold"), relationship = "many-to-many")

sss


# # Then mutate the method based on its ncomp and design
# sss %>%
#   mutate(
#     method = case_when(
#       !(is.na(ncomp) | !is.na(design)) ~ paste(method, "ncomp", ncomp, "design", design, sep="-"),
#       TRUE ~ method
#     )
#   )
#
#


wrangle_trace <- function(
    trace_df,
    workflow_prefix="NFCORE_MESSI_BENCHMARK:MESSI_BENCHMARK:",
    time_col="duration") {

  trace_df_pre <- trace_df %>%
    select(process, tag, realtime, duration) %>%
    mutate(
      process = str_replace(process, workflow_prefix, "") |> tolower()
    ) %>%
    # Need to fix the cooperative learning name for regex matching later
    mutate(process = str_replace_all(process, "cooperative_learning", "multiview")) %>%
    # Get the ones of select feature and cross validation only
    # Since there are other jobs like prepare metadata
    filter(
      str_detect(process, "^feature_selection:[^_]+_select_feature") |
        str_detect(process, "^cross_validation:")
    ) %>%
    filter(
      !str_detect(process, "downstream|merge_result_table")
    ) %>%
    # Then just replace long prefixes in front of the process
    mutate(
      process = str_replace(
        process,
        "^(feature_selection:|cross_validation:cv.*:)", "")
    ) %>%
    # Now split the <method>_<action> to more columns
    separate(process, into = c("method", "action"), sep = "_", extra = "merge") %>%
    # Now for diablo, check if tag contains null or full (which is its design)
    mutate(
      method = case_when(
        str_detect(method, "diablo") & str_detect(tag, "-(null|full)") ~ paste0(
          method, str_extract(tag, "-(null|full)")
        ),
        str_detect(method, "rgcca") & str_detect(tag, "-(null|full)") ~ paste0(
          method, str_extract(tag, "-(null|full)")
        ),
        str_detect(method, "mofa") ~ "mofa + glmnet",
        TRUE ~ method
      ),
      dataset = str_replace(tag, "-fold.*", ""),
      tag = str_replace(tag, "-(null|full)", "") # Clean up tag column
    ) %>%
    mutate(raw_seconds = sapply(!! sym( time_col ), toSeconds) |> as.numeric())
  # ============================================================================
  # Need to creat additional diablo rows given they shared same preprocess step
  diablo_null_copy <- trace_df_pre %>%
    filter(method == "diablo") %>%
    mutate(method = "diablo-null")

  diablo_full_copy <- trace_df_pre %>%
    filter(method == "diablo") %>%
    mutate(method = "diablo-full")

  # TODO: this might not be too readable?
  sgcca_copy <- trace_df_pre %>%
    filter(str_detect(method, "rgcca"),
           !str_detect(tag, "rgcca")) %>%
    mutate(method = paste0(method, " + lda")) %>%
    distinct(tag, action, .keep_all=TRUE)

  rgcca_copy <- trace_df_pre %>%
    filter(str_detect(method, "sgcca"),
           !str_detect(tag, "sgcca")) %>%
    mutate(method = paste0(method, " + lda")) %>%
    distinct(tag, action, .keep_all=TRUE)


  # And also need to handle those of rgcca vs sgcca

  # Lastly combine these anad output it
  output_df <- trace_df_pre %>%
    # This remove the diablo "preprocess" step, and add in from our aside copy
    filter(method != "diablo", method != "rgcca") %>%
    bind_rows(diablo_null_copy, diablo_full_copy, sgcca_copy)

  return(output_df)
}
