library(data.table)  # fread is fast and efficient
library(stringr)

# Define the parent directory
parent_dir <- here::here("data/raw/simulated_data_results/")

# List subdirectories only (no files)
subdirs <- list.dirs(parent_dir, recursive = FALSE)

# Define target file names (handle .csv and .txt separately)
csv_files <- c(
  "all_feature_selection_results.csv",
  "all_langs-result.csv",
  "metrics.csv",
  "parsed_metadata.csv"
)
tsv_files <- c("execution_trace.txt")

# Output directory for merged files
output_dir <- file.path(parent_dir, "merged_results")
dir.create(output_dir, showWarnings = FALSE)

# Helper function to read and merge CSV files
merge_csv_files <- function(filename) {
  dfs <- lapply(subdirs, function(dir) {
    path <- file.path(dir, filename)
    if (file.exists(path)) {
      dt <- fread(path)
      return(dt)
    } else {
      return(NULL)
    }
  })
  merged <- rbindlist(dfs, use.names = TRUE, fill = TRUE)
  fwrite(merged, file.path(output_dir, filename))
  message("Saved: ", filename)
}

# Helper function to read and merge TSV files
merge_tsv_files <- function(filename) {
  dfs <- lapply(subdirs, function(dir) {
    path <- file.path(dir, filename)
    if (file.exists(path)) {
      dt <- fread(path, sep = "\t")
      return(dt)
    } else {
      return(NULL)
    }
  })
  merged <- rbindlist(dfs, use.names = TRUE, fill = TRUE)
  #output_name <- str_replace(filename, "\\.txt$", ".tsv")
  fwrite(merged, file.path(output_dir, filename), sep = "\t")
  message("Saved: ", filename)
}

# Merge all target files
lapply(csv_files, merge_csv_files)
lapply(tsv_files, merge_tsv_files)
