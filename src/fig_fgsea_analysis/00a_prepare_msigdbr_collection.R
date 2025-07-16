doc <- "

This script is used to prepare gene symbols from the msigdbr collection database
Usage:
  00a_prepare_msigdbr_collection.R [options]

Options:
  --output_path=OUTPUT_PATH     File to output the processed database
"


# Need to get the pathways first
library(msigdbr)
library(MiRSEA)
suppressPackageStartupMessages(library(dplyr))


main <- function(output_path) {
  if (is.null(output_path)) {
    output_path <- "data/processed/msigdbr_pathways_collection.rds"
  }
  message("\nNote this script requires internet connection to work, so it should take some time")
  # Load the pathways first and combine it together
  # NOTE: these require internet connections
  reactome_pathways <- msigdbr(species = "Homo sapiens", collection = "C2",
                               subcollection = "CP:REACTOME")
  oncogenic_pathways <- msigdbr(species = "Homo sapiens", collection = "C6")

  # Select relevant columns
  relevant_cols <- c("gene_symbol", "gs_name", "gs_collection",
                     "gs_collection_name")

  msigdbr_pathways <- bind_rows(reactome_pathways, oncogenic_pathways) |>
    # And filter those of human only
    filter(gs_source_species == "HS") %>%
    select(all_of(relevant_cols)) %>%
    as_tibble()

  # First save this for plotting later
  unique_pathways_collection <- msigdbr_pathways %>%
    distinct(gs_name, gs_collection, gs_collection_name)

  saveRDS(object = unique_pathways_collection,
          file = here::here(output_path))
  message("\nSaved msigdbr collection into ", output_path)

}

# Lastly execute the main based on cli args
opt <- docopt::docopt(doc)
main(output_path=opt$output_path)

# And this below is to run analysis with FGSEA

# gene_list_pathway <- msigdbr_pathways %>%
#   group_by(gs_name) |>
#   summarize(gene_list = list(gene_symbol)) %>%
#   mutate(gene_list = map(gene_list, unlist)) %>%
#   deframe()
#
# # Now also make it the miRNA ONES?
# MiRTarget <- GetMiRTargetData()
# MiRTarget <- subset(MiRTarget, Species == "hsa")
# mrna_mirna <- split(as.character(MiRTarget$miRNA), MiRTarget$Gene)
# # This find those matching genes with miRNAs that source to
# mirnas_by_pathway <- lapply(gene_list_pathway, function(genes) {
#   relevant_genes <- intersect(names(mrna_mirna), genes)
#   miRNAs <- unlist(mrna_mirna[relevant_genes])
#   unique(gsub("\\*", "", miRNAs))
# })
# # Save these to output
# out <- list(gene_pathways = gene_list_pathway, mirna_pathways = mirnas_by_pathway)
# # TODO: should rerun this part, so no NA shown
#
#
# saveRDS(out, "msigdbr_c2reactome-c6_pathways.rds")
