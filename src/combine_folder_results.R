library(data.table)

sim_dir <- "data/raw/old_bulk_filtered/"
cr_dir  <- "data/raw/rgcca_only/"

fs_df       <- rbind(fread(paste0(sim_dir, "all_feature_selection_results.csv")),
                     fread(paste0(cr_dir,  "all_feature_selection_results.csv")), fill = TRUE)

pred_df     <- rbind(fread(paste0(sim_dir, "all_langs-result.csv")),
                     fread(paste0(cr_dir,  "all_langs-result.csv")), fill = TRUE)

perf_df     <- rbind(fread(paste0(sim_dir, "metrics.csv")),
                     fread(paste0(cr_dir,  "metrics.csv")), fill = TRUE) |>
  arrange(method_name) |>
  distinct_all()

trace_df    <- rbind(fread(paste0(sim_dir, "execution_trace.txt")),
                     fread(paste0(cr_dir,  "execution_trace.txt")), fill = TRUE) |>
  distinct_all()

metadata_df <- rbind(fread(paste0(sim_dir, "parsed_metadata.csv")),
                     fread(paste0(cr_dir,  "parsed_metadata.csv")), fill = TRUE) |>
  distinct_all()

out_dir <- "data/raw/merged/"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

fwrite(fs_df,       paste0(out_dir, "all_feature_selection_results.csv"))
fwrite(pred_df,     paste0(out_dir, "all_langs-result.csv"))
fwrite(perf_df,     paste0(out_dir, "metrics.csv"))
fwrite(metadata_df, paste0(out_dir, "parsed_metadata.csv"))

# Tab-separated, no quoting
fwrite(trace_df, paste0(out_dir, "execution_trace.txt"), sep = "\t", quote = FALSE)

