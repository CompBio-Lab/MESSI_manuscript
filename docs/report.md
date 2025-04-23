---
title: "MESSI: A Nextflow pipeline for benchmarking multiomics integration methods for disease classification"
author:
  - "Chunqing (Tony) Liang"
  - "Tajveer Grewal"
  - "Asees Singh"
  - "Amrit Singh"
#csl: assets/nature.csl
csl: assets/springer-vancouver-brackets.csl
bibliography: assets/reference.bib
linkcolor: blue
link-citations: true
geometry: margin=2cm
nocite: '@*'
output: 
  bookdown::pdf_document2:
    number_sections: false
    toc: true
    extra_dependencies: ["flafter"]
    keep_md: true
    includes:
      in_header: common_header.tex
header-includes:
  \usepackage{lscape}
  \usepackage{pdfpages}
  \usepackage{graphicx}
  \usepackage[figuresright]{rotating}
  
---




# Abstract

Technological advances enable multiomics profiling of molecular data (e.g., genes, proteins, metabolites) from biological samples at bulk, single-cell, spatial resolution. Integrative methods identify shared patterns and biomarkers, improving disease understanding and clinical strategies. However, method selection is challenging due to varying analytical tasks (e.g., clustering, prediction) and data types. Existing reviews are task-specific or non-reproducible. We propose an automated framework in Nextflow, *MESSI*, for systematic benchmarking of multiomics methods. It ensures reproducibility, standardizes inputs across tasks, and runs on any computing platform, enabling reliable method evaluation and selection.

**Keywords**: bioinforma    tics pipeline, multiomics integration methods, machine learning, benchmark, multimodal learning



# Background


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

\begin{table}
\centering
\caption{(\#tab:method-meta-table)List of available multiomics integration methods}
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


# Results





# Discussion

-   Explain results, and relevant comments to these

# Conclusion

Overall, DIABLO emerged as the top performer in terms of classification performance, with relatively consistent computational time Conversely, MOGONET, leveraging deep neural networks, displayed the weakest performance. While acknowledging the potential for further enhancements through exploration of additional datasets and methodologies, we encountered a significant challenge of no publicly available repository/data portal with curated multiomics data. To address this gap, we have begun to curate multiomics studies for various omics data (e.g., transcriptomics, methylation, proteomics) and associated clinical metadata across a range of cancer and non-cancer diseases from various public sources to create the first data portal for multiomics data (\~ 100 studies) in both standard formats mentioned such that they can easily be used by other researchers. We anticipate this exercise to be highly relevant to the community utilizing multiomics data for their research, such will help inform the development of a new integrative method that is applicable to different types (bulk, single-cell, or spatial) of multiomics data with the extensibility of our proposed MESSI pipeline.

\newpage

<!----

Here simply include child doc of method

---->

# Methods



\newpage

# References

::: {#refs}
:::

# (APPENDIX) Appendix {.unnumbered}

# More information

This will be Appendix A.

<!-- This proposed pipeline ensures full reproducibility of any method by using an independent container environment with Singularity [@kurtzer2017singularity]. We propose to publish this pipeline on the nf-core [@ewels2020nf] platform, a community of Nextflow users, to ensure easy access and usability for researchers worldwide. 


Currently, we are benchmarking existing methods like DIABLO [@singh2019diablo], Cooperative Learning [@ding2022cooperative], MOGONET [@wang2021mogonet], RGCCA [@girka2023multiblock], MOFA [@Argelaguet2018; @Argelaguet2020] . The current pipeline focuses on testing this selection of integrative methods against a series of real multiomics datasets, particularly for classification tasks.

The results are compared using metrics like balanced classification error, F1 score, and biological enrichment results.

Regarding classification performance, we employed the area under the curve (AUC) score for method comparison across datasets (Fig 1B). Mogonet emerged as the weakest performer, with MOFA + glmnet showing only marginal improvement. In contrast, Cooperative Learning demonstrated the highest performance, followed by DIABLO and RGCCA. Interestingly, DIABLO with a null design outperformed than its full design choice. Nevertheless, all methods performed poorly on the tcga-thca dataset.




Through MESSI, we could systematically identify the top-performing methods with respect to classification performance and identifying molecular drivers of disease. Furthermore, this could extend to regression tasks or clustering tasks. This project can greatly benefit the community, either by developing new methods to assess their strength or finding a method that best suits custom multiomics data.

-->


# One more thing

This will be Appendix B.
