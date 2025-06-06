## MESSI pipeline

```{r another-setup}
# DELETE LATER
knitr::opts_chunk$set(eval=T)
```

We introduce here the MESSI pipeline, *Multiple Experiments with SyStematic Interrogation* (Fig \@ref(fig:messi-workflow-plot), and additional supplementary), comprising 4 main steps: 1) [Prepare data], 2) [Data splitting], 3) [Cross validation], 4) [Feature selection].

```{r messi-workflow-plot,fig.cap="Workflow design of MESSI for benchmarking integration methods with supervised setting. MESSI has a modular design between stages of preparing data, splitting data, cross validation (CV), and feature selection. The CV stage enables parallel computing of many methods implemented in different languages like R and Python seamleslly and reproducibly through independent containers.", fig.align="center",echo=FALSE, out.width="60%", eval=F}
knitr::include_graphics(here::here("docs/assets", "messi_workflow.png"))
```



MESSI is implemented with Nextflow [@di2017nextflow], a domain specific language (DSL) primarily used by bioinformaticians. Compared to traditional workflow management systems like Snakemake [@koster2012snakemake] or GNU make [@stallman1988gnu], Nextflow breaks down complex workflows into modular components, and connect them with channels which determines the flow of pipeline. This feature allows us to customize each module, extending the pipeline to not only benchmark purposes but also multi-purpose usage. Additionally, This modular design enables rapid, efficient and reproducible way to test and maintain codebases.

Moreover, the core feature of Nextflow of using containerization for modules like Docker [@docker2020docker] and Singularity [@kurtzer2017singularity] solves the reproducibility issue in replicating papers. 
Each time the pipeline is executed, containers are created for each process defined in the workflows that constitute the pipeline. These containers follow same sets of operating system configurations, software versions of the desired computation performed. Hence, it fulfills reproducibility and portability of our results as each time we run these independently on its own encapsulated environment. 
In addition, Nextflow creates unique working directory for each process spawned via these containers, and having all writing I/O operations in this specified directory without modifying the original input files. This way, we dont accidentally overwrite the raw data or any important input file without knowing in the first place.
Furthermore, the independence between each process leads nature of parallelizable computations. This characteristic of the pipeline along with the resumability of re-executing interrupted or failed processes make debugging or changing computational settings for certain methods only atomic and simple. 
Ultimately, it reduces time complexity of dealing with large datasets or long runtime computations, compared to standard way of sequentially executing complex scripts.
In terms of interoperability, Nextflow is capable to run the pipeline on various computing platforms including and not limited to our own personal computer, mainstream high-performance computing clusters (HPC) like SLURM, PBS or popular cloud platforms like AWS and Google cloud without modifying code logics. 
This is enabled from resource and parameters configurations, making user to only worry about configurations to carry out and not the code logic itself. 


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


```{r one-method-flow-plot, fig.width=6, fig.height=5}
ggplot() +
  theme_bw()
```

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


### Pipeline output

The output directory of the pipeline includes numerous files and folders:

- `merge_selected_features`: folder for a combined result of feature selection for all methods and datasets csv and its log
- `nfcore_messi_benchmark`: folder of core contents depending on parameter `publish_relevant`, if true only final results like metrics and the final predicted results are kept. Otherwise, all intermediate results from methods are present here. 
- `parse_metadata`: folder containing high level metadata of datasets including its omic names, dataset dimensions.
- `pipeline_info`: folder containing workflow metatada like execution report, trace of resource usages, timeline, and a dag of connection of processes and workflows.



### Model Assessment

<!--- 
- Describe how to evaluate the methods, but full technical details refer to methods instead
--->

To showcase the usage of the pipeline and comprehensively assess the performances of these integration methods, simulated data were evaluated to test robustness of methods in different parameter settings Full mathematical details of the process of simulating data are provided under [Methods]. Furthermore, we then evaluated the methods on real world datasets retrieved from public source like GEO [cite here], and TCGA[ cite] at total of $14$ datasets as described in table \@ref(tab:benchmark-data-table).

```{r benchmark-data-table}
real_data_tbl <- data.table::fread(here("data/processed/real_dataset_metadata.csv")) %>%
  as_tibble()


select_cols <- c("dataset", "obs", "neg_class", "pos_class", "positive_prop", "omics_names", "var", "diseases")
tbl_col <-  c(
  "Dataset",
  "N",
  "Y=0",
  "Y=1",
  "Prop(Y = 1)",
  "Omic",
  "P",
  "Disease"
  )

# longer cols
real_data_tbl %>%
  dplyr::mutate(dataset = toupper(dataset)) %>%
  dplyr::rename(
    pos_class = pos_col,
    neg_class = neg_col
  ) %>%
  dplyr::select(all_of(select_cols)) %>%
  arrange(obs) %>%
  # Change ordering
  kbl(
    caption = "Overview of real datasets to benchmark",
    booktab = T,
    longtable = T,
    col.names = tbl_col,
    escape = T) %>%
  # Previously scale down
  kable_styling(latex_options = c("repeat_header"), full_width = F, font_size = 7) %>%
  column_spec(1, width = "0.75in") %>%
  column_spec(3:4, width = "0.7in") %>%
  # middle would not work if merging too many cells
  collapse_rows(valign = "bottom", longtable_clean_cut = F,
                latex_hline = "custom",
                custom_latex_hline = c(1, 3, 4)) %>%
  {.}
  #footnote(symbol = "Features represents number of predictors in invididual omics", footnote_as_chunk = T)
```


In the meantime, we have benchmarked $5$ methods: DIABLO [@singh2019diablo], Cooperative Learning [@ding2022cooperative], MOGONET [@wang2021mogonet], RGCCA [@girka2023multiblock], MOFA [@Argelaguet2018; @Argelaguet2020]. We proposed to evaluate more, with the available options described in table \@ref(tab:method-meta-table). 

<!--- add more here? -->

We haved used metrics like area under the curve (AUC), balanced accuracy, F1 score for classification performance with a 5-fold CV from the pipeline. This way, we could measure each method's performance in each dataset using these binary classification scores.

In terms of quality of feature selection, we applied different metrics to simulated and real datasets. For the simulated ones, we utilized sensitivity and specificity of predictors identified, as we have full control and knowledge on which predictors were noise , and those that are actual useful ones. For the real ones, we measure ranking of predictors in each data for every method, and then compute the spearman rank correlation of these methods to see which method tend to have similar ranking in terms of arranging important predictors.

In addition, we measured the computational time requirement of each method all the way from preprocessing its input data, training model, making prediction, and feature selection. Also, the memory usage of each of these processes were recorded. This way, we could compare methods not only through performance but also its costs to achieve good work via more computational time and more intensive memory usage.


## Simulation studies

We examined the methods on controlled setting of simulation studies with varying parameters like number of observations, number of predictors in each omics, proportion of signal and correlation between omics and fixed number omics at $3$. Each of these combination of paramters were replicated $3$ times to account for data variability.  

We noticed that as signal increases, method tend to perform better, ultimately its AUC score plateaus at 1 as ilustrated in Fig \@ref(fig:sim-perf-plot). 

This is expected, as more clear pattern exist in different groups (i.e. positive vs negative), labels are better and easier for methods to learn.  On the other hand, we also prove that when there's no signal present, method gives a median AUC of 0.5 , which means it turns out to be randomly guessing the response. This result is also trivial, as there's not clear difference between groups, hence hard to distinguish and models struggle to learn anything meaningful. 

With these simple facts, we have showed that simulations are setup correctly, and verified how machine learning works with labelled data.
Furthermore, we noticed that method given little signal, i.e. $\text{signal} = 1 > 0$, they all start to work well, quickly bumping its $0.5$ AUC to $0.7$. This have showed data with little variation provided it is clear difference among groups, current SOTA methods are capable to make reasonably well predictions. 
We also tested against varying correlation in the omics within each dataset. But, the role of correlation in this simulation is not depicted clearly and requires further understanding and exploration.

From this simulation for classification performance, DIABLO with different design matrices showed relatively good performance ranking at top. Cooperative Learning follows next with consistent distribution of AUC scores, and less variable compared to other methods. MOFA + glmnet and RGCCA + LDA are in the middle, with high variability. Lastly, MOGONET showed consistenly low performance compared to others and only performing well at no signal and full correlation between omics. 


```{r sim-perf-plot, echo=FALSE, out.width="70%", out.height="80%", eval=T, fig.cap="Classification performance of all simulated datasets. T"}
knitr::include_graphics(here(fig_path, "fig_performance_evaluation_sim.png"))
```

In terms of ability and quality of feature selection (Fig \@ref(fig:sim-feat-sel-plot)), only Cooperative Learning showed consistent behavior and choosing those meaningful biomarkers out compared to other methods. DIABLO is slightly behind it, and with higher variability at the sensitivity distribution. All other methods performed poorly, since they're quite unstable and could have any performance. 


```{r sim-feat-sel-plot, fig.cap="Simulation studies feature selection sensitivity performance", echo=FALSE, out.width="96%"}
knitr::include_graphics(here(fig_path, "fig_feature_selection_sim.png"))
```


We believe these sets of simulation studies could be used for future method development, and test them against various scenarios of multiomics data. More parameters could be involved to rigorously test method's robustness. This could be achieved with ease with our proposed pipeline, as we need is to setup the correct data and rest is just handled by these fixed and reproducible workflows.


### Real dataset classification performances

After evaluating the pipeline with simulation studies, we then proceed to execute it with real world datasets as describe in table \@ref(tab:benchmark-data-table). The scripts to clean these data could be found under [insert link here...]. 


We noticed the AUC scores follows a similar pattern from the simulations, where most of the AUC fall around $0.7$ as per Fig \@ref(fig:real-perf-plot), this is exactly the case when we have little signal in the data. 
These real datasets that we evaluated are mostly carnicoma cohorts from TCGA, where usually we have fewer observations in later stage carnicoma, and its molecular measurement are not much different with those early stage, i.e. stageii vs stageiii. Furthermore, we have datasets that have near $0.5$, this could indicate low signal present in those datasets. 

In terms of performance ranking, DIABLO still perform at top compared to other methods, where its variant with null design matrix beats performance with full design matrix. This design matrix represents connection or correlation between the omics inside the data. Similar to our simulations, Cooperative Learning follows after DIABLO. Although this time, there are competitions between rest models where all perform moderately. Arguably, one of MOFA + glmnet or MOGONET perform as weakest. 

From here, we verified that there's no such method that could perform well in all possible scenarios, it could be top in certain dataset, but it could also be weakest in some specific dataset, i.e Cooperative Learning has best overall high AUC, but it struglles particularly in the TCGA-STES dataset that studies stomach and esophageal carcinoma. This might be due to the limited sample size of this dataset with only $25$ observations.
Therefore, we prove the pipeline provides an easy way to benchmark multiomics integration methods in purely data-driven approach, and could quickly compare large set of methods at once, and targeting possible candidate method that suits user custom data the most. This way, researcher won't have to figure out setting environments to test certain method against their data, and save their time by fitering out methods that are not best suit to their needs.



```{r real-perf-plot, fig.cap="Heatmap of mean AUC from 5 fold-cv", echo=FALSE, out.width="96%"}
knitr::include_graphics(here(fig_path, "fig_performance_evaluation_real.png"))
```



<!--
```{r sim-grid-plot, fig.cap="Simulation studies on signal, correlation, number of samples and number of predictors", echo=FALSE, out.width="96%"}
#include_graphics(here(fig_path, "fig_sim_grid.png"))
```
--->


## Feature selection performance

We further investigated each method's ability to identify significant biomarkers and examined the overlap between them, calculating the ranking similarity of in their feature sets at Fig \@ref(fig:real-feat-sel-plot). DIABLO-null and RGCCA have high spearson rank correlation of $0.76$, which indicates that their rankings on the important predictors are very similar to each other. 
This could be due the fact that they're both using canonical correlation analysis, which aims to solve a maximization problem of covariance between omics, for more details see [Methods]. In addition, DIABLO-full showed high correlation with MOFA + glmnet of $0.73$, despite being the same DIABLO method but a different design could mean a very distinct model. This time, they are similar because of ....
Rest methods, Cooperative Learning relates with both DIABLO-null and MOGONET, where the first showed near $0.5$ correlation, but the latter of $0.24$ only.

ADD ON HERE?

```{r real-feat-sel-plot, fig.cap="Feature selection result", out.width="95%"}
knitr::include_graphics(here(fig_path, "fig_feature_selection_real.png"))
```

## Biological Relevance Interpretation

To enhance biological relevance of these datasets, we examined FGSEA [insert citation] on all the datasets + method combination separately after the pipeline at Fig
\@ref(fig:fgsea-analysis-plot)

```{r fgsea-analysis-plot, fig.cap="FGSEA Analysis", out.width="92%"}
knitr::include_graphics(here(fig_path, "fig_fgsea_analysis_two_panels.png"))
```

## Computational time

We observed notable variations in the computation time of most methods with changing dataset sizes (categorized as small if the size of dataset is less than median of all), while DIABLO exhibited consistent performance regardless of dataset size. Conversely, Cooperative Learning displayed a comparatively longer median time than other methods. (Fig 1A).




```{=html}
<!---
Fig1. Benchmark results of multiomics data and integration methods. (A) Computation time for each multiomics method of varying data size. (B) Classification performances by area under the curve of method and dataset combination. (C) Similarity in feature selection between methods and datasets.
---->
```
```{r real-grid-plot, fig.cap="Benchmark results on real datasets.", echo=FALSE, out.width="92%"}
#include_graphics(here(fig_path, "fig_real_grid.png"))
```

