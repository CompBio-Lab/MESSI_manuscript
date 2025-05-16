# There isnt any other way to standardize the approach of mapping symbols, specially those of GSE studies
# So the illuminaMethylation annotation here

parse_gse_cpg <- function(dat, dname) {
  # For the cpgs, try illumina_450k_db
  # Returns a dataframe
  cpg_methylation_illumina_450k_db <- minfi::getAnnotation("IlluminaHumanMethylation450kanno.ilmn12.hg19") %>%
    as.data.frame() %>%
    dplyr::select(c("Name", "UCSC_RefGene_Name")) %>%
    # Removes that do not have a symbol
    filter(UCSC_RefGene_Name != "") %>%
    mutate(symbol = map_chr(str_split(UCSC_RefGene_Name, ";"), 1)) %>%
    dplyr::select(-c("UCSC_RefGene_Name")) %>%
    as_tibble()


  matched_symbol <- cpg_methylation_illumina_450k_db %>%
    filter(Name %in% dat) %>%
    dplyr::rename(feat = Name)

  return(matched_symbol)
}

parse_gse_mrna <- function(dat, dname) {
  # For these mrnas, usually they're come with probeid
  # Need more customize approach by dataset
  # For now only found to use hugene10sttranscriptcluster.db and illuminaHumanv4.db
  # Could add more in the future
  library(hugene10sttranscriptcluster.db)
  library(illuminaHumanv4.db)

  # Define the available databases
  db_choices <- list(
    "hugene10sttranscriptcluster.db" = hugene10sttranscriptcluster.db,
    "illuminaHumanv4.db" = illuminaHumanv4.db
  )

  matched_symbol <- NULL  # To store the results if found

  for (db_name in names(db_choices)) {
    db <- db_choices[[db_name]]
    message("\nTrying database: ", db_name, " for data: ", dname)

    result <- tryCatch(
      {
        select(db,
               keys = dat,
               columns = c("SYMBOL"),
               keytype = "PROBEID") %>%
          as_tibble() %>%
          dplyr::rename(feat = PROBEID, symbol = SYMBOL) %>%
          dplyr::mutate(feat = as.character(feat))
      },
      error = function(e) {
        message("Error with database ", db_name, ": ", conditionMessage(e))
        NULL
      },
      warning = function(w) {
        message("Warning with database ", db_name, ": ", conditionMessage(w))
        NULL
      }
    )

    # If a valid result is obtained, break out of loop
    if (!is.null(result) && nrow(result) > 0) {
      matched_symbol <- result
      return(matched_symbol)
    }
  }

  # If no match found, return a message
  if (is.null(matched_symbol)) {
    message("Could not find a match for the given probe IDs. Consider adding more database implementations.")
    return(NULL)
  }
}

handle_geo_data <- function(dat, dname) {
  # Slightly harder in gse
  # Most of time have rna and cpg
  if (str_detect(dname, "cpg")) {
    matched_symbol <- parse_gse_cpg(dat, dname)
  }

  if (str_detect(dname, "mrna")) {
    matched_symbol <- parse_gse_mrna(dat, dname)
  }
  return(matched_symbol)
}

handle_tcga_data <- function(dat, dname) {
  # For tcga data at the moment only need to find match of those miRNA
  MiRTarget <- GetMiRTargetData() %>%
    # Only keep human ones for now
    #filter(Species == "hsa") %>%
    dplyr::select(miRNA, Gene, Species, SourceDB) %>%
    as_tibble()
  # Then just match those that contain a record
  # And since data comes in a lower case mirna, so uppercase the R only to find match
  # Where db mostly contain records with upper case R
  # miR is for mature miRNA
  # mir is for precurosor mirna
  new_dat <- str_replace(dat, "r", "R")
  # NOTE: one miRNA could have multiple target genes
  # For example hsa-miR-200a has 15 unique target symbols
  matched_symbol <- MiRTarget %>%
    mutate(miRNA = as.character(miRNA)) %>%
    filter(miRNA %in% new_dat) %>%
    dplyr::rename(symbol = Gene) %>%
    # Also could have duplicate rows? or repeats since there are multiple sourceDB
    # So just take all unique symbol out
    dplyr::select(miRNA, symbol) %>%
    distinct(miRNA, symbol) %>%
    dplyr::rename(feat = miRNA)
  return(matched_symbol)
}

parse_ensembl_gene <- function(dat, dname) {

  mart <- useEnsembl(biomart = "genes", dataset = "hsapiens_gene_ensembl")

  # Create a copy of the original 'dat' to retain the order later
  #dat <- all_feats_list$rosmap_genomics
  original_dat <- tibble(feat = dat) %>%
    dplyr::mutate(
      # Remove the version information from the Ensembl IDs
      trimmed_dat = str_replace(dat, "\\..*", "")
    )


  # Retrieve matched symbols
  matched <- getBM(
    attributes = c("ensembl_gene_id", "hgnc_symbol"),  # Retrieve Ensembl ID and Gene Symbol
    filters = "ensembl_gene_id",
    values = original_dat$trimmed_dat,
    mart = mart
  ) %>%
    # Remove those that have no gene symbol
    filter(hgnc_symbol != "") %>%
    dplyr::rename(symbol = hgnc_symbol) %>%
    as_tibble()

  # Join the original 'dat' with the filtered 'matched_symbol' based on the feature column (Ensembl Gene ID)
  matched_symbol <- left_join(original_dat, matched, by = c("trimmed_dat" = "ensembl_gene_id")) %>%
    dplyr::select(-c("trimmed_dat")) %>%
    filter(!is.na(symbol))

  return(matched_symbol)
}

handle_custom <- function(dat, dname) {
  # In this moment only have rosmap
  matched_symbol <- NULL
  is_rosmap <- str_detect(tolower(dname), "rosmap")
  if (!is_rosmap) {
    print(dname)
    stop("Not implemented beyond rosmap for other custom datasets")
  } else {
    # In rosmap there are 3 omics
    # epigenomics follows similar of cpg earlier of geo
    if (str_detect(dname, "epigenomics")) {
      matched_symbol <- parse_gse_cpg(dat, dname)
    } else if (str_detect(dname, "transcript")) {
      # transcriptomics follower similar of miRNA earlier of tcga
      matched_symbol <- handle_tcga_data(dat, dname)
    } else {
      # genomics is in Ensembl gene id
      # NOTE: THIS ONE COULD FAIL due to internet error
      matched_symbol <- parse_ensembl_gene(dat, dname)
    }
  }

  return(matched_symbol)

}
