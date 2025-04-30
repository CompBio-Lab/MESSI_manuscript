Technological advances have allowed for the profiling of different molecular measurements (e.g., genes, proteins, metabolites) from the same biological samples; termed multiomics [@hasin2017multi; @subramanian2020multi].

The majority of multiomics data are obtained for samples from individual patients (bulk multiomics data) and more recently with single-cell and spatial resolution.

Many methods have been developed to jointly analyze multiomics data to identify common patterns between datasets, and to identify biomarkers of disease [@vandereyken2023methods].

This integrative approach of multiomics data may strengthen the understanding of the molecular dynamics underlying the biological processes of diseases and may lead to novel strategies for early detection, prevention, and treatment of human diseases [@sun2016integrative].

Researchers face difficulties in choosing the right method due to the varying nature of analytical tasks such as clustering analysis, factor analysis, or cancer type prediction.

Hence, numerous reviews have benchmarked various integrative methods [@bersanelli2016methods; @cantini2021benchmarking; @hasin2017multi; @huang2017more; @li2018review; @li2022benchmark; @luecken2022benchmarking; @pucher2019comparison; @richardson2016statistical; @yu2018integrative; @zeng2018review]. However, these studies often focus on methods for specific tasks or data types and may lack reproducibility.

To address this, we propose a new automated framework to systematically benchmark and analyze multiomics methods (table \@ref(tab:method-meta-table)) with varying data types. This framework ensures full reproducibility and provides standardized input for any analytical task, with the capability to run on any computing platform.


<!--------
Dummy way but have to self define the reference in markdown first
https://github.com/haozhu233/kableExtra/issues/214#issuecomment-421706528
---------->

(ref:singh2019diablo) @singh2019diablo
(ref:Argelaguet2020) @Argelaguet2020
(ref:girka2023multiblock) @girka2023multiblock
(ref:ma2025moving) @ma2025moving
(ref:mallick2024integrated) @mallick2024integrated
(ref:hedou2024discovery) @hedou2024discovery
(ref:ding2022cooperative) @ding2022cooperative
(ref:wang2021mogonet) @wang2021mogonet
(ref:jeong2023goat) @jeong2023goat
(ref:huizing2023paired) @huizing2023paired
(ref:seffernick2024bootstrap) @seffernick2024bootstrap
(ref:rahimikollu2024slide) @rahimikollu2024slide
(ref:yang2016non) @yang2016non
(ref:bennett2024eipy) @bennett2024eipy
(ref:ashuach2023multivi) @ashuach2023multivi


``` r
method_table <- read.csv(here::here("data/processed/method_metadata.csv"))
# This is the citation table
paper_link_citation <- c(
  "singh2019diablo", # DIABLO
  "Argelaguet2020", # MOFA+
  "girka2023multiblock", # RGCCA
  "ma2025moving", # IntegrAO
  "mallick2024integrated", # IntegratedLearner
  "hedou2024discovery", # STABL 
  "ding2022cooperative", # Cooperative Learning 
  "wang2021mogonet", # MOGONET 
  "jeong2023goat", # GOAT 
  "huizing2023paired", # Mowgli 
  "seffernick2024bootstrap", # BEAMR 
  "rahimikollu2024slide", # SLIDE 
  "yang2016non", # JointNMF 
  "bennett2024eipy", # EIPY 
  "ashuach2023multivi" # MultiVI
  )
# Escape problematic LaTeX characters manually (e.g., _ or % in package names)
escape_latex <- function(x) {
  x |>
    stringr::str_replace_all("_", "\\\\_") |>
    stringr::str_replace_all("%", "\\\\%") |>
    stringr::str_replace_all("&", "\\\\&") |>
    stringr::str_replace_all("#", "\\\\#") |>
    stringr::str_replace_all("\\$", "\\\\$")
}
# And output the table
method_table |>
  dplyr::mutate(across(.cols = -c("paper_link"), .fns = escape_latex)) |>
  # Replace the original paper link to citation
  dplyr::mutate(
    paper_link = paste0("(ref:", paper_link_citation, ")")
    ) |>
  # Ignore code link
  dplyr::select(-c("code_link")) |>
   # Change names of column
  kableExtra::kbl(
    caption = "List of available multiomics integration methods", booktab=T,
      col.names = c(
        "Method", 
        "Type",
        "Language",
        "Package available",
        "Paper link"
        #"Code link"
      ),
      escape = FALSE,
      format = "latex") |>
  kableExtra::kable_styling(
    latex_options = c("scale_down", "striped", "HOLD_position"), 
    full_width = F)
```

\begin{table}[H]
\centering
\caption{\label{tab:method-meta-table}List of available multiomics integration methods}
\centering
\resizebox{\ifdim\width>\linewidth\linewidth\else\width\fi}{!}{
\begin{tabular}[t]{lllll}
\toprule
Method & Type & Language & Package available & Paper link\\
\midrule
\cellcolor{gray!10}{DIABLO} & \cellcolor{gray!10}{GCCA} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:singh2019diablo)}\\
MOFA+ & Factor analysis & R/Python & yes & (ref:Argelaguet2020)\\
\cellcolor{gray!10}{RGCCA} & \cellcolor{gray!10}{GCCA} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:girka2023multiblock)}\\
IntegrAO & IntegrAo & Python & yes & (ref:ma2025moving)\\
\cellcolor{gray!10}{IntegratedLearner} & \cellcolor{gray!10}{IntegratedLearner} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:mallick2024integrated)}\\
\addlinespace
Stabl & Stabl & Python & no & (ref:hedou2024discovery)\\
\cellcolor{gray!10}{Cooperative Learning (multiview)} & \cellcolor{gray!10}{Penalized regression} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:ding2022cooperative)}\\
MOGONET & GNN & Python & no & (ref:wang2021mogonet)\\
\cellcolor{gray!10}{GOAT} & \cellcolor{gray!10}{GNN} & \cellcolor{gray!10}{Python} & \cellcolor{gray!10}{no} & \cellcolor{gray!10}{(ref:jeong2023goat)}\\
mowgli & Matrix factorization, optimal transport & Python & yes & (ref:huizing2023paired)\\
\addlinespace
\cellcolor{gray!10}{BEAM} & \cellcolor{gray!10}{BEAM} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:seffernick2024bootstrap)}\\
SLIDE & SLIDE & R & yes & (ref:rahimikollu2024slide)\\
\cellcolor{gray!10}{JointNMF} & \cellcolor{gray!10}{JointNMF} & \cellcolor{gray!10}{JointNMF} & \cellcolor{gray!10}{JointNMF} & \cellcolor{gray!10}{(ref:yang2016non)}\\
eipy & Ensemble & Python & yes & (ref:bennett2024eipy)\\
\cellcolor{gray!10}{multiVI} & \cellcolor{gray!10}{Deep Learning} & \cellcolor{gray!10}{Python} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:ashuach2023multivi)}\\
\bottomrule
\end{tabular}}
\end{table}

``` r
  #kableExtra::landscape()
  #collapse_rows(valign = "middle") %>%
  #column_spec(5, width="10px") %>%
```
