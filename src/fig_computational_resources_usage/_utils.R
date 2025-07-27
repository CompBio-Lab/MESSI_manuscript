library(stringr)

chop_nf_core_prefix <- function(process) {
  str_replace(process,"NFCORE_MESSI_BENCHMARK:MESSI_BENCHMARK:", "")
}

separate_workflow_process <- function(df, to_wide_col) {
  tidyr::separate_wider_delim(
    df, !!ensym(to_wide_col), delim=":", names=c("workflow", "process"),
    too_many="merge", too_few="align_start"
  )
}




convert_to_seconds <- function(time_str) {
  # Hours (digits before 'h')
  hours <- str_extract(time_str, "\\d+(?=h)") %>% as.numeric()

  # Minutes (digits before 'm' but NOT followed by 's')
  minutes <- str_extract(time_str, "\\d+(?=m(?!s))") %>% as.numeric()

  # Seconds (digits with optional decimals before 's' but NOT preceded by 'm')
  seconds <- str_extract(time_str, "\\d+(\\.\\d+)?(?=s)") %>% as.numeric()

  # Milliseconds (digits with optional decimals before 'ms')
  milliseconds <- str_extract(time_str, "\\d+(\\.\\d+)?(?=ms)") %>% as.numeric()

  # Replace NAs with 0
  hours[is.na(hours)] <- 0
  minutes[is.na(minutes)] <- 0
  seconds[is.na(seconds)] <- 0
  milliseconds[is.na(milliseconds)] <- 0

  # Calculate total seconds
  total_seconds <- hours * 3600 + minutes * 60 + seconds + milliseconds / 1000
  return(total_seconds)
}


convert_to_mb <- function(mem_str) {
  mem_str <- str_trim(toupper(mem_str))  # Clean and standardize
  # Extract numeric value and unit
  value <- str_extract(mem_str, "[0-9.]+") %>% as.numeric()
  unit <- str_extract(mem_str, "[KMG]B")

  # Conversion based on unit
  multiplier <- dplyr::case_when(
    unit == "KB" ~ 1 / 1024,
    unit == "MB" ~ 1,
    unit == "GB" ~ 1024,
    TRUE ~ NA_real_  # For unknown units
  )

  # Convert to MB
  value * multiplier
}
