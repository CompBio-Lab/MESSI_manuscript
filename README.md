# MESSI Figures repository

This repository contains scripts and sample data file to generate the figures for the MESSI project.

Tony Liang


For these tables and figures, should have a link to the script file

## Tables

1. Table of describing datasets characteristics
  - See this [paper here](https://www.nature.com/articles/s41592-024-02429-w/figures/1)

2. Table of describing methods capability
  - Reproduceable or not
  - Accept custom data or not
  - Accept n modalities or not
  - ...

3. Table of simulation strategies, and show varieties of range of grids, and their outcomes


## Figures

1. Figure 1. Benchmarking overview
  - Nextflow pipeline
  - Number of datasets (simulated, real)
  - Number of methods (grouping of related methods)
  - Metrics (auc, f1 scores)
  - comparison of identified biology (geneset enrichment)
  - Insert [link here](./README.md)


2. Figure 2 Simulated data performance
  - A. Time ~ method stratified by simulated data (vary n, p)
  - B. Error rates method stratified by simulated data (vary n, p, signal, noise)
  - C. Plot proportion of correctly identified features

3. Figure 3 Real data performance
  - A: error rates ~ method stratified by real dataset (classification, regression)
  - B: number of features selected
  - C. overlap between methods
  - D. biological enrichment and overlap

