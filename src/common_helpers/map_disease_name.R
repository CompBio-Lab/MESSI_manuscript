# This function maps the disease name into its common name
map_disease_name <- function(dataset) {
  dplyr::case_when(
    dataset == "gse38609" ~ "Autism",
    dataset == "gse71669" ~ "Bladder Cancer (GSE)",
    dataset == "rosmap" ~ "Alzheimer's",
    dataset == "tcga-acc" ~ "Adrenocortical Cancer",
    dataset == "tcga-blca" ~ "Bladder Urothelial Cancer",
    dataset == "tcga-brca" ~ "Breast Invasive Cancer",
    dataset == "tcga-chol" ~ "Bile Duct Cancer",
    dataset == "tcga-esca" ~ "Esophageal Cancer",
    dataset == "tcga-kich" ~ "Kidney Chromophobe Cancer",
    dataset == "tcga-kirc" ~ "Kidney Renal Clear Cell Cancer",
    dataset == "tcga-meso" ~ "Mesothelioma Cancer",
    dataset == "tcga-skcm" ~ "Skin Cutaneous Melanoma",
    dataset == "tcga-stes" ~ "Stomach and Esophageal Cancer",
    dataset == "tcga-thca" ~ "Thyroid Cancer",
    dataset == "clinical_omics" ~ "Clinical + Omics",
    dataset == "imaging_omics" ~ "Imaging + omics",
    dataset == "electrical_omics" ~ "Electrical + omics",
    TRUE ~ "not mapped"
  )
}
