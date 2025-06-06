Technological advances now enable profiling of diverse molecular measurements (e.g., genes, proteins, metabolites) from the same biological samples. This approach, termed multiomics [@subramanian2020multi], treats each omics layer as a distinct source of information. Integrating these layers can improve our understanding of the molecular mechanisms underlying disease and lead to novel strategies for early detection, prevention, and treatment [@sun2016integrative].

However, integrating multiomics data is not straightforward. There are various ways to combine data sources, and improper integration can increase model complexity without improving performance [@picard2021integration]. The integration strategy should depend on the intended task—such as cancer subtyping, drug response prediction, or survival analysis. Accordingly, numerous methods have been developed to jointly analyze multiomics data, aiming to identify cross-omics patterns and disease-related biomarkers [@vandereyken2023methods]. Yet, due to the wide variety of methods and their abstract nature, researchers often struggle to select appropriate tools for their specific biological questions.


Several reviews have compared multiomics integration methods across tasks such as classification, clustering, and survival prediction [@bersanelli2016methods; @cantini2021benchmarking; @hasin2017multi; @huang2017more; @li2018review; @li2022benchmark; @luecken2022benchmarking; @pucher2019comparison; @richardson2016statistical; @yu2018integrative; @zeng2018review] with public dataset sources like TCGA [cite] and GEO [cite]. However, many of these studies suffer from limitations, including lack of reproducibility, shallow comparisons, limited combinations of methods and datasets, and lack of continuous updates. In particular, most reviews rely on custom scripts, with little effort toward standardized, reusable frameworks. This made others extremely hard to reproduce works and trust on the methods, specifically when some benchmarks do not have its implementation publicly available.


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

```{r method-meta-table, results="asis", eval=TRUE, fig.pos="H"}
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
        "Paper"
        #"Code link"
      ),
      escape = FALSE,
      format = "latex") |>
  kableExtra::kable_styling(
    latex_options = c("scale_down", "striped", "HOLD_position"), 
    full_width = F)
  # Change column width of method
  #column_spec(1, width="100pt") |>
  # Change column width of type of method
  #column_spec(2, width="80pt")

  #kableExtra::landscape()
  #collapse_rows(valign = "middle") %>%
  #column_spec(5, width="10px") %>%
```


Despite the growing number of multiomics integration methods, systematic benchmarking remains a challenge. Methods vary widely in input requirements (e.g., omics formats, labels), implementation languages (R, Python), and evaluation protocols (e.g., internal cross-validation vs. fixed splits). These inconsistencies hinder fair comparison and reproducibility.

To address these limitations, we propose MESSI, a modular nad automated framework for systematically benchmarking and analyzing multiomics integration methods (see Table @ref(tab:method-meta-table)). Its generic and extensible design allows easy incorporation of new state-of-art (SOTA) methods, ensures full reproducibility, and standardizes inputs across analytical tasks. By treating each method as a self-contained module and managing execution via Nextflow and containers, MESSI ensures reproducibility and enables seamless extension to new tools and datasets. It can be deployed on any computing platform, enabling continuous evaluation of existing and emerging methods without duplicating effort.  Overall, MESSI serves not only as a benchmarking framework, but also as a prototype for a unified and reproducible approach to multiomics analysis such researchers could continuously assess current and in-development methods, and track changes without the need to reinventing the wheels in many sense.
