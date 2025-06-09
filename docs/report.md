---
title: "MESSI: A Nextflow pipeline for benchmarking multiomics integration methods for disease classification"
author:
  - "Chunqing (Tony) Liang"
  - "Tajveer Grewal"
  - "Asees Singh"
  - "Amrit Singh"
csl: assets/nature.csl
#csl: assets/springer-vancouver-brackets.csl
bibliography: assets/reference.bib
linkcolor: blue
link-citations: true
geometry: margin=2cm
nocite: '@*'
output: 
  bookdown::pdf_document2:
    number_sections: false
    toc: false
    extra_dependencies: ["flafter"]
    keep_md: true
    includes:
      in_header: common_header.tex
header-includes:
  - \usepackage{lscape}
  - \usepackage{pdfpages}
  - \usepackage{graphicx}
  - \usepackage[figuresright]{rotating}
  - \usepackage{caption}
  # Use smaller font size and sans serif for figure captions
  - \captionsetup[figure]{font={small,sf,it}}

---



<!--- Add custom styling for figure captions  -->
<style>
p.caption {
  font-size: 0.1em;
}
</style>

# Abstract

Technological advances enable multiomics profiling of molecular data (e.g., genes, proteins, metabolites) from biological samples at bulk, single-cell, spatial resolution. Integrative methods identify shared patterns and biomarkers, improving disease understanding and clinical strategies. However, method selection is challenging due to varying analytical tasks (e.g., clustering, prediction) and data types. Existing reviews are task-specific or non-reproducible. We propose an automated framework in Nextflow, *MESSI*, for systematic benchmarking of multiomics methods. It ensures reproducibility, standardizes inputs across tasks, and runs on any computing platform, enabling reliable method evaluation and selection.

**Keywords**: bioinformatics pipeline, multiomics integration methods, machine learning, benchmark, multimodal learning



# Background


<!-------------

First section

Set the stage and show the reader why multi-omics is important in modern biology and medicine.

- Briefly introduce what multi-omics is (genomics, transcriptomics, etc.)

- Mention the explosion of available multi-omics data

- Emphasize the need to integrate different omics layers for better biological insight and clinical prediction

- Mention popular applications (e.g., cancer subtyping, drug response, survival analysis)

--------------->

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

\begin{table}[H]
\centering
\caption{(\#tab:method-meta-table)List of available multiomics integration methods}
\centering
\resizebox{\ifdim\width>\linewidth\linewidth\else\width\fi}{!}{
\begin{tabular}[t]{lllll}
\toprule
Method & Type & Language & Package available & Paper\\
\midrule
\cellcolor{gray!10}{DIABLO} & \cellcolor{gray!10}{GCCA} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:singh2019diablo)}\\
MOFA+ & Factor analysis & R/Python & yes & (ref:Argelaguet2020)\\
\cellcolor{gray!10}{RGCCA} & \cellcolor{gray!10}{GCCA} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:girka2023multiblock)}\\
IntegrAO & IntegrAo-fill-later & Python & yes & (ref:ma2025moving)\\
\cellcolor{gray!10}{IntegratedLearner} & \cellcolor{gray!10}{IntegratedLearner-fill-later} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:mallick2024integrated)}\\
\addlinespace
Stabl & Stabl-fill-later & Python & no & (ref:hedou2024discovery)\\
\cellcolor{gray!10}{Cooperative Learning (multiview)} & \cellcolor{gray!10}{Penalized regression} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:ding2022cooperative)}\\
MOGONET & GNN & Python & no & (ref:wang2021mogonet)\\
\cellcolor{gray!10}{GOAT} & \cellcolor{gray!10}{GNN} & \cellcolor{gray!10}{Python} & \cellcolor{gray!10}{no} & \cellcolor{gray!10}{(ref:jeong2023goat)}\\
mowgli & Matrix factorization, optimal transport & Python & yes & (ref:huizing2023paired)\\
\addlinespace
\cellcolor{gray!10}{BEAM} & \cellcolor{gray!10}{BEAM-fill-later} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:seffernick2024bootstrap)}\\
SLIDE & SLIDE-fill-later & R & yes & (ref:rahimikollu2024slide)\\
\cellcolor{gray!10}{JointNMF} & \cellcolor{gray!10}{Matrix factorization} & \cellcolor{gray!10}{R} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:yang2016non)}\\
eipy & Ensemble & Python & yes & (ref:bennett2024eipy)\\
\cellcolor{gray!10}{multiVI} & \cellcolor{gray!10}{Deep Learning} & \cellcolor{gray!10}{Python} & \cellcolor{gray!10}{yes} & \cellcolor{gray!10}{(ref:ashuach2023multivi)}\\
\bottomrule
\end{tabular}}
\end{table}

Despite the growing number of multiomics integration methods, systematic benchmarking remains a challenge. Methods vary widely in input requirements (e.g., omics formats, labels), implementation languages (R, Python), and evaluation protocols (e.g., internal cross-validation vs. fixed splits). These inconsistencies hinder fair comparison and reproducibility.

To address these limitations, we propose MESSI, a modular nad automated framework for systematically benchmarking and analyzing multiomics integration methods (see Table \@ref(tab:method-meta-table)). 
Its generic and extensible design allows easy incorporation of new state-of-art (SOTA) methods, ensures full reproducibility, and standardizes inputs across analytical tasks. By treating each method as a self-contained module and managing execution via Nextflow and containers, MESSI ensures reproducibility and enables seamless extension to new tools and datasets. 
It can be deployed on any computing platform, enabling continuous evaluation of existing and emerging methods without duplicating effort.  

Overall, MESSI serves not only as a benchmarking framework, but also as a prototype for a unified and reproducible approach to multiomics analysis such researchers could continuously assess current and in-development methods, and track changes without the need to reinventing the wheels in many sense.

<!-- Considering omics data in multiple matrices of N x P , where N is samples, P is variables, current integration could be done via N-integration (same samples) or P-integration (same variables) or mix of both [@shannon2024commentary]. We will focus on the N-integration methods for now, and later extend it to P-integration. -->




# Results




## MESSI pipeline

We introduce here the MESSI pipeline, *Multiple Experiments with SyStematic Interrogation* (Fig \@ref(fig:messi-workflow-plot), and additional supplementary), which comprises of 4 main steps: 1) [Prepare data], 2) [Data splitting], 3) [Cross validation], 4) [Feature selection].

\begin{figure}

{\centering \includegraphics[width=0.6\linewidth]{assets/messi_workflow} 

}

\caption{Workflow design of MESSI for benchmarking integration methods with supervised setting. MESSI has a modular design between stages of preparing data, splitting data, cross validation (CV), and feature selection. The CV stage enables parallel computing of many methods implemented in different languages like R and Python seamleslly and reproducibly through independent containers.}(\#fig:messi-workflow-plot)
\end{figure}



MESSI is implemented with Nextflow [@di2017nextflow], a domain specific language (DSL) primarily used by bioinformaticians. Compared to traditional workflow management systems like Snakemake [@koster2012snakemake] or GNU make [@stallman1988gnu], Nextflow breaks down complex workflows into modular components, and connect them with channels which determines the flow of pipeline. This feature allows us to customize each module, extending the pipeline to not only benchmark purposes but also multi-purpose usage. Additionally, This modular design enables rapid, efficient and reproducible way to test and maintain codebases.

Moreover, the core feature of Nextflow of using containerization for modules like Docker [@docker2020docker] and Singularity [@kurtzer2017singularity] solves the reproducibility issue in replicating papers. 
Each time the pipeline is executed, containers are created for each process defined in the workflows that constitute the pipeline. These containers follow same sets of operating system configurations, software versions of the desired computation performed. Hence, it fulfills reproducibility and portability of our results as each time we run these independently on its own encapsulated environment. 
In addition, Nextflow creates unique working directory for each process spawned via these containers, and having all writing I/O operations in this specified directory without modifying the original input files. This way, we dont accidentally overwrite the raw data or any important input file without knowing in the first place.

Furthermore, the independence between each process leads nature of parallelizable computations. This characteristic of the pipeline along with the resumability of re-executing interrupted or failed processes make debugging or changing computational settings for certain methods only atomic and simple.  Ultimately, it reduces time complexity of dealing with large datasets or long runtime computations, compared to standard way of sequentially executing complex script yet failing at a random timepoint with hardness to recover from error.

In terms of interoperability, Nextflow is capable to run the pipeline on various computing platforms including and not limited to our own personal computer, mainstream high-performance computing clusters (HPC) like SLURM, PBS or popular cloud platforms like AWS and Google cloud without modifying code logics.  This is enabled through resource and parameters configurations, making user to only worry about configurations to carry out and not the code logic itself. In particular, this is yet another important feature, the usage of flexible configuration, where user could run full methods collection or of their interest to benchmark. 

With all these characteristics, benchmarking integration methods become trivial, as the data flow through different subworkflows and modules as if in factory, user should only be concerned on providing the right format of data and let MESSI handle the rest. Next, we will describe the main components of the pipeline as in and how each part is implemented as in Fig \@ref(fig:messi-workflow-plot).

### Prepare data


<!----

Things to comment:


- Explain its hard to compare method directly due to diffent input of method
- and their downstream output are not same, so need to standardize data and meethod
- These method are open source

- Mention how data expect to be in tar gz containing the MAE and MuData
- These data goes to a preprocess step of filtering
- And cleaning up "columns" or metadata of it
- Describe some parameters used here, that could be controlled through nextflow config
- So from here, we come to commonly used and cleaned mae and mudata for respective language method

--->


The first step of the pipeline is to prepare the datasets to be benchmarked against for each method thorough a series of common steps.  This is required as methods have different input format, hence we have to first standardize the raw data input, and pass them down to each method's own workflow to further processing.


The input of the pipeline is a csv like the following:

```csv
dataset_name,tar_path
rosmap,/path/to/data/rosmap.tar.gz
tcga-blca,/path/to/data/tcga-blca.tar.gz
```

These csv input allows user to specify multiples datasets as long it follows the requirement of providing an identifier, and a path to compressed tar which consists of two key file formats `.h5` and `.h5mu`. An example of a dataset compressed tar would be:

```bash
rosmap
|- mae_data
|   |- experiments.h5
|   |- mae.rds
|-- rosmap.h5mu
```

These format are used to handle MultiAssayExperiment (mae) [@ramos2017software] in R and MuData [@bredikhin2022muon] in Python. With these two core API, we could interchangeably transform the underlying multiomics data to the different language without losing content. This would also be a first try to unify standard file format used for multiomics data, as current studies usually have very distinct file formats, making it harder to reproduce in the future. In addition, We hope that using these two packages will help users adapt to other integration methods implemented in different languages they are familiar with.

Once having provided the input csv, our pipeline perform following steps to all input data:
1) uncompress each data record's tar file. 2) a) preprocess all mae portion of the data. b) preprare all mudata portion. 3) Parse the datasets using the mu portion only to retrieve common metadata from the datasets.

Step 1) is trivial as it uncompress data in specified working directory to not affect the original raw data. 
Step 2) is ran in a parallel fashion, where the two sub steps perform same preprocessing operations: removing NA observations, filtering features with lower variance than mean variance of each omics of a dataset, later removing those feature that still have near zero variance, i.e. most entries of a feature being same number (usually 0); lastly, coercing the response variable to binary entries if not already provided from the original raw data. 
We have make sure both python and R code are consistent enough, so when comparing datasets in different languages, the data underhood is still the identical at some numerical precision. 
Step 3) retrieves common metadata information like names of the omics present in every dataset, dimensions of its features, number of common observations, the positive class of the response and the proportion of it.

With these standardized data in MAE and MuData format, we then proceeds to next stages of the pipeline, with the MuData portion goes to a data splitting stage prior to model assessment part.

### Data Splitting 


<!---

Things to say

- This splitting is because not all methods carry a built in cv
- Moreover, this make sure all method start with same data setup, since cv in each method might vary due to random seed problem
- Stratified to make sure of handling class imbalance, possible to go into discussion

--->


To perform different types of analysis, we make sure to split data into folds as in usual cross validation way [insert citation here?] using the mudata part. This is because python libraries often have good support in dealing with these operations specifically libraries like scikit-learn [@kramer2016scikit] that provides well-tested API like stratifiedKFold. With this support we create the folds under a 5-fold setting and record the index of testing sets in each fold in txts for downstream usage. The number of folds can also be controlled via nextflow config option of `params.k`. 


This module of splitting data ensures we could always cross validate the data even when an integration method do not have this built-in functionality. In addition, we create these common data splits for all methods making sure that they have same data setup, since the splits could be different in each method due to OS difference or random seed number generation problem. Moreover, this allows us to explore hyperparameters, where the pipeline itself constitutes of outer loop to assess performance, and within method could have inner loop cv for optimizing hyperparameters. Further details will be described under [Methods].


### Cross Validation 

<!----

Things to say

- Have a more detail flow of how here works, given could parallel per method, data, fold
- Show some plot from each method or data
- Then this makes each method as one workflow, where each can contain different number of modules, but requirement is just produce some kind of csv as end result
that follows some format
- each workflow works in parallel and group by languages

---->

The cross validation subworkflow is one of the core component of the pipeline, as it have most computations occurring in place. The key part is we treat each integration method as one independent workflow from another method. Each method can consist different number of modules, but the required ones are: preprocess, train, predict.  The input of each method is either the MAE portion or MuData portion of the original datasets, determined by the language of the method is implemented. 

This flexibility of treating each method as one workflow allows us to specify method dependent parameters within its workflow and also controlled via nextflow config. Moreover, it enable us to further customize and extend any method of preference, i.e. adding extra modules to utilize method's other built-in API like its exploratory data analysis (EDA), plotting functionalities, and so on.

Focusing on our current evaluation, we have only implemented mostly preprocess, train, predict step in this cross validation stage. The preprocess step is to further transform those standardized MAE/MuData as described in [Prepare data] into method specific format. This is due to fact that method have its unique input format either in matrices, tensors, list or any other data types. Hence, this step is crucial and needs to be present. Furthermore, the data here is splitted based on the test set indices stored in txts from [Data Splitting], which results in a format like $\text{data}_i-\text{fold}_j$ where $i = 1, \dots, N$ and $j = 1, \dots, k$ at $k=5$ in a default setting. 
Then in the train step, the specific data $\text{data}_i-\text{fold}_j$ is fed. Its train set will be used for training a model with all default settings of the methods, further details are described under [Methods]. On the other hand, its test portion is past to the predict step and hunged to wait for until model is finish training, Note, there is the option to carry a inner CV on this one fold of data to tune hyperparameters provided if the method has this built-in CV functionality. This option is enable via the nextflow configuration `params.inner_cv`, where default is `False`.  
Next, we evaluate the model against its fold specific test set in the test step, whereas all methods are processed to return common output like predicted probabilities on the repsonse variable, sample names of the fold data, method name, dataset name, and so on.

Lastly, the results from test step are collected together looping all datasets in a method, then against all other method workflows as one full table of model assessment output. An ilustration of one complete method flow is shown at Fig \@ref(fig:one-method-flow-plot)



\begin{center}\includegraphics{report_files/figure-latex/one-method-flow-plot-1} \end{center}

With one method workflow, we just then generalize this to all other methods, and compute them all in parallel in this setting $\text{method}_a\text{-data}_i\text{-fold}_j$ where $a = 1, \dots, M$, $i = 1, \dots, N$, $j = 1, \dots, K$, $M$ is number of methods, $N$ is number of datasets, $K$ is number of folds.





### Feature Selection

<!---

Things to say

- This is an additional workflow that go directly after prepare data rather than splitting
- also makes it parallel by method
- then just talk how collect stuff in common format and produce series of metrics file that could be visualize downstream

--->

Besides the main flow of model assessment via cross validating data, we also provided an additional workflow in the pipeline that solely handles feature selection and return meaningful biomarkers or features from each dataset and method combination. 
This takes in input directly after the common processing in [Prepare data] as it uses full data to tune for relevant features in the data. Similar to model assessment, this workflow is composed of various independent method workflow, which means computation is parallelizable as well.

The output of each method is a table of selected features along with the coefficient associated with it. And, these are collected for all method evaluated on each datasets full portion. Lastly, once collected these results, it is return to user for downstream analysis.


### Configuration of parameters

Configuration of Parameters
To support flexible, reproducible, and modular execution, the pipeline is implemented using Nextflow, which allows multiple configuration profiles to be defined and composed dynamically. Each profile may inherit from others and override parameter values, supporting a hierarchical and modular approach to configuration. Further details on profile usage and inheritance can be found in the Nextflow official documentation [cite here].

In our implementation, important options such as skipping specific methods, adjusting the number of cross-validation folds, modifying method-specific hyperparameters, or adapting to site/platform-specific computing environments are all controlled through Nextflow profiles.

Each profile is defined in a .config file using a Groovy-based syntax similar to YAML, but with the additional ability to evaluate Nextflow expressions dynamically. For example:

```groovy
// This is a top level profile that allows to contain multiple other profiles
params {
  skip_mogonet  = false
  skip_diablo   = false
  fold_k        = 5
  // Method specific
  diablo_design = ["null", "full"]
  mogonet_hdim  = [1, 3, 5]
  // Resource specific
  cpus          = 2
  time_hr       = 3
  mem_gb        = 3 
}

// Then inclusion of other profiles of platform-wise, container-wise, data-wise
profiles {
  // Platforms
  sockeye_hpc { include_config 'conf/sockeye_hpc.config' }
  aws         { include_config 'conf/aws.config'         }
  // Container / Env
  docker      { include_config 'conf/docker.config'      }
  apptainer   { include_config 'conf/apptainer.config'   }
  // Data
  real_data   { include_config 'conf/real_data.config'   }
  sim_data    { include_config 'conf/sim_data.config'    }

}
```

Execution can then be customized by chaining multiple profiles to create tailored configurations. For instance:

```bash
# Run on our university hpc with apptainer of settings for real data 
# where real data could have very specific settings like resource constraints
nextflow run messi-benchmark -profile sockeye_hpc,apptainer,real_data
# Run on aws on simulated data
nextlfow run messi-benchmark -profile aws,sim_data
```

This modular and declarative approach enables extensive flexibility for users, allowing parameter tuning, environment adaptation, and reproducible configuration from a single control script. Changing a single parameter in a profile automatically propagates to all pipeline components where that parameter is used. Furthermore, this structure facilitates systematic exploration of hyperparameters and preserves a complete record of configurations used in each run—critical for reproducibility, benchmarking, and downstream analysis.


### Model Assessment

<!--- 
- Describe how to evaluate the methods, but full technical details refer to methods instead
--->

To demonstrate the utility of our pipeline and to comprehensively assess the performance of integration methods, we evaluated both simulated and real-world datasets under a range of experimental conditions.

Simulated datasets were generated with controlled parameters to test method robustness across varying signal strengths, feature correlations, and noise structures. The full details of the simulation framework are described in the [Methods] section.

In addition, we benchmarked methods on $14$ real-world datasets collected from publicly available sources such as the Gene Expression Omnibus (GEO) [cite here] and The Cancer Genome Atlas (TCGA) [cite here], as summarized in Table \@ref(tab:benchmark-data-table).


\begingroup\fontsize{7}{9}\selectfont

\begin{longtable}[t]{>{\raggedright\arraybackslash}p{0.75in}r>{\raggedright\arraybackslash}p{0.7in}>{\raggedright\arraybackslash}p{0.7in}rlrl}
\caption{(\#tab:benchmark-data-table)Overview of real datasets to benchmark}\\
\toprule
Dataset & N & Y=0 & Y=1 & Prop(Y = 1) & Omic & P & Disease\\
\midrule
\endfirsthead
\caption[]{(\#tab:benchmark-data-table)Overview of real datasets to benchmark \textit{(continued)}}\\
\toprule
Dataset & N & Y=0 & Y=1 & Prop(Y = 1) & Omic & P & Disease\\
\midrule
\endhead

\endfoot
\bottomrule
\endlastfoot
 &  &  &  &  & mrna & 8110 & \\

 &  &  &  &  & cpg & 1674 & \\

\multirow[b]{-3}{0.75in}{\raggedright\arraybackslash GSE38609} & \multirow[b]{-3}{*}{\raggedleft\arraybackslash 24} & \multirow[b]{-3}{0.7in}{\raggedright\arraybackslash control Cer} & \multirow[b]{-3}{0.7in}{\raggedright\arraybackslash autistic} & \multirow[b]{-3}{*}{\raggedleft\arraybackslash 0.458} & cc & 12 & \multirow[b]{-3}{*}{\raggedright\arraybackslash Autism}\\
\cmidrule{1-8}
 &  &  &  &  & cpg & 4796 & \\

 &  &  &  &  & mirna & 175 & \\

 &  &  &  &  & rppa & 42 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-STES} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 25} &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.600} & mrna & 5590 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Stomach and Esophageal Carcinoma}\\
\cmidrule{1-2}
\cmidrule{5-8}
 &  &  &  &  & cpg & 7756 & \\

 &  &  &  &  & mirna & 168 & \\

 &  &  &  &  & rppa & 48 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-CHOL} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 30} & \multirow[b]{-8}{0.7in}{\raggedright\arraybackslash stagei/stageii} & \multirow[b]{-8}{0.7in}{\raggedright\arraybackslash stageiii/stageiv} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.233} &  & 5407 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Cholangiocarcinoma}\\
\cmidrule{1-5}
\cmidrule{7-8}
 &  &  &  &  & \multirow[b]{-2}{*}{\raggedright\arraybackslash mrna} & 5831 & \\

 &  &  &  &  & cpg & 8915 & \\

\multirow[b]{-3}{0.75in}{\raggedright\arraybackslash GSE71669} & \multirow[b]{-3}{*}{\raggedleft\arraybackslash 33} & \multirow[b]{-3}{0.7in}{\raggedright\arraybackslash non-invasive bladder cancer} & \multirow[b]{-3}{0.7in}{\raggedright\arraybackslash invasive bladder cancer} & \multirow[b]{-3}{*}{\raggedleft\arraybackslash 0.424} & cc & 10 & \multirow[b]{-3}{*}{\raggedright\arraybackslash Bladder Cancer}\\
\cmidrule{1-8}
 &  &  &  &  & cpg & 7396 & \\

 &  &  &  &  & mirna & 166 & \\

 &  &  &  &  & rppa & 40 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-ACC} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 46} &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.391} & mrna & 5660 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Adrenocortical Carcinoma}\\
\cmidrule{1-2}
\cmidrule{5-8}
 &  &  &  &  & cpg & 6489 & \\

 &  &  &  &  & mirna & 180 & \\

 &  &  &  &  & rppa & 57 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-KICH} &  &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.302} & mrna & 5517 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Adenomas and Adenocarcinomas}\\
\cmidrule{1-1}
\cmidrule{5-8}
 &  &  &  &  & cpg & 7647 & \\

 &  &  &  &  & mirna & 203 & \\

 &  &  &  &  & rppa & 41 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-MESO} & \multirow[b]{-8}{*}{\raggedleft\arraybackslash 63} &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.762} & mrna & 5852 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Mesothelioma}\\
\cmidrule{1-2}
\cmidrule{5-8}
 &  &  &  &  & cpg & 7534 & \\

 &  &  &  &  & mirna & 218 & \\

 &  &  &  &  & rppa & 47 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-SKCM} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 80} &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.350} & mrna & 5691 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Skin Cutaneous Melanoma}\\
\cmidrule{1-2}
\cmidrule{5-8}
 &  &  &  &  & cpg & 7985 & \\

 &  &  &  &  & mirna & 251 & \\

 &  &  &  &  & rppa & 43 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-BRCA} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 109} &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.358} & mrna & 5936 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Breast Invasive Carcinoma}\\
\cmidrule{1-2}
\cmidrule{5-8}
 &  &  &  &  & cpg & 7963 & \\

 &  &  &  &  & mirna & 202 & \\

 &  &  &  &  & rppa & 44 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-ESCA} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 119} &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.353} & mrna & 5709 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Esophageal Carcinoma}\\
\cmidrule{1-2}
\cmidrule{5-8}
 &  &  &  &  & cpg & 7726 & \\

 &  &  &  &  & mirna & 214 & \\

 &  &  &  &  & rppa & 44 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-KIRC} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 123} &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.520} & mrna & 5941 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Kidney Renal Clear Cell Carcinoma}\\
\cmidrule{1-2}
\cmidrule{5-8}
 &  &  &  &  & cpg & 6367 & \\

 &  &  &  &  & mirna & 231 & \\

 &  &  &  &  & rppa & 25 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-THCA} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 217} &  &  & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.318} & mrna & 5537 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Thyroid Carcinoma}\\
\cmidrule{1-2}
\cmidrule{5-8}
 &  &  &  &  & cpg & 8072 & \\

 &  &  &  &  & mirna & 268 & \\

 &  &  &  &  & rppa & 44 & \\

\multirow[b]{-4}{0.75in}{\raggedright\arraybackslash TCGA-BLCA} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 336} & \multirow[b]{-36}{0.7in}{\raggedright\arraybackslash stagei/stageii} & \multirow[b]{-36}{0.7in}{\raggedright\arraybackslash stageiii/stageiv} & \multirow[b]{-4}{*}{\raggedleft\arraybackslash 0.685} & mrna & 6093 & \multirow[b]{-4}{*}{\raggedright\arraybackslash Bladder Urothelial Carcinoma}\\
\cmidrule{1-8}
 &  &  &  &  & cpg & 58 & \\

 &  &  &  &  & genomics & 74 & \\

\multirow[b]{-3}{0.75in}{\raggedright\arraybackslash ROSMAP} & \multirow[b]{-3}{*}{\raggedleft\arraybackslash 351} & \multirow[b]{-3}{0.7in}{\raggedright\arraybackslash normal control} & \multirow[b]{-3}{0.7in}{\raggedright\arraybackslash alzheimer's disease} & \multirow[b]{-3}{*}{\raggedleft\arraybackslash 0.519} & mrna & 90 & \multirow[b]{-3}{*}{\raggedright\arraybackslash Alzheimer's Disease}\\*
\end{longtable}
\endgroup{}


In the meantime, we have benchmarked $5$ methods: DIABLO [@singh2019diablo], Cooperative Learning [@ding2022cooperative], MOGONET [@wang2021mogonet], RGCCA [@girka2023multiblock], MOFA [@Argelaguet2018; @Argelaguet2020]. Additional candidate methods and implementation options available through the pipeline are listed in Table \@ref(tab:method-meta-table).

<!--- add more here? -->

We evaluated classification performance using standard binary classification metrics: area under the receiver operating characteristic curve (AUC), balanced accuracy, and F1 score, computed using 5-fold cross-validation. The full cross-validation procedure and metric definitions are detailed in the [Methods] section. This allowed us to compare each method’s predictive performance across all datasets in a consistent manner.

To assess the quality of feature selection, we employed different evaluation strategies for simulated and real datasets. For simulated data, where the ground truth is known, we measured the sensitivity and specificity of the selected features to evaluate each method’s ability to distinguish informative variables from noise (see Methods). For real datasets, where ground truth is not available, we ranked features by importance for each method and computed pairwise Spearman rank correlations to quantify the similarity in feature prioritization between methods.

In addition to predictive performance, we measured the computational cost of each method. This included the total runtime and memory usage across key stages of the pipeline: input preprocessing, model training, prediction, and feature selection. These resource metrics allow for a holistic comparison of methods in terms of both performance and computational efficiency.


## Simulation studies

We examined the methods on controlled setting of simulation studies with varying parameters like number of observations, number of predictors in each omics, proportion of signal and correlation between omics and fixed number omics at $3$. Each of these combination of parameters were replicated $3$ times to account for data variability.  

We noticed that as signal increases, method tend to perform better, ultimately its AUC score plateaus at 1 as ilustrated in Fig \@ref(fig:sim-perf-plot). 

This is expected, as more clear pattern exist in different groups (i.e. positive vs negative), labels are better and easier for methods to learn.  On the other hand, we also prove that when there's no signal present, method gives a median AUC of 0.5 , which means it turns out to be randomly guessing the response. This result is also trivial, as there's not clear difference between groups, hence hard to distinguish and models struggle to learn anything meaningful. 

With these simple facts, we have showed that simulations are setup correctly, and verified how machine learning works with labelled data.
Furthermore, we noticed that method given little signal, i.e. $\text{signal} = 1 > 0$, they all start to work well, quickly bumping its $0.5$ AUC to $0.7$. This have showed data with little variation provided it is clear difference among groups, current SOTA methods are capable to make reasonably well predictions. 
We also tested against varying correlation in the omics within each dataset. But, the role of correlation in this simulation is not depicted clearly and requires further understanding and exploration.

From this simulation for classification performance, DIABLO with different design matrices showed relatively good performance ranking at top. Cooperative Learning follows next with consistent distribution of AUC scores, and less variable compared to other methods. MOFA + glmnet and RGCCA + LDA are in the middle, with high variability. Lastly, MOGONET showed consistenly low performance compared to others and only performing well at no signal and full correlation between omics. 


\begin{figure}

{\centering \includegraphics[width=0.85\linewidth,height=0.8\textheight]{../results/figures/fig_performance_evaluation_sim} 

}

\caption{Classification performance of all simulated datasets via varied signal and correlation in the data. Each grid is a specific combination of signal and correlation of datasets. Each box inside grids represents auc mean score from a 5 fold cross validation of method evaluated data at one combination of parameters. The bold line on each box indicates the median of auc mean. Grey points are considered outliers.}(\#fig:sim-perf-plot)
\end{figure}

In terms of ability and quality of feature selection (Fig \@ref(fig:sim-feat-sel-plot)), only Cooperative Learning showed consistent behavior and choosing those meaningful biomarkers out compared to other methods. DIABLO is slightly behind it, and with higher variability at the sensitivity distribution. All other methods performed poorly, since they're quite unstable and could have any performance. 


\begin{figure}

{\centering \includegraphics[width=0.96\linewidth]{../results/figures/fig_feature_selection_sim} 

}

\caption{Simulation studies feature selection sensitivity performance with varied signal and correlation in the data. Each grid is combination of amount of signal to differentiate response variable classes, and correlation of omics within one complete set of multiomics simulated data. Boxplots shows overall sensitivity score distribution on each method for specific combinations of simulation parameters. The sensititivity here is to measure how good methods are identifying the actual signal variables given noise in other variables. A score of 0.75 is considered good.}(\#fig:sim-feat-sel-plot)
\end{figure}


We believe these sets of simulation studies could be used for future method development, and test them against various scenarios of multiomics data. More parameters could be involved to rigorously test method's robustness. This could be achieved with ease with our proposed pipeline, as we need is to setup the correct data and rest is just handled by these fixed and reproducible workflows.


### Real dataset classification performances

After evaluating the pipeline with simulation studies, we then proceed to execute it with real world datasets as describe in table \@ref(tab:benchmark-data-table). The scripts to clean these data could be found under [insert link here...]. 


We noticed the AUC scores follows a similar pattern from the simulations, where most of the AUC fall around $0.7$ as per Fig \@ref(fig:real-perf-plot), this is exactly the case when we have little signal in the data. 
These real datasets that we evaluated are mostly carnicoma cohorts from TCGA, where usually we have fewer observations in later stage carnicoma, and its molecular measurement are not much different with those early stage, i.e. stageii vs stageiii. Furthermore, we have datasets that have near $0.5$, this could indicate low signal present in those datasets. 

In terms of performance ranking, DIABLO still perform at top compared to other methods, where its variant with null design matrix beats performance with full design matrix. This design matrix represents connection or correlation between the omics inside the data. Similar to our simulations, Cooperative Learning follows after DIABLO. Although this time, there are competitions between rest models where all perform moderately. Arguably, one of MOFA + glmnet or MOGONET perform as weakest. 

From here, we verified that there's no such method that could perform well in all possible scenarios, it could be top in certain dataset, but it could also be weakest in some specific dataset, i.e Cooperative Learning has best overall high AUC, but it struglles particularly in the TCGA-STES dataset that studies stomach and esophageal carcinoma. This might be due to the limited sample size of this dataset with only $25$ observations.
Therefore, we prove the pipeline provides an easy way to benchmark multiomics integration methods in purely data-driven approach, and could quickly compare large set of methods at once, and targeting possible candidate method that suits user custom data the most. This way, researcher won't have to figure out setting environments to test certain method against their data, and save their time by fitering out methods that are not best suit to their needs.



\begin{figure}

{\centering \includegraphics[width=0.96\linewidth]{../results/figures/fig_performance_evaluation_real} 

}

\caption{Heatmap of mean AUC from 5 fold-CV. This heatmap represents the mean area under the curve score taken from a 5 fold cross validation evaluated for each method + dataset combination. Lighter color indicates better score or performance of the method. A mean AUC score > 0.7 is considered good. Dendograms indicates possibble relationship between two columns/rows.}(\#fig:real-perf-plot)
\end{figure}



<!--

--->


## Feature selection performance

[1] 0.5213847
 [1] "diablo-full-ncomp-1"      "diablo-full-ncomp-2"     
 [3] "diablo-null-ncomp-1"      "diablo-null-ncomp-2"     
 [5] "mofa-Factor1 + glmnet"    "mofa-Factor2 + glmnet"   
 [7] "mogonet"                  "multiview"               
 [9] "sgcca-full-ncomp-2 + lda" "sgcca-null-ncomp-2 + lda"

We further investigated each method's ability to identify significant biomarkers and examined the overlap between them, calculating the ranking similarity of in their feature sets at Fig \@ref(fig:real-feat-sel-plot). 


\begin{figure}

{\centering \includegraphics[width=0.95\linewidth]{../results/figures/fig_feature_selection_real} 

}

\caption{Pairwise Spearman rank correlations of multiomics integration methods based on real datasets. The heatmap depicts Spearman correlations between method rankings across real datasets. A higher correlation (darker red) indicates greater agreement in performance between two methods. Methods are hierarchically clustered to highlight similarity in performance patterns. Colors on the top and side bars indicate method identity.}(\#fig:real-feat-sel-plot)
\end{figure}

This heatmap illustrates the similarity in performance profiles of different multiomics integration methods across real datasets, as measured by Spearman rank correlation.

Several clear clusters emerge. For example, the mofa-Factor1 + glmnet, and diablo-full-ncomp-2 methods show high mutual correlations of 0.731, suggesting they tend to rank datasets similarly and may be interchangeable in some contexts. In contrast, methods such as mognonet and sgcca-null-ncomp-2 + lda exhibit low correlations with most others (as low as $0.010$), indicating divergent behavior and possibly unique selection or ranking criteria.

Interestingly, diablo-null-ncomp-1 and diablo-null-ncomp-2 form a tight subcluster, implying internal consistency between parameter settings of the same method family. Meanwhile, multiview and sgcca-full-ncomp-2 + lda show only moderate to weak correlation with other methods, suggesting less alignment with the dominant trends.

These findings highlight methodological distinctions even within the same family (e.g., different components or priors in DIABLO) and reinforce the importance of method choice depending on downstream goals—whether to maximize consensus with other tools or to uncover novel patterns


## Biological Relevance Interpretation

To enhance biological relevance of these datasets, we examined FGSEA [insert citation] on all the datasets + method combination separately after the pipeline at Fig
\@ref(fig:fgsea-analysis-plot)

\begin{figure}

{\centering \includegraphics[width=0.92\linewidth]{../results/figures/fig_fgsea_analysis_two_panels} 

}

\caption{Comparative evaluation of multiomics integration methods for identifying significant pathways through gene set enrichment analysis. (A) Mean number of significant pathways detected across methods for two pathway databases: Oncogenic Signature (left) and Reactome (right), with error bars indicating variability. (B) Heatmap showing the proportion of significant pathway–tissue–disease associations (cells) for each method across multiple disease types and tissues. Blue intensity reflects a higher proportion of significant results. The side barplot on the right summarizes the frequency each method appears among the top performers for each tissue–disease pair.}(\#fig:fgsea-analysis-plot)
\end{figure}

This analysis demonstrates the relative effectiveness of different multiomics methods in identifying known pathway associations across diseases. In panel A, MOGONET achieved the highest mean number of significant pathways in the Oncogenic Signature database, while diablo-full-ncomp-1 and mofa-factor2 + glmnet consistently identified more significant Reactome pathways.

Panel B highlights disease and tissue specific strengths of each method. For example, mofa-factor1 + glmnet and diablo-full-ncomp-1 are particularly effective for Thyroid Cancer and Melanoma. The horizontal barplot shows that mofa-factor1 + glment and diablo-full-ncomp-1 are most frequently top performers across diseases and tissues.

Overall, these results suggest that while some methods are more generalizable across datasets (e.g., diablo-full-ncomp-1), others may perform better in specific biological contexts. This has implications for selecting appropriate methods based on the disease or tissue of interest.

## Computational time

We observed notable variations in the computation time of most methods with changing dataset sizes (categorized as small if the size of dataset is less than median of all), while DIABLO exhibited consistent performance regardless of dataset size. Conversely, Cooperative Learning displayed a comparatively longer median time than other methods. (Fig 1A).




```{=html}
<!---
Fig1. Benchmark results of multiomics data and integration methods. (A) Computation time for each multiomics method of varying data size. (B) Classification performances by area under the curve of method and dataset combination. (C) Similarity in feature selection between methods and datasets.
---->
```



# Discussion

-   Explain results, and relevant comments to these

# Conclusion

Overall, DIABLO emerged as the top performer in terms of classification performance, with relatively consistent computational time Conversely, MOGONET, leveraging deep neural networks, displayed the weakest performance. While acknowledging the potential for further enhancements through exploration of additional datasets and methodologies, we encountered a significant challenge of no publicly available repository/data portal with curated multiomics data. 

To address this gap, we have begun to curate multiomics studies for various omics data (e.g., transcriptomics, methylation, proteomics) and associated clinical metadata across a range of cancer and non-cancer diseases from various public sources to create the first data portal for multiomics data (\~ 100 studies) in both standard formats mentioned such that they can easily be used by other researchers. 



We anticipate this exercise to be highly relevant to the community utilizing multiomics data for their research, such will help inform the development of a new integrative method that is applicable to different types (bulk, single-cell, or spatial) of multiomics data.

Lastly, due to the modularity of our pipeline, any additional method or dataset could be easily added, and used to compare with existing methods implemented inside the pipeline




\newpage

<!----

Here simply include child doc of method

---->

# Methods


<!-----

Methods section, main level 1 header is in a parent file

----->
## Dataset

We consider multiomics dataset represented by $P$ omics matrices $X_i$ , where $X_i$ is of dimension $n \times p_i$ ($n$ samples and $p_i$ features) for $i = 1, \dots, P$. 

The real dataset were retrieved from public sources like TCGA [ [citation here] ](citation)  [ [citaiton here] ](citation) with R 4.3.3 and libraries TCGAbiolinks 2.30.4 and GEOquery 2.70.0.
These dataset were furthered processed to keep matched samples data only (same subjects measured in different omics modalities)
Furthermore, they are filtered for omics with non zero variance during the pipeline execution, as certain methods would not work if zero variance data was present.
For a summarized list of real dataset, please refer to table [ [cite the dataset table]](cite). Below we present higher level information of dataset studied in this paper.

### GSE38609

This data is retrieved from https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE38609 with title: *Brain transcriptional and epigenetic associations with the autistic phenotype*. It is composed of an expression data with Illumina HumanHT-12 V4.0 expression beadchip and methylation data with Illumina HumanMethylation27 BeadChip. 24 of the original 72 samples are kept after preprocessing in R 4.2 under our pipeline.
 
### TCGA-STES 

This data is retrieved from https://www.linkedomics.org/data_download/TCGA-STES/, and studies *Stomach and Esophageal carcinoma* (STES). It is made of methylation data of Illumina HM450K platform, miRNA data of Illumina HiSeq platform, miRgene-level with RPM normalization, reverse phase protein array (RPPA) gene level data, and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, RPKM). 25 of the original 625 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-CHOL

This data is retrieved from https://www.linkedomics.org/data_download/TCGA-CHOL/, and studies *Cholangiocarcinoma* or commonly known as bile duct cancer. It is composed of an miRNA with RPM normalization,  methylation data with Illumina HM450K platform, RPPA data, and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, RPKM). 30 of the original 45 samples are kept after preprocessing in R 4.2 under our pipeline.

### GSE71669

This data is retrieved from https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE71669 with title: *Integration analysis of three omics data using penalized regression methods: An application to bladder cancer*. It is composed of expression data with Affymetrix Human Gene 1.0 ST Array [transcript (gene) version] and methylation data with Illumina HumanMethylation27 BeadChip (HumanMethylation27_270596_v.1.2). 33 of the original 90 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-ACC

This data is retrieved from https://www.linkedomics.org/data_download/TCGA-ACC/ and studies *Adrenocortical carcinoma* (ACC). It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples with RPM normalization, RPPA expression normalized (Gene-level), and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, RPKM). 46 of the original 92 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-KICH

This data is retrieved from https://www.linkedomics.org/data_download/TCGA-KICH/ and studies *Kidney Chromophobe*. It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples with RPM normalization, RPPA expression normalized (Gene-level), and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, RPKM). 63 of the original 113 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-MESO


This data is retrieved from https://www.linkedomics.org/data_download/TCGA-MESO/ and studies *Mesothelioma*. It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples with RPM normalization, RPPA expression normalized (Gene-level), and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, RPKM). 63 of the original 87 samples are kept after preprocessing in R 4.2 under our pipeline.


### TCGA-SKCM


This data is retrieved from https://www.linkedomics.org/data_download/TCGA-SKCM/ and studies *Skin Cutaneous Melanoma*. It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples with RPM normalization, RPPA expression normalized (Gene-level), and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, RPKM). 80 of the original 470 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-BRCA


This data is retrieved from https://www.linkedomics.org/data_download/TCGA-BRCA/ and studies *Breast invasive carcinoma*. It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples (Illumina GenomeAnalyzer platform, Normalized, miRgene-level, RPM), RPPA expression normalized (Gene-level), and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, RPKM). 109 of the original 1097 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-ESCA


This data is retrieved from https://www.linkedomics.org/data_download/TCGA-ESCA/ and studies *Esophageal carcinoma*. It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples with RPM normalization, RPPA expression normalized (Gene-level), and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, Normalized log2 RPKM). 119 of the original 185 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-KIRC


This data is retrieved from https://www.linkedomics.org/data_download/TCGA-KIRC/ and studies *Kidney renal clear cell carcinoma*. It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples (Illumina GenomeAnalyzer platform, miRgene-level, Normalized, RPM), RPPA expression normalized (Gene-level), and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, RPKM). 80 of the original 123 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-THCA


This data is retrieved from https://www.linkedomics.org/data_download/TCGA-THCA/ and studies *Thyroid carcinoma*. It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples with RPM normalization, RPPA expression normalized (Gene-level). and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, Normalized log2 RPKM). 217 of the original 503 samples are kept after preprocessing in R 4.2 under our pipeline.

### TCGA-BLCA   

This data is retrieved from https://www.linkedomics.org/data_download/TCGA-BLCA/ and studies *Bladder urothelial carcinoma*. It is composed of methylation data of tumor samples at Gene level from Illumina HM450K platform, miRNA expression for tumor samples with RPM normalization, RPPA expression normalized (Gene-level), and RNAseq data normalized counts (Illumina HiSeq platform, Gene-level, Normalized log2 RPKM). 336 of the original 412 samples are kept after preprocessing in R 4.2 under our pipeline.

### ROSMAP

This data is obtained from AMP-AD Knowledge Portal, and this stands for *The Religious Orders Study and Memory and Aging Project* (ROSMAP) Study, which mainly focus on Alzheimer Disease. It involves genomics, epigenetic, and trasncriptomics data. All 351 samples are kept after preprocessing in R 4.2 under our pipeline.

## Simulated dataset

In order to benchmark methods under full control and knowledge of the data generating process, we simulated a sets of multiomics data based on the paper [@tenenhaus2014variable] with slight modification. The code to generate such data is contained in a R package [SimBulkMultiomics](cite), taht could be accessed through GitHub.

We followed similar approach in the paper mentioned with considering 3 blocks of omics, i.e. each $n \times p_j$ block $X_j$ for $j = 1, 2, 3$ and generated with the following model:

$$X_j = u_j W^{t}_{j} + E_j \quad j = 1, 2, 3$$

The vector $u$ represents principal components and drawn from multivariate normal distribution

$$u \sim N(\mu, \Sigma)$$

where $\mu$ is mean vector with fixed mean for all entries as:

$$\mu = [ \mu_0, \mu_0, \mu_0]^T$$

where $\mu_0$ is also controllable as parameter of the package, and default to $\mu_0 = 0$. This is a parameter to help distinguish group difference.

$\Sigma$ covariance matrix is identity matrix by default representing no correlation across each block. 

We have implemented this simulation in such way to control correlation of each block modifying $\Sigma$ like:

$$\begin{bmatrix}1 & cor & cor \\cor & 1 & cor \\cor & cor & 1 \end{bmatrix}$$

where $cor \in [0, 1]$, and default to $1$. 

The weights are drawn from the following distribution:

$$\text{Unif}(-0.3, -0.2) \cup \text{Unif}(0.2, 0.3)$$

$E_j$ is a $n \times p_j$ residual matrix drawn from $N(0,1)$.

The core function that generates such data from the mentioned R package is `simBulkMultiomics::sim_data()` that takes in parameters of `n` for number of subjects/samples , `p` for number of predictors in each omics individually, `j` for number of omics (default to 3), `dt` for strength of distinction between response classes, `rho` for correlation between omics, `pc_mu` for group means. 

## Integration methods algorithms

The original technical details of evaluated integration methods can be found in publications [ @singh2019diablo, @ding2022cooperative, @wang2021mogonet, @girka2023multiblock,  @Argelaguet2018; @Argelaguet2020 ]. Here, we will quickly summarize key components of each method in alphabetical order.

### Cooperative Learning

Cooperative Learning is implemeneted in R with package name `multiview`. It is a supervised learning framework that integrates multiple data modalities (views) by joinly minizing prediction error while encouraging agreement across $M$ views with the following optimization problem:

$$
\text{min} E[\frac{1}{2}(y - \sum_{m=1}^M f_{X_m} (X_m))^2 + \frac{\rho}{2} \sum_{m < m^{\prime}} ( f_{X_m}(X_m) - f_{x_{m^{\prime}}} (X_{m^{\prime}})  )^2]
$$

For a hyperparameter $\rho \geq 0$. The first term of the minimization is the usual prediction error (or could used other loss function), and the second being an agreement penalty term.

### DIABLO

DIABLO stands for Data Integration Analysis for Biomarker discovery using Latent cOmponents. It extends sGCCA [cite] to a supervised setting. 

Denote $Q$ normalized, centered and scaled datasets $X^{(1)}, X^{(2)}, \dots, X^{(Q)}$ such each dataset measures expression levels of $P_1, \dots, P_Q$ omics variables on same $N$ samples, then sGCCA solves the optimization function for each dimension $h = 1, \ldots, H$:

$$
\begin{aligned}
\underset{\mathbf{a}_h^{(1)}, \ldots, \mathbf{a}_h^{(Q)}}{\text{maximize}} & \quad \sum_{i,j=1, i \neq j}^{Q} c_{i,j}   \text{cov}(\mathbf{X}_h^{(i)} \mathbf{a}_h^{(i)}, \mathbf{X}_h^{(j)} \mathbf{a}_h^{(j)})  \\
\text{subject to} & \quad  \|\mathbf{a}_h^{(q)}\|_2 = 1, \text{and} \|\mathbf{a}_h^{(q)}\|_1 \leq \lambda^{(q)} \quad \text{for all} \quad 1 \leq q \leq Q
\end{aligned}
$$

Where:

- $a_h^{(q)}$ is loading vector on dimension $h$ associated to residual matrix $X_h^{(q)}$ of dataset $X^{q}$

- $C = \{c_{i,j}\}_{i,j}$ is a $Q \times Q$ design matrix of connection between datasets

- $\lambda^{(q)}$ is a non-negative parameter that controls amount of shrinkage, ultimately number of non-zero coefficients in $a_h^{(q)}$.


Then DIABLO extends the above optimization further by substituting one omics dataset $X^{(q)}$ in above problem with a dummy indicator matrix $Y$ of $N \times G$ dimension to indicate class membership of each sample, and $G$ is number of phenotype or class groups.


### MOFA

MOFA is Multi-Omics Factor Analysis. It can viewed as a generalization of principal component analysis to multi-omics data. Starting from $M$ data matrices $Y^1, Y^M$ of dimensions $N \times D_m$, where $N$ is number of samples and $D_m$ the number of features in data matrix $m$, MOFA decomposes these matrices as:

$$
\begin{aligned}
Y^M = ZW^{mT} + \epsilon^m \quad m = 1, \dots, M
\end{aligned}
$$

Here, $Z$ denotes a common factor matrix for all data matrices representing low-dimensional latent variables and $W^m$ as the weight matrices for each data matrix $m$. And, $\epsilon^m$ being the omic-specific residual noise term, and has different choices of noise model with most frequently used Gaussian noise.

MOFA uses variational inference for model fitting and includes automatic relevance determination to promote sparsity in $W^m$. It supports missing values, making it robust for real-world multi-omics datasets with incomplete measurements.

Due to the fact that MOFA is unsupervised, hence we fit an additional glmnet [cite] model on the $Z$ factor matrix from MOFA and predict the classes. 

### MOGONET

MOGONET is named as Multi-Omics Graph cOnvolutional NETworks. It combines graph convolutional network (GCN) for omics specific learning and passed through a view Correlation Discovery Network(VCDN) for multi-omics integration.

A different GCN is trained for each omics data type.  The loss function for $i$ th omics data type $\text{GCN}_i$ is the following:

$$
L^{i}_{\text{GCN}} = \sum_{j=1}^{n_{tr}} L_{CE} (\hat{y}^{(i)}, y_j) = \sum_{j=1}^{n_{tr}} -log(\frac{e^{\hat{y}^{(i)}y_j}}{\sum_k e^{\hat{y_{j,k}}^{(i)}}} )
$$

where $L_{CE}(.)$ represents the cross entropy loss function, $y_j$ is one-hot encoded label of jth training sample, and $\hat{y}^{i}_{j,k}$ is kth element in vector $\hat{y}_j^{(i)}$

Furthermore, a VCDN is trained to integrate different omics type by constructing a cross-omics discovery tensor $C_j$. For data with $m$ omics data types, each element in $C_j$ can be calculated as:

$$
C_{j,a_1, a_2, \dots, a_m} = \prod_{i=1}^m \hat{y}^{(i)}_{j, a_i} , \quad a_i = 1,2,\dots,m
$$

where its loss function is:

$$
L_{VCDN} = \sum_{j=1}^{n_{tr}} L_{CE} (VCDN (c_j), y_j)
$$

In summary the total loss function of MOGONET could then be summarized as:

$$
L = \sum_{i=1}^{m=} L_{GCN}^{i} + \gamma L_{VCDN}
$$

where $m$ is number of omics, and $\gamma$ is a trade-off parameter between omics-specific classification loss and final classification loss from VCDN. 


### RGCCA

RGCCA is Regularized Generalized Canonical Correlation Analysis. Considering $J$ data matrices $X_1, \dots, X_J$, each $n \times p_j$ data matrix $X_j=[X_{j1}, \dots, X_{j_{p_j}}]$ is treated as block. Each block represents set of $p_j$ variables observed on $n$ individuals. A core criteria is that individuals has to match across blocks, where number of variables could differ from one to another.  Furthermore, all variables are assumed to be centered.


RGCCA aims to solve the following optimization problem:

$$
\begin{aligned}
\underset{\mathbf{a}_1, \ldots, \mathbf{a}_J}{\text{maximize}} & \quad \sum_{j=1}^{J} \sum_{k=1}^{J} c_{jk} \cdot g\left( \text{cov}(\mathbf{X}_j \mathbf{a}_j, \mathbf{X}_k \mathbf{a}_k) \right) \\
\text{subject to} & \quad (1 - \tau_j) \cdot \text{var}(\mathbf{X}_j \mathbf{a}_j) + \tau_j \cdot \|\mathbf{a}_j\|_2^2 = 1, \quad \text{for } j = 1, \ldots, J
\end{aligned}
$$

where

- $C_{jk}$ are elements of the design matrix , indicating the connections between blocks
- $g$ is a continuous convex scheme function applied to the covariance between block components, allowing different optimization criteria like max of sum of covariances or max of sum of absolute values covariances, etc.
- $\tau_j$ are shrinkage or regularization parameters ranging from 0 to 1. 
  - $\tau_j = 1$ yields maximization of covariance-based criterion, where variance of blocks dominates over correlation
  - $\tau_j = 0$ yields maximization of correlation-based criterion, where correlation of connected components is maximized
  - $0 < \tau_j  < 1$ is a compromise between variance and correlation of the block components

This formulation aims to find weight vectors $a_j$ that maximize the sum of pairwise covariances (or other measures, depending on the choice of $g$) between the projected block components $X_ja_j$


## Evaluation

To evaluate the classification tasks, we used standard metrics as described in [cite]. All dataset in this study involve binary classification problems, where the response variable represents categories such as *late-stage vs early-stage* cancer (e.g., in the TCGA setting) or *Alzheimer’s disease positive vs negative*. In each case, we let the minority class as the positive class. All methods are evaluated based on their ability to correctly predict the probability $P(\hat{Y} = 1)$ and to classify instances accordingly.

We report performance using the area under the receiver operating characteristic curve (AUC), accuracy, sensitivity, and specificity. AUC is particularly emphasized because it is threshold-independent and more appropriate for imbalanced dataset [cite], which are common in biological data. In addition, accuracy, sensitivity, and specificity are reported to assess how well methods identify true signal variables in simulated dataset where the ground truth is known.

\begin{table}[!h]
\centering
\caption{(\#tab:confusion-mat-tab)Confusion matrix of binary classification}
\centering
\begin{tabular}[t]{lll}
\toprule
  & Actual Positive & Actual Negative\\
\midrule
Predicted Positive & True Positive (TP) & False Negative (FN)\\
Predicted Negative & False Positive (FP) & True Negative (TN)\\
\bottomrule
\end{tabular}
\end{table}

From these values of table \@ref(tab:confusion-mat-tab), various performance metrics can then be calculated. All metrics except AUC requires a threshold, where we have set it invariant as usual $0.5$, i.e. if $P (\hat{Y}=1) \geq 0.5$, then $\hat{Y} = 1$, otherwise $\hat{Y} = 0$.

### Accuracy

Accuracy represents ratio between correctly predicted samples and total samples:

$$\text{Accuracy} = \frac{TP + TN}{TP+FP+TN+FN}$$

### Sensitivity (Recall / True Positive Rate)

Sensitivity quantifies proportion of actual positives correctly identified:

$$\text{Sensitivity} = \frac{TP}{TP + FN}$$

### Specificity (True Negative Rate)

Specificity measures the proportion of actual negatives correctly identified:

$$\text{Specificity} = \frac{TN}{TN + FP}$$

Furthermore, we could derive the False Positive Rate from specificity (TNR) as both are calculated based on negative classes, where $FPR + TNR = 1$:

$$FPR + TNR  = 1$$

$$FPR = 1 - TNR = \frac{FP}{FP + TN}$$

### Reiceiver Operating Characteristic (ROC) Curve

The ROC curve is plot of TPR on the y-axis against FPR x-axis at various classification thresholds.

The x-axis:

$$FPR(t) = \frac{FP(t)}{FP(t) + TN(t)} = 1 - \text{Specificity}(t)$$

The y-axis:

$$TPR(t) = \frac{TP(t)}{TP(t) + FN(t)} = \text{Sensitivity}(t)$$

These quantities are calculated at varying thresholds of $t \in [0, 1]$, where we classify $\hat{P}(Y=1) \geq t$ as positive.

### Area Under the ROC Curve (AUC)

AUC tells you how well a classifier separates the positive class from the negative class across all possible thresholds.


\newpage

# References

::: {#refs}
:::

# (APPENDIX) Appendix {.unnumbered}

<!-- # More information -->

<!-- This will be Appendix A. -->

<!-- This proposed pipeline ensures full reproducibility of any method by using an independent container environment with Singularity [@kurtzer2017singularity]. We propose to publish this pipeline on the nf-core [@ewels2020nf] platform, a community of Nextflow users, to ensure easy access and usability for researchers worldwide. 


Currently, we are benchmarking existing methods like DIABLO [@singh2019diablo], Cooperative Learning [@ding2022cooperative], MOGONET [@wang2021mogonet], RGCCA [@girka2023multiblock], MOFA [@Argelaguet2018; @Argelaguet2020] . The current pipeline focuses on testing this selection of integrative methods against a series of real multiomics datasets, particularly for classification tasks.

The results are compared using metrics like balanced classification error, F1 score, and biological enrichment results.

Regarding classification performance, we employed the area under the curve (AUC) score for method comparison across datasets (Fig 1B). Mogonet emerged as the weakest performer, with MOFA + glmnet showing only marginal improvement. In contrast, Cooperative Learning demonstrated the highest performance, followed by DIABLO and RGCCA. Interestingly, DIABLO with a null design outperformed than its full design choice. Nevertheless, all methods performed poorly on the tcga-thca dataset.




Through MESSI, we could systematically identify the top-performing methods with respect to classification performance and identifying molecular drivers of disease. Furthermore, this could extend to regression tasks or clustering tasks. This project can greatly benefit the community, either by developing new methods to assess their strength or finding a method that best suits custom multiomics data.

-->


<!-- # One more thing -->

<!-- This will be Appendix B. -->
