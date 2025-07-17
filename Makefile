# ===============================================================================
# Makefile for MESSI figures
# This Makefile is used to automate the process of generating figures and tables
# for the MESSI project. It includes preprocessing, plotting, and generating
# the final report.
# Author: Tony Liang
# Date: 2024-06-22
# ===============================================================================
# Important variables
# ===============================================================================
# Plotting params
WIDTH=7
HEIGHT=7
DEVICE=png # default is png
DPI=700 # default is 300
SHOW_TITLE=1 # 1 for show title, 0 for disable it

# ==========================================================================
# Data has raw dir and processed
DATA_DIR=data
DATA_RAW_DIR=${DATA_DIR}/raw
REAL_DATA_DIR=${DATA_RAW_DIR}/real_data_results
SIM_DATA_DIR=${DATA_RAW_DIR}/simulated_data_results
FGSEA_RESULT_DIR=${DATA_RAW_DIR}/fgsea_results
DATA_PROCESSED_DIR=${DATA_DIR}/processed
RAW_GZ=${DATA_RAW_DIR}/results.tar.gz
SRC_DIR=src
# Similarly results could have figures and other files
OUTPUT_DIR=results
FIG_DIR=results/figures
KEEP='.gitkeep'
BANNER="======================================================================="

# ==============================================================================

# Input data files
# Real data
REAL_METRICS_CSV=${REAL_DATA_DIR}/metrics.csv
REAL_METADATA_CSV=${REAL_DATA_DIR}/parsed_metadata.csv
REAL_TRACE_TXT=${REAL_DATA_DIR}/execution_trace.txt
REAL_FS_RESULTS_CSV=${REAL_DATA_DIR}/all_feature_selection_results.csv
# FGSEA analysis files
FGSEA_PART1_DIR=${FGSEA_RESULT_DIR}/fgsea_part1
FGSEA_PART2_DIR=${FGSEA_RESULT_DIR}/fgsea_part2


# Simulated data
SIM_METRICS_CSV=${SIM_DATA_DIR}/metrics.csv
SIM_METADATA_CSV=${SIM_DATA_DIR}/parsed_metadata.csv
SIM_TRACE_TXT=${SIM_DATA_DIR}/execution_trace.txt
SIM_FS_RESULTS_CSV=${SIM_DATA_DIR}/all_feature_selection_results.csv

# Processed file names
# Performance evaluation
FIG1_REAL_PROCESSED=${DATA_PROCESSED_DIR}/fig_performance_evaluation_real_plot_data.rds
FIG1_SIM_PROCESSED=${DATA_PROCESSED_DIR}/fig_performance_evaluation_sim_plot_data.rds

# Computational time
FIG2_REAL_PROCESSED=${DATA_PROCESSED_DIR}/fig_computational_time_real_plot_data.csv
FIG2_SIM_PROCESSED=${DATA_PROCESSED_DIR}/fig_computational_time_sim_plot_data.csv

# Feature selection
FIG3_REAL_PROCESSED=${DATA_PROCESSED_DIR}/fig_feature_selection_real_plot_data.rds
FIG3_SIM_PROCESSED=${DATA_PROCESSED_DIR}/fig_feature_selection_sim_plot_data.rds

# Common R utilities
COMMON_R=${SRC_DIR}/_utils.R

# Figure source directories (contain scripts for generating figures)
# Scripts for performance evaluation figure
FIG1_SRC_DIR=${SRC_DIR}/fig_performance_evaluation
# Scripts for computational time figure
FIG2_SRC_DIR=${SRC_DIR}/fig_computational_time
# Scripts for feature selection figure
FIG3_SRC_DIR=${SRC_DIR}/fig_feature_selection
# Scripts for fgsea analysis figure
FIG4_SRC_DIR=${SRC_DIR}/fig_fgsea_analysis

# Cleaning scripts (for preprocessing data)
# Scripts to clean/preprocess performance evaluation data
FIG1_WRANGLE_REAL_SRC=${FIG1_SRC_DIR}/real/clean_real.R
FIG1_WRANGLE_SIM_SRC=${FIG1_SRC_DIR}/sim/clean_sim.R
# Scripts to clean/preprocess computational time data
FIG2_WRANGLE_REAL_SRC=${FIG2_SRC_DIR}/real/clean_real.R
FIG2_WRANGLE_SIM_SRC=${FIG2_SRC_DIR}/sim/clean_sim.R
# Scripts to clean/preprocess feature selection data
FIG3_WRANGLE_REAL_SRC=${FIG3_SRC_DIR}/real/clean_real.R
FIG3_WRANGLE_SIM_SRC=${FIG3_SRC_DIR}/sim/clean_sim.R

# Plotting scripts (for generating figures)
# Scripts to plot performance evaluation figure
FIG1_PLOT_REAL_SRC=${FIG1_SRC_DIR}/real/plot_real.R
FIG1_PLOT_SIM_SRC=${FIG1_SRC_DIR}/sim/plot_sim.R
# Scripts to plot computational time figure
FIG2_PLOT_REAL_SRC=${FIG2_SRC_DIR}/real/plot_real.R
FIG2_PLOT_SIM_SRC=${FIG2_SRC_DIR}/sim/plot_sim.R
# Scripts to plot feature selection figure
FIG3_PLOT_REAL_SRC=${FIG3_SRC_DIR}/real/plot_real.R
FIG3_PLOT_SIM_SRC=${FIG3_SRC_DIR}/sim/plot_sim.R

# Figure output names
# Performance evaluation
FIG_REAL_PERF_OUT=${FIG_DIR}/fig_performance_evaluation_real.${DEVICE}
FIG_SIM_PERF_OUT=${FIG_DIR}/fig_performance_evaluation_sim.${DEVICE}

# Computational time
FIG_REAL_TIME_OUT=${FIG_DIR}/fig_computational_time_real.${DEVICE}
FIG_SIM_TIME_OUT=${FIG_DIR}/fig_computational_time_sim.${DEVICE}

# Feature selection
FIG_REAL_FS_OUT=${FIG_DIR}/fig_feature_selection_real.${DEVICE}
FIG_SIM_FS_SENSITIVITY=${FIG_DIR}/fig_feature_selection_sim_sensitivity.${DEVICE}
FIG_SIM_FS_SPECIFICITY=${FIG_DIR}/fig_feature_selection_sim_specificity.${DEVICE}

# FGSEA analysis
FIG_FGSEA_OUT=${FIG_DIR}/fig_fgsea_analysis_two_panels.${DEVICE}

# ================================================
# TABLES
TABLE_METHOD=${DATA_PROCESSED_DIR}/method_metadata.csv
TABLE_DATASET=${DATA_PROCESSED_DIR}/real_dataset_metadata.csv

# ====================================================================================
# All the outputs
# Real data targets are always included


TABLE_OUTPUTS=${TABLE_METHOD} ${TABLE_DATASET}

OUTPUTS=${FIG_REAL_PERF_OUT} ${TABLE_METHOD} ${TABLE_DATASET} ${FIG_FGSEA_OUT}
#${FIG_REAL_TIME_OUT}
#${FIG_REAL_FS_OUT} ${TABLE_METHOD} ${TABLE_DATASET}
# Conditionally include simulated data targets if input files exist
ifneq ($(wildcard ${SIM_METRICS_CSV}),)
OUTPUTS+= ${FIG_SIM_PERF_OUT}
endif
#ifneq ($(wildcard ${SIM_METADATA_CSV}),)
#OUTPUTS+= ${FIG_SIM_TIME_OUT}
#endif
ifneq ($(wildcard ${SIM_FS_RESULTS_CSV}),)
OUTPUTS+= ${FIG_SIM_FS_SENSITIVITY} ${FIG_SIM_FS_SPECIFICITY}
endif

# The report file containing the figures
REPORT_SRC=docs/report.Rmd
REPORT_PDF=docs/report.pdf

# The report depends on the outputs files
${REPORT_PDF}: ${OUTPUTS} ${REPORT_SRC} docs/sections/background.Rmd docs/sections/methods.Rmd docs/sections/results.Rmd
	@echo "==========================================="
	@echo "Rendering report now..."
	Rscript -e 'rmarkdown::render("${REPORT_SRC}")'
	@echo "==========================================="

.PHONY: clean all

# all: ${OUTPUTS} ${REPORT_PDF}
# 	@echo "All targets complete!"
all: ${OUTPUTS}
	@echo "==========================================="
	@echo "Running all targets..."
	@echo "==========================================="
	# Measure time taken to run all targets
	# Using $$ to ensure the date command is executed in the shell
	# and not in the Makefile context
	# This allows us to capture the start time correctly
	@start=$$(date +%s); \
	echo "Running all targets..."; \
	$(MAKE) ${OUTPUTS}; \
	end=$$(date +%s); \
	elapsed=$$((end - start)); \
	echo "All targets complete!"; \
	echo "Total time elapsed: $$(date -u -d @$$elapsed +%M:%S) (mm:ss)"

clean: clean_figures clean_data

clean_figures:
	@echo "Cleaning files in ${FIG_DIR} ..."
	@find ${FIG_DIR} ! -name ${KEEP} -type f -exec rm -f {} +

clean_data:
	@echo "Cleaning file in ${DATA_PROCESSED_DIR} ..."
	@find ${DATA_PROCESSED_DIR} ! -name ${KEEP} -type f -exec rm -f {} +

# ==============================================================================
# PREPROCESSING
# Common util for Performance evaluation util
PERF_UTIL=${FIG1_SRC_DIR}/_performance_evaluation_utils.R

# Figure 1: Performance evaluation (Real Data)
${FIG1_REAL_PROCESSED}: ${FIG1_WRANGLE_REAL_SRC} ${COMMON_R} ${REAL_METRICS_CSV} ${PERF_UTIL}
	@echo ${BANNER}
	@echo "Processing real data for performance evaluation"
	Rscript ${FIG1_WRANGLE_REAL_SRC} \
		--input_csv ${REAL_METRICS_CSV} \
		--output_path ${FIG1_REAL_PROCESSED}

# Figure 1: Performance evaluation (Simulated Data)
${FIG1_SIM_PROCESSED}: ${FIG1_WRANGLE_SIM_SRC} ${COMMON_R} ${SIM_METRICS_CSV} ${PERF_UTIL}
	@echo ${BANNER}
	@echo "Processing simulated data for performance evaluation"
	Rscript ${FIG1_WRANGLE_SIM_SRC} \
		--input_csv ${SIM_METRICS_CSV} \
		--output_path ${FIG1_SIM_PROCESSED}

# Figure 2: Computational time (Real Data)
#${FIG2_REAL_PROCESSED}: ${FIG2_WRANGLE_REAL_SRC} ${COMMON_R} ${REAL_METADATA_CSV} ${REAL_TRACE_TXT}
#	@echo ${BANNER}
#	@echo "Processing real data for computational time"
#	Rscript ${FIG2_WRANGLE_REAL_SRC} \
#		--metadata ${REAL_METADATA_CSV} \
#		--trace ${REAL_TRACE_TXT} \
#		--output_csv ${FIG2_REAL_PROCESSED}

# Figure 2: Computational time (Simulated Data)
#${FIG2_SIM_PROCESSED}: ${FIG2_WRANGLE_SIM_SRC} ${COMMON_R} ${SIM_METADATA_CSV} ${SIM_TRACE_TXT}
#	@echo ${BANNER}
#	@echo "Processing simulated data for computational time"
#	Rscript ${FIG2_WRANGLE_SIM_SRC} \
#		--metadata ${SIM_METADATA_CSV} \
#		--trace ${SIM_TRACE_TXT} \
#		--output_csv ${FIG2_SIM_PROCESSED}

# Figure 3: Feature selection (Real Data)
${FIG3_REAL_PROCESSED}: ${FIG3_WRANGLE_REAL_SRC} ${COMMON_R} ${REAL_FS_RESULTS_CSV}
	@echo ${BANNER}
	@echo "Processing real data for feature selection"
	Rscript ${FIG3_WRANGLE_REAL_SRC} \
		--input_csv ${REAL_FS_RESULTS_CSV} \
		--output_path ${FIG3_REAL_PROCESSED}

# Figure 3: Feature selection (Simulated Data)
${FIG3_SIM_PROCESSED}: ${FIG3_WRANGLE_SIM_SRC} ${COMMON_R} ${SIM_FS_RESULTS_CSV}
	@echo ${BANNER}
	@echo "Processing simulated data for feature selection"
	Rscript ${FIG3_WRANGLE_SIM_SRC} \
		--input_csv ${SIM_FS_RESULTS_CSV} \
		--output_path ${FIG3_SIM_PROCESSED}

# Figure 4: Preprocessing pathways



# ==============================================================================
# PLOTTING
# FIGURE 1: Performance evaluation (Real Data)
${FIG_REAL_PERF_OUT}: ${FIG1_PLOT_REAL_SRC} ${COMMON_R} ${FIG1_REAL_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting performance evaluation (Real Data)..."
	Rscript ${FIG1_PLOT_REAL_SRC} \
		--input_path ${FIG1_REAL_PROCESSED} \
		--output_path ${FIG_REAL_PERF_OUT} \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--show_title ${SHOW_TITLE}

# FIGURE 1: Performance evaluation (Simulated Data)
${FIG_SIM_PERF_OUT}: ${FIG1_PLOT_SIM_SRC} ${COMMON_R} ${FIG1_SIM_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting performance evaluation (Simulated Data)..."
	Rscript ${FIG1_PLOT_SIM_SRC} \
		--input_path ${FIG1_SIM_PROCESSED} \
		--output_path ${FIG_SIM_PERF_OUT} \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--show_title ${SHOW_TITLE}

# ==============================================================================
# FIGURE 2: Computational time (Real Data)
${FIG_REAL_TIME_OUT}: ${FIG2_PLOT_REAL_SRC} ${COMMON_R} ${FIG2_REAL_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting computational time (Real Data)..."
	Rscript ${FIG2_PLOT_REAL_SRC} \
		--input_path ${FIG2_REAL_PROCESSED} \
		--output_path ${FIG_REAL_TIME_OUT} \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--show_title ${SHOW_TITLE}

# FIGURE 2: Computational time (Simulated Data)
${FIG_SIM_TIME_OUT}: ${FIG2_PLOT_SIM_SRC} ${COMMON_R} ${FIG2_SIM_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting computational time (Simulated Data)..."
	Rscript ${FIG2_PLOT_SIM_SRC} \
		--input_path ${FIG2_SIM_PROCESSED} \
		--output_path ${FIG_SIM_TIME_OUT} \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--show_title ${SHOW_TITLE}

# ==============================================================================
# FIGURE 3: Feature selection (Real Data)
${FIG_REAL_FS_OUT}: ${FIG3_PLOT_REAL_SRC} ${COMMON_R} ${FIG3_REAL_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting feature selection (Real Data)..."
	Rscript ${FIG3_PLOT_REAL_SRC} \
		--input_path ${FIG3_REAL_PROCESSED} \
		--output_path ${FIG_REAL_FS_OUT} \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--show_title ${SHOW_TITLE}

# FIGURE 3: Feature selection (Simulated Data)

# Sensitivity plot
${FIG_SIM_FS_SENSITIVITY}: ${FIG3_PLOT_SIM_SRC} ${COMMON_R} ${FIG3_SIM_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting feature selection sensitivity (Simulated Data)..."
	Rscript ${FIG3_PLOT_SIM_SRC} \
		--input_path ${FIG3_SIM_PROCESSED} \
		--output_path ${FIG_SIM_FS_SENSITIVITY} \
		--metric sensitivity \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--show_title ${SHOW_TITLE}
# Specificity plot
${FIG_SIM_FS_SPECIFICITY}: ${FIG3_PLOT_SIM_SRC} ${COMMON_R} ${FIG3_SIM_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting feature selection specificity (Simulated Data)..."
	Rscript ${FIG3_PLOT_SIM_SRC} \
		--input_path ${FIG3_SIM_PROCESSED} \
		--output_path ${FIG_SIM_FS_SPECIFICITY} \
		--metric specificity \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--show_title ${SHOW_TITLE}

# ==============================================================================
# FGSEA ANALYSIS
CUTOFF=0.2 # Cutoff for filtering results in fgsea part 1 & 2

# Prepare feature selection data with gene symbols
FEATURE_SELECTION_WITH_SYMBOL=data/processed/feature_selection_with_symbol.csv
${FEATURE_SELECTION_WITH_SYMBOL}: src/fig_fgsea_analysis/prepare_feature_selection_with_symbol.R ${REAL_FS_RESULTS_CSV}
	@echo ${BANNER}
	@echo "Preparing feature selection data with gene symbols..."
	Rscript src/fig_fgsea_analysis/prepare_feature_selection_with_symbol.R \
		--input_path ${REAL_FS_RESULTS_CSV} \
		--output_path ${FEATURE_SELECTION_WITH_SYMBOL}

# Prepare the FGSEA inputs data (ranked gene lists) in batches of rds
FGSEA_INPUTS_DIR=data/batched_input_for_fgsea
${FGSEA_INPUTS_DIR}: ${FEATURE_SELECTION_WITH_SYMBOL} src/fig_fgsea_analysis/prepare_fgsea_inputs.R
	@echo ${BANNER}
	@echo "Preparing FGSEA inputs data (ranked gene list) in batches..."
	Rscript src/fig_fgsea_analysis/prepare_fgsea_inputs.R \
		--input_path ${FEATURE_SELECTION_WITH_SYMBOL} \
		--output_dir ${FGSEA_INPUTS_DIR} \
		--batch_size 10
# FGSEA Preprocessing pathways
MSIGDBR_DB=data/processed/msigdbr_pathways_collection.rds
${MSIGDBR_DB}: src/fig_fgsea_analysis/00a_prepare_msigdbr_collection.R
	@echo ${BANNER}
	@echo "Preparing MSigDB pathways collection..."
	Rscript src/fig_fgsea_analysis/00a_prepare_msigdbr_collection.R \
		--output_path ${MSIGDBR_DB}
PANGLAO_DB=data/processed/panglao_pathways_collection.rds
${PANGLAO_DB}: src/fig_fgsea_analysis/00b_prepare_panglaodb_collection.R
	@echo ${BANNER}
	@echo "Preparing PanglaoDB pathways collection..."
	Rscript src/fig_fgsea_analysis/00b_prepare_panglaodb_collection.R \
		--output_path ${PANGLAO_DB}


# FGSEA PART 1: preprocessing data
FGSEA_PART1_RAW=data/processed/fgsea_part1_df.csv
${FGSEA_PART1_RAW}: src/fig_fgsea_analysis/01a_process_msigdbr_part1.R ${MSIGDBR_DB}
	@echo ${BANNER}
	@echo "Preprocessing FGSEA part 1 data..."
	Rscript src/fig_fgsea_analysis/01a_process_msigdbr_part1.R \
		--output_path ${FGSEA_PART1_RAW}

FGSEA_PART1_PROCESSED=data/processed/fgsea_part1_summary_df.csv
${FGSEA_PART1_PROCESSED}: src/fig_fgsea_analysis/02a_summary_fgsea_part1.R ${FGSEA_PART1_RAW}
	@echo ${BANNER}
	@echo "Summarizing FGSEA part 1 data..."
	Rscript src/fig_fgsea_analysis/02a_summary_fgsea_part1.R \
		--input_path ${FGSEA_PART1_RAW} \
		--output_path ${FGSEA_PART1_PROCESSED} \
		--cutoff ${CUTOFF}

# FGSEA PART 1: plotting

FGSEA_PART1_PLOT_DATA=data/processed/fig_fgsea_panel_a_plot_data.rds
${FGSEA_PART1_PLOT_DATA}: src/fig_fgsea_analysis/03a_plot_fgsea_part1.R ${FGSEA_PART1_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting FGSEA part 1 data..."
	Rscript src/fig_fgsea_analysis/03a_plot_fgsea_part1.R \
		--input_path ${FGSEA_PART1_PROCESSED} \
		--output_path ${FGSEA_PART1_PLOT_DATA} \
		--width 10 \
		--height 8

# FGSEA PART 2: preprocessing data
FGSEA_PART2_RAW=data/processed/fgsea_part2_df.csv
${FGSEA_PART2_RAW}: src/fig_fgsea_analysis/01b_process_panglaodb_part2.R ${PANGLAO_DB}
	@echo ${BANNER}
	@echo "Preprocessing FGSEA part 2 data..."
	Rscript src/fig_fgsea_analysis/01b_process_panglaodb_part2.R \
		--output_path ${FGSEA_PART2_RAW}

FGSEA_PART2_PROCESSED=data/processed/fgsea_part2_summary_df.csv
${FGSEA_PART2_PROCESSED}: src/fig_fgsea_analysis/02b_summary_fgsea_part2.R ${FGSEA_PART2_RAW}
	@echo ${BANNER}
	@echo "Summarizing FGSEA part 2 data..."
	Rscript src/fig_fgsea_analysis/02b_summary_fgsea_part2.R\
		--input_path ${FGSEA_PART2_RAW} \
		--output_path ${FGSEA_PART2_PROCESSED} \
		--cutoff ${CUTOFF}

# FGSEA PART 2: plotting
FGSEA_PART2_PLOT_DATA=data/processed/fig_fgsea_panel_b_plot_data.rds
${FGSEA_PART2_PLOT_DATA}: src/fig_fgsea_analysis/03b_plot_fgsea_part2.R ${FGSEA_PART2_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting FGSEA part 2 data..."
	Rscript src/fig_fgsea_analysis/03b_plot_fgsea_part2.R \
		--input_path ${FGSEA_PART2_PROCESSED} \
		--output_path ${FGSEA_PART2_PLOT_DATA} \
		--width 12  \
		--height 9

# ------------------------------------------
# FGSEA FINAL FIGURE
${FIG_FGSEA_OUT}: ${FGSEA_PART1_PLOT_DATA} ${FGSEA_PART2_PLOT_DATA} src/fig_fgsea_analysis/04_plot_fgsea_panels.R
	@echo ${BANNER}
	@echo "Plotting final FGSEA figure..."
	Rscript src/fig_fgsea_analysis/04_plot_fgsea_panels.R \
		--part1_data_path ${FGSEA_PART1_PLOT_DATA} \
		--part2_data_path ${FGSEA_PART2_PLOT_DATA} \
		--output_path ${FIG_FGSEA_OUT} \
		--width 12 \
		--height 12
# ==============================================================================
# TABLES
TABLE_METHOD_SRC=src/table2_method_description/create_method.R
${TABLE_METHOD}: ${TABLE_METHOD_SRC}
	@echo ${BANNER}
	@echo "Creating method description table..."
	Rscript ${TABLE_METHOD_SRC}

TABLE_DATASET_SRC=src/table1_dataset_description/create_table_real_datasets.R
${TABLE_DATASET}: ${TABLE_DATASET_SRC}
	@echo ${BANNER}
	@echo "Creating dataset description table..."
	Rscript ${TABLE_DATASET_SRC}
