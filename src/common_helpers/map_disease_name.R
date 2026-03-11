# This function maps the disease name into its common name
map_disease_name <- function(dataset) {
  dplyr::case_when(
    dataset == "gse38609" ~ "Autism",
    dataset == "gse71669" ~ "Bladder Cancer (GSE)",
    dataset == "rosmap" ~ "Alzheimer's",
    dataset == "tcga-acc" ~ "Adrenal gland Cancer",
    dataset == "tcga-blca" ~ "Bladder Cancer",
    dataset == "tcga-brca" ~ "Breast Cancer",
    dataset == "tcga-chol" ~ "Bile Duct Cancer",
    dataset == "tcga-esca" ~ "Esophageal Cancer",
    dataset == "tcga-kich" ~ "Kidney Cancer (kich)",
    dataset == "tcga-kirc" ~ "Kidney Cancer (kirc)",
    dataset == "tcga-meso" ~ "Pleura Cancer",
    dataset == "tcga-skcm" ~ "Skin Cancer",
    dataset == "tcga-stes" ~ "Stomach/Esophagus Cancer",
    dataset == "tcga-thca" ~ "Thyroid Cancer",
    dataset == "clinical_omics" ~ "Clinical + Omics",
    dataset == "imaging_omics" ~ "Imaging + Omics",
    dataset == "electrical_omics" ~ "Electrical + Omics",
    TRUE ~ "not mapped"
  )
}
