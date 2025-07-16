doc <- "

This script is used to prepare gene symbols from the panglao database
Usage:
  00b_prepare_panglaodb_collection.R [options]

Options:
  --output_path=OUTPUT_PATH     File to output the processed database
"



# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(stringr)

main <- function(output_path) {
  # Load source data, this is fixed
  data_path <- here::here("data/raw/PanglaoDB_markers_27_Mar_2020.tsv")
  if (is.null(output_path)) {
    output_path <- "data/processed/panglao_pathways_collection.rds"
  }

  # Data downloaded from
  # https://panglaodb.se/markers/PanglaoDB_markers_27_Mar_2020.tsv.gz
  # Load the database
  db <- readr::read_tsv(data_path, col_type = readr::cols())
  # Fix colnames
  colnames(db) <- make.names(colnames(db)) # Change to dot
  # Then change to _ for col names
  colnames(db) <- str_replace_all(colnames(db), "\\.", "_")
  # Get relevant columns after fixing name
  relevant_cols <- c(
    "official_gene_symbol", "cell_type",
    "gene_type", "organ"
  )

  # Only look into human genes, make up "gene set",
  # by appending organ_cell type_gene type in that order
  clean_db <- db |>
    # hs is homo sapiens, mm is mus musculus
    filter(str_detect(tolower(species), "hs")) |>
    # Remove NA of organ
    filter(!is.na(organ)) |>
    dplyr::select(all_of(relevant_cols)) |>
    mutate(
      gs_name = str_c(
        str_replace_all(cell_type, " ", "-") |> toupper(),
        sep="_")
    ) |>
    # And rename the gene
    dplyr::rename(gene_symbol = official_gene_symbol)


  # And also save the unique ones out
  unique_pathways_collection <- clean_db %>%
    distinct(gs_name, organ)

  saveRDS(object = unique_pathways_collection,
          file = here::here(output_path))
  message("\nSaved PanglaoDB collection into ", output_path)
}

# Lastly calling it
opt <- docopt::docopt(doc)
main(output_path=opt$output_path)


# So take each "gene set" and the genes that belongs to
# to those sets in list(gene_set1 = c("gene1", "gene3") , ...)
# format
# panglao_db_gsea_input_list <- clean_db |>
#   group_by(gs_name) |>
#   summarize(gene_list = list(gene_symbol)) |>
#   mutate(gene_list = purrr::map(gene_list, unlist)) |>
#   deframe()
#
# # Then save this this to output list for fgsea
# panglao_db_pathways <- list(gene_pathways = panglao_db_gsea_input_list)
#
# saveRDS(panglao_db_pathways, file = output_path)


