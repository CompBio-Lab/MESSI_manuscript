library(data.table)
library(dplyr)

# Original path
old_path <- "data/raw/old_bulk/"

# New path
new_path <- "data/raw/old_bulk_filtered"

# Create folder if it doesn't exist
dir.create(new_path, recursive = TRUE, showWarnings = FALSE)

files <- list.files(old_path, full.names = TRUE)
# Method name here
met <- "gcca"
# Read + filter
feat_df <- fread(files[1]) %>%
  filter(!stringr::str_detect(method, met))

pred_df <- fread(files[2]) %>%
  filter(!stringr::str_detect(method_name, met))

trace_df <- fread(files[3]) %>%
  filter(!stringr::str_detect(process, toupper(met)))

metric_df <- fread(files[4]) %>%
  filter(!stringr::str_detect(method_name, met))

metadata_df <- fread(files[5])

# Write back using SAME filenames but NEW path
fwrite(feat_df,  file.path(new_path, basename(files[1])))
fwrite(pred_df,  file.path(new_path, basename(files[2])))
fwrite(trace_df, file.path(new_path, basename(files[3])))
fwrite(metric_df,file.path(new_path, basename(files[4])))
fwrite(metadata_df,file.path(new_path, basename(files[5])))
