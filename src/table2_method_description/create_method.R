# Load required libraries
library(flextable)
library(dplyr)
library(stringr)
library(here)
# ==================================
# These are to edit variables

# Name of the method
METHOD_NAMES <- c(
  "DIABLO", "MOFA+", "RGCCA", "IntegrAO",
  "IntegratedLearner", "Stabl", "Cooperative Learning (multiview)", "MOGONET",
  "GOAT", "mowgli", "BEAM", "SLIDE",
  "JointNMF", "eipy", "multiVI"
  )
# Language of method
LANGUAGES <- c(
  "R", "R/Python", "R", "Python",
  "R", "Python", "R", "Python",
  "Python", "Python", "R", "R",
  "JointNMF", "Python", "Python"
  )

# Type of method (mathematically)
TYPES <- c(
  "GCCA", "Factor analysis", "GCCA", "IntegrAo",
  "IntegratedLearner", "Stabl", "Penalized regression", "GNN",
  "GNN", "Matrix factorization, optimal transport", "BEAM", "SLIDE",
  "JointNMF", "Ensemble", "Deep Learning"
  )


# If it is published as package on main stream package index
PACKAGES <- c(
  "yes", "yes", "yes", "yes",
  "yes", "no", "yes", "no",
  "no", "yes", "yes", "yes",
  "JointNMF", "yes", "yes"
  )

# Link to paper
PAPER_LINKS <- c(
  "https://academic.oup.com/bioinformatics/article/35/17/3055/5292387", # DIABLO
  "https://genomebiology.biomedcentral.com/articles/10.1186/s13059-020-02015-1", # MOFA
  "https://link.springer.com/article/10.1007/s11336-017-9573-x", # RGCCA
  "https://www.nature.com/articles/s42256-024-00942-3", # IntegrAO,
  "https://onlinelibrary.wiley.com/doi/full/10.1002/sim.9953?saml_referrer", # IntegratedLearner
  "https://www.nature.com/articles/s41587-023-02033-x", # Stabl
  "https://www.nature.com/articles/s41746-024-01128-2", # COOPERATIVE_LEARNING
  "https://www.nature.com/articles/s41467-021-23774-w", # MOGONET
  "https://academic.oup.com/bioinformatics/article/39/10/btad582/7280697", # GOAT
  "https://www.nature.com/articles/s41467-023-43019-2", # mowgli
  "https://www.biorxiv.org/content/10.1101/2024.07.31.605805v1", # BEAM,
  "https://www.nature.com/articles/s41592-024-02175-z", # SLIDE
  "JointNMF", # JointNMF
  "https://arxiv.org/abs/2401.09582", # EIPY
  "https://www.nature.com/articles/s41592-023-01909-9" # multiVI


  )

# Link to public repo hosting its code
CODE_LINKS <- c(
  "https://mixomicsteam.github.io/mixOmics-Vignette/id_06.html", # DIABLO,
  "https://github.com/bioFAM/mofapy2/blob/master/mofapy2/notebooks/getting_started_python.ipynb", # MOFA
  "https://github.com/rgcca-factory/RGCCA", # RGCCA
  "https://github.com/bowang-lab/IntegrAO/blob/main/tutorials/simulated_cancer_omics.ipynb", # IntegrAO
  "https://github.com/himelmallick/IntegratedLearner", # IntegratedLearner
  "https://github.com/gregbellan/Stabl/blob/stabl_lw/Notebook%20examples/Tutorial%20Notebook.ipynb", # Stabl
  "https://github.com/dingdaisy/cooperative-learning/", # COOPERATIVE_LEARNING
  "https://github.com/txWang/MOGONET", # MOGONET
  "https://github.com/DabinJeong/GOAT2.0", # GOAT
  "https://github.com/cantinilab/Mowgli", # mowgli
  "https://annaseffernick.github.io/BEAMR/articles/BEAMR.html", # BEAM
  "https://github.com/jishnu-lab/SLIDE/blob/main/vignettes/SLIDE.pdf", # SLIDE,
  "https://cran.r-project.org/web/packages/nnTensor/vignettes/nnTensor-2.html", # JointNMF
  "https://github.com/GauravPandeyLab/eipy", # EIPY
  "https://docs.scvi-tools.org/en/stable/tutorials/notebooks/multimodal/MultiVI_tutorial.html" # multiVI
  )


# Create sample data
data <- data.frame(
  method = METHOD_NAMES,
  type = TYPES,
  language = LANGUAGES,
  package = PACKAGES,
  paper_link = PAPER_LINKS,
  code_link = CODE_LINKS
) %>%
  as_tibble()


data |>
  write.csv("data/processed/method_metadata.csv", row.names = F)
# Create the table with flextable


# table <- flextable(data) %>%
#   # Optionally set header
#   theme_box() %>%
#   autofit() %>%
#   bg(i = seq(1, nrow(data), by = 2), bg = "grey90") %>%  # Light grey for alternate rows
#   bg(part = "header", bg = "navyblue") %>%                 # Dark color for header background
#   color(part = "header", color = "white")
#
#
# # Lastly should save this to output
# table
#save_as_image(table, "some_path.png")
