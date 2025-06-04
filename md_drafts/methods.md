<!-----

Methods section, main level 1 header is in a parent file

----->
## Dataset

We consider multiomics datasetes represented by $P$ omics matrices $X_i$ , where $X_i$ is of dimension $n \times p_i$ ($n$ samples and $p_i$ features) for $i = 1, \dots, P$. 


The real datasets were retrieved from public sources like TCGA and GEO...

The real datasets were filtered based on criterias like matched samples (same subjects measured in different omics modalities), not near zero variance with omic measurement. These filtering steps were carried in custom R scripts before and within the pipeline execution.

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

The process of simulation was based on the paper [@tenenhaus2014variable] and slightly modified, and the code to generate such data is contained in a R package accessed through GitHub.

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

We varied a number of samples, number of predictors, correlation between omics, pc mean to study a variety of simulation scenarios. Each scenario is replicated 3 times and evaluated for all the methods.

The original technical details of evaluated integration methods can be found in publications [ @singh2019diablo, @ding2022cooperative, @wang2021mogonet, @girka2023multiblock,  @Argelaguet2018; @Argelaguet2020 ]. Here, we will quickly summarize key components of each method.

### DIABLO

DIABLO is ...

### Multiview

Multiview is ...

### MOFA

MOFA is ...

### MOGONET

MOGONET is ...

### RGCCA

RGCCA is ...



### TODO

-   Explain what is the data input in mathematical form

-   Then introduce the integration methods used here

-   Each should have their unique characterisitic, and what problem it solves in math, with proper citation

-   Then on how data was simulated, hopefully add math details

-   Then explain what metrics to be used in both simulated data and real datasets

    -   Define what is TP, FP, FN, TN
    -   and the the actual formulas of the metrics


### Metric

First, defined the metrics used in benchmark analysis ...

-   TP: true positive

-   TN: true negative

-   FP: false positive

-   FN: false negative

wheras, it could be constructed to the following:

$$\text{accuracy} = \frac{TP + TN}{TP +TN + FP +FN}$$


