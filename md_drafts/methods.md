<!-----

Methods section, main level 1 header is in a parent file

----->
## Dataset

We consider multiomics datasetes represented by $P$ omics matrices $X_i$ , where $X_i$ is of dimension $n \times p_i$ ($n$ samples and $p_i$ features) for $i = 1, \dots, P$. 


The real datasets were retrieved from public sources like TCGA [ [citation here] ](citation)  [ [citaiton here] ](citation) with R 4.3.3 and libraries TCGAbiolinks 2.30.4 and GEOquery 2.70.0.
These datasets were furthered processed to keep matched samples data only (same subjects measured in different omics modalities)

Furthermore, they are filtered for omics with non zero variance during the pipeline execution, as certain methods would not work if zero variance data was present.

For a summarized list of real datasets, please refer to table [ [cite the dataset table]](cite). Below we present higher level information of datasets studied in this paper.

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

We varied a number of samples, number of predictors, correlation between omics, pc mean, and fixed number of omics to study a variety of simulation scenarios. Each scenario is replicated 3 times and evaluated for all the methods.

## Integration methods algorithms

The original technical details of evaluated integration methods can be found in publications [ @singh2019diablo, @ding2022cooperative, @wang2021mogonet, @girka2023multiblock,  @Argelaguet2018; @Argelaguet2020 ]. Here, we will quickly summarize key components of each method.

### DIABLO

DIABLO stands for Data Integration Analysis for Biomarker discovery using Latent cOmponents. It extends sGCCA [cite] to a supervised setting. 

Denote $Q$ normalized, centered and scaled datasets $X^{(1)}, X^{(2)}, \dots, X^{(Q)}$ such each dataset measures expression levels of $P_1, \dots, P_Q$ omics variables on same $N$ samples, then sGCCA solves the optimization function for each dimension $h = 1, \ldots, H$:

```math
\begin{aligned}
\underset{\mathbf{a}_h^{(1)}, \ldots, \mathbf{a}_h^{(Q)}}{\text{maximize}} & \quad \sum_{i,j=1, i \neq j}^{Q} c_{i,j}   \text{cov}(\mathbf{X}_h^{(i)} \mathbf{a}_h^{(i)}, \mathbf{X}_h^{(j)} \mathbf{a}_h^{(j)})  \\
\text{subject to} & \quad  \|\mathbf{a}_h^{(q)}\|_2 = 1, \text{and} \|\mathbf{a}_h^{(q)}\|_1 \leq \lambda^{(q)} \quad \text{for all} \quad 1 \leq q \leq Q
\end{aligned}
```
Where:

- $a_h^{(q)}$ is loading vector on dimension $h$ associated to residual matrix $X_h^{(q)}$ of dataset $X^{q}$

- $C = \{c_{i,j}\}_{i,j}$ is a $Q \times Q$ design matrix of connection between datasets

- $\lambda^{(q)}$ is a non-negative parameter that controls amount of shrinkage, ultimately number of non-zero coefficients in $a_h^{(q)}$.


Then DIABLO extends the above optimization further by substituting one omics dataset $X^{(q)}$ in above problem with a dummy indicator matrix $Y$ of $N \times G$ dimension to indicate class membership of each sample, and $G$ is number of phenotype or class groups.


### Cooperative Learning

Cooperative Learning is implemeneted in R with package name `multiview`. It is a supervised learning framework that integrates multiple data modalities (views) by joinly minizing prediction error while encouraging agreement across $M$ views with the following optimization problem:

```math
\text{min} E[\frac{1}{2}(y - \sum_{m=1}^M f_{X_m} (X_m))^2 + \frac{\rho}{2} \sum_{m < m^{\prime}} ( f_{X_m}(X_m) - f_{x_{m^{\prime}}} (X_{m^{\prime}})  )^2]

``` 

For a hyperparameter $\rho \geq 0$. The first term of the minimization is the usual prediction error (or could used other loss function), and the second being an agreement penalty term.


### MOFA

MOFA is Multi-Omics Factor Analysis. It can viewed as a generalization of principal component analysis to multi-omics data. Starting from $M$ data matrices $Y^1, Y^M$ of dimensions $N \times D_m$, where $N$ is number of samples and $D_m$ the number of features in data matrix $m$, MOFA decomposes these matrices as:

```math
\begin{aligned}
Y^M = ZW^{mT} + \epsilon^m \quad m = 1, \dots, M
\end{aligned}
```

Here, $Z$ denotes a common factor matrix for all data matrices representing low-dimensional latent variables and $W^m$ as the weight matrices for each data matrix $m$. And, $\epsilon^m$ being the omic-specific residual noise term, and has different choices of noise model with most frequently used Gaussian noise.

MOFA uses variational inference for model fitting and includes automatic relevance determination to promote sparsity in $W^m$. It supports missing values, making it robust for real-world multi-omics datasets with incomplete measurements.

Due to the fact that MOFA is unsupervised, hence we fit an additional glmnet [cite] model on the $Z$ factor matrix from MOFA and predict the classes. 

### MOGONET

MOGONET is named as Multi-Omics Graph cOnvolutional NETworks. It combines graph convolutional network (GCN) for omics specific learning and passed through a view Correlation Discovery Network(VCDN) for multi-omics integration.

A different GCN is trained for each omics data type.  The loss function for $i$ th omics data type $\text{GCN}_i$ is the following:

```math
L^{i}_{\text{GCN}} = \sum_{j=1}^{n_{tr}} L_{CE} (\hat{y}^{(i)}, y_j) = \sum_{j=1}^{n_{tr}} -log(\frac{e^{\hat{y}^{(i)}y_j}}{\sum_k e^{\hat{y_{j,k}}^{(i)}}} )
```

where $L_{CE}(.)$ represents the cross entropy loss function, $y_j$ is one-hot encoded label of jth training sample, and $\hat{y}^{i}_{j,k}$ is kth element in vector $\hat{y}_j^{(i)}$

Furthermore, a VCDN is trained to integrate different omics type by constructing a cross-omics discovery tensor $C_j$. For data with $m$ omics data types, each element in $C_j$ can be calculated as:

```math
C_{j,a_1, a_2, \dots, a_m} = \prod_{i=1}^m \hat{y}^{(i)}_{j, a_i} , \quad a_i = 1,2,\dots,m
```

where its loss function is:

```math
L_{VCDN} = \sum_{j=1}^{n_{tr}} L_{CE} (VCDN (c_j), y_j)
```

In summary the total loss function of MOGONET could then be summarized as:

```math
L = \sum_{i=1}^{m=} L_{GCN}^{i} + \gamma L_{VCDN}
```

where $m$ is number of omics, and $\gamma$ is a trade-off parameter between omics-specific classification loss and final classification loss from VCDN. 


### RGCCA

RGCCA is Regularized Generalized Canonical Correlation Analysis. Considering $J$ data matrices $X_1, \dots, X_J$, each $n \times p_j$ data matrix $X_j=[X_{j1}, \dots, X_{j_{p_j}}]$ is treated as block. Each block represents set of $p_j$ variables observed on $n$ individuals. A core criteria is that individuals has to match across blocks, where number of variables could differ from one to another.  Furthermore, all variables are assumed to be centered.


RGCCA aims to solve the following optimization problem:

```math
\begin{aligned}
\underset{\mathbf{a}_1, \ldots, \mathbf{a}_J}{\text{maximize}} & \quad \sum_{j=1}^{J} \sum_{k=1}^{J} c_{jk} \cdot g\left( \text{cov}(\mathbf{X}_j \mathbf{a}_j, \mathbf{X}_k \mathbf{a}_k) \right) \\
\text{subject to} & \quad (1 - \tau_j) \cdot \text{var}(\mathbf{X}_j \mathbf{a}_j) + \tau_j \cdot \|\mathbf{a}_j\|_2^2 = 1, \quad \text{for } j = 1, \ldots, J
\end{aligned}
```

where

- $C_{jk}$ are elements of the design matrix , indicating the connections between blocks
- $g$ is a continous convex scheme function applied to the covariance between block components, allowing different optimization criteria like max of sum of covariances or max of sum of absolute values covariances, etc.
- $\tau_j$ are shrinkage or regularization parameters ranging from 0 to 1. 
  - $\tau_j = 1$ yields maximization of covariance-based criterion, where variance of blocks dominates over correlation
  - $\tau_j = 0$ yields maximization of correlation-based criterion, where correlation of connected components is maximized
  - $0 < \tau_j  < 1$ is a compromise between variance and correlation of the block components

This formulation aims to find weight vectors $a_j$ that maximize the sum of pairwise covariances (or other measures, depending on the choice of $g$) between the projected block components $X_ja_j$

## Evaluation

To evaluate the tasks


First, defined the metrics used in benchmark analysis ...

-   TP: true positive

-   TN: true negative

-   FP: false positive

-   FN: false negative

wheras, it could be constructed to the following:

$$\text{accuracy} = \frac{TP + TN}{TP +TN + FP +FN}$$


