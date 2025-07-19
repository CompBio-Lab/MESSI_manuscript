library(dplyr)
library(ggplot2)

process_dat <- function(df) {
  df %>%
    tidyr::pivot_longer(cols = starts_with("TCGA"), names_to = "sample") |>
    tidyr::pivot_wider(names_from = "attrib_name", values_from = "value")
}

cancer_cand <- c("ACC", "CHOL", "COADREAD",
         "ESCA", "HNSC", "KICH",
         "KIRC", "LIHC", "LUAD", "LUSC",
         "MESO", "PAAD",
         "SARC", "SKCM", "STAD", "STES",
         "TGCT", "UVM")

cancer_names <- paste("TCGA", cancer_cand, sep="-")

new_list <- vector(mode = "list", length = length(cancer_names))
names(new_list) <- cancer_names


for (n in cancer_names) {
  new_dat <- getLinkedOmicsData(n, "Clinical") |>
    process_dat()
  if (!"pathologic_stage" %in% colnames(new_dat)) {
    print(paste0("Data has no pathologic stage", ": ", n))
  } else {
    stage_names <- new_dat |>
      filter(tolower(pathologic_stage) %in% c("stagei", "stageii", "stageiii", "stageiv")) |>
      pull(pathologic_stage) |>
      table()
    new_list[[n]] <- stage_names
  }
}


# This do not check if these patients have data in all omics
# It is just counting how many patients have for specific cohort
cleaned <- new_list %>%
  purrr::discard(is.null) %>%                        # Remove NULL elements
  purrr::imap_dfr(~ as.data.frame(.x) %>%             # Convert each table to a data frame
             mutate(cancer = .y))  %>%
  tidyr::pivot_wider(names_from = "Var1", values_from = "Freq") %>%
  group_by(cancer) %>%
  mutate(total_sum = sum(stagei, stageii, stageiii, stageiv)) %>%
  mutate(prop_neg = ( stagei + stageii ) / total_sum,
         prop_pos = 1 - prop_neg) %>%
  ungroup() %>%
  filter(!if_any(everything(), ~ is.na(.))) %>%
  filter(prop_pos > 0.1)



# Then created the list based on what to be retrieved in internet
tcga <- vector(mode="list", length = nrow(cleaned))
names(tcga) <- cleaned$cancer

for (cancer in cleaned$cancer) {
  # Construct list for each cancer
  out_list <- list(
    comparison = c("stagei_ii", "stageiii_stageiv"),
    stages = c("stagei"="stagei_stageii", "stageii"="stagei_stageii",
               "stageiii"="stageiii_stageiv", "stageiv"="stageiii_stageiv"),
    cancer_name = cancer,
    datasets = c("Clinical", "Methylation (Gene level, HM450K)",
                 "miRNA (Gene level)", "RPPA (Gene Level)",
                 "RNAseq (HiSeq, Gene level)")
    )
  tcga[[cancer]] <- out_list
}

# Now edit specific entries for certain cancer
tcga$`TCGA-COADREAD`$datasets[3] <- "miRNA (GA, Gene level)"
tcga$`TCGA-COADREAD`$datasets[4] <- "RPPA (Gene level)"
tcga$`TCGA-HNSC`$datasets[3] <- "miRNA (GA, miRgene level)"
tcga$`TCGA-KIRC`$datasets[3] <- "miRNA (GA, miRgene level)"
tcga$`TCGA-LUAD`$datasets[3] <- "miRNA (GA, miRgene level)"
tcga$`TCGA-LUSC`$datasets[3] <- "miRNA (GA, miRgene level)"
tcga$`TCGA-STAD`$datasets[3] <- "miRNA (GA, miRgene level)"
tcga$`TCGA-STES`$datasets[2] <- "Methylation (Gene level, HM27)"
tcga$`TCGA-STES`$datasets[3] <- "miRNA (GA, miRgene level)"

# Save to file as well
saveRDS(tcga, "tcga-metadata-list.rds")

tcga <- readRDS("tcga-metadata-list.rds")

# THEN TO EXECUTE
raw_data <- lapply(names(tcga), function(cancer){
  ## Download data

  dats <- lapply(tcga[[cancer]]$datasets, function(data){
    print(paste(cancer, data, sep="-"))
    omics_data <- getLinkedOmicsData(
      project = cancer,
      dataset = data
    )
  })
  names(dats) <- tcga[[cancer]]$datasets
  return(dats)
  })
names(raw_data) <- names(tcga)
# Then just load from here to start cleaning
saveRDS(raw_data, "tcga-datasets.rds")


# FROM HERE Loading the rds instead
raw_data <- readRDS("tcga-datasets.rds")



all_data <- lapply(names(tcga), function(cancer) {

  dats <- raw_data[[cancer]]
  ## select common subjects and transpose data
  processed_data <- lapply(dats, function(i){
    x <- as.data.frame(i[, Reduce(intersect, sapply(dats, colnames))])
    xx <- x[,-1]
    rownames(xx) <- x$attrib_name
    t(xx)
  })

  ## add response
  response <- processed_data$Clinical[, "pathologic_stage"]
  names(response) <- rownames(processed_data$Clinical)

  ## process clinical data
  clin <- data.frame(age = processed_data$Clinical[, "years_to_birth"],
                     sex = as.numeric(factor(processed_data$Clinical[, "gender"], levels = c("female", "male")))-1,
                     sample_names = rownames(processed_data$Clinical))
  processed_data$Clinical <- clin

  ## keep selected stages only
  response <- response[as.character(response) %in% names(tcga[[cancer]]$stages)]
  for(stage in names(tcga[[cancer]]$stages)){
    response[response %in% stage] <- tcga[[cancer]]$stages[stage]
  }
  processed_data <- lapply(processed_data, function(i){
    i[names(response), ]
  })
  processed_data$Y <- response
  processed_data
})


names(all_data) <- names(tcga)
dnames <- names(all_data)

clean_data <- lapply(dnames, function(cancer) {
  d <- all_data[[cancer]]
  # For each of this dataset of cancer, rename those names
  # Replace spaces with _ and remove either parenthesis and comma
  names(d) <- gsub(" ", "_", names(d))
  names(d) <- gsub("[(),]", "", names(d))
  #names(d) <- gsub(",", "-", names(d))
  return(d)
})

names(clean_data) <- dnames


saveRDS(clean_data, "cleaned-tcga-datasets.rds")

library(MultiAssayExperiment)

clean_data <- readRDS("cleaned-tcga-datasets.rds")
for (d in names(clean_data)) {
 if (nrow(clean_data[[d]]$Clinical) < 20) {
   print(paste(d, " has less than ", 20, " observations"))
 }
}

# These have less than 20 obs
to_filter <- c("TCGA-COADREAD", "TCGA-LIHC", "TCGA-LUAD", "TCGA-LUSC", "TCGA-STAD")

clean_data <- clean_data[!names(clean_data) %in% to_filter]

saveRDS(clean_data, "cleaned-tcga-datasets.rds")

clean_data <- readRDS("cleaned-tcga-datasets.rds")




# NOTE HERE, we only have those patients that have data in all omics
# i.e. if 3 omics, each has 47, 43, 46, we end up taking 43 that are present in
# all 3 omics
mae_list <- lapply(names(clean_data), function(dataset_name) {
  raw_data <- clean_data[[dataset_name]]

  col_data_df <- cbind(raw_data$Clinical, response = factor(raw_data$Y)) |>
    dplyr::mutate(response = factor(as.numeric(response) - 1)) |>
    dplyr::mutate(dataset = dataset_name)
  # Extract diff comp from the data
  # Data comes in n x p_i format, so transform it to the MAE preferred one
  experiments <- raw_data[!names(raw_data) %in% c("Clinical", "Y")] |>
    lapply(t)
  # Then should construct MAE
  mae <- MultiAssayExperiment(experiments=experiments,
                              metadata=col_data_df,
                              colData = col_data_df
  )
  return(mae)
})
names(mae_list) <- names(clean_data)


mae_list$`TCGA-ACC`@ExperimentList$Methylation_Gene_level_HM450K |> ncol()


sapply(names(mae_list), function(cancer) {
  mae_list[[cancer]]@ExperimentList[[1]] |> ncol()

  mean(mae_list[[cancer]]$response == "1")
})
for (dname in names(mae_list)) {
  mae <- mae_list[[dname]]
  saveHDF5MultiAssayExperiment(mae, dir=paste0(dname, "_mae_data"), prefix = "")
}
