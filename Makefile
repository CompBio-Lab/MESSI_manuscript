# ===============================================================================
# Important variables
# ==========================
# Plotting params
WIDTH=7
HEIGHT=7
DEVICE=png # default is png
DPI=700 # default is 300

# ==========================================================================
# Data has raw dir and processed
DATA_DIR=data
DATA_RAW_DIR=${DATA_DIR}/raw
REAL_DATA_DIR=${DATA_RAW_DIR}/real_data_results
SIM_DATA_DIR=${DATA_RAW_DIR}/simulated_data_results
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
FIG3_REAL_PROCESSED=${DATA_PROCESSED_DIR}/fig_feature_selection_real_plot_data.csv
FIG3_SIM_PROCESSED=${DATA_PROCESSED_DIR}/fig_feature_selection_sim_plot_data.csv

# Figure source directories (contain scripts for generating figures)
# Scripts for performance evaluation figure
FIG1_SRC_DIR=${SRC_DIR}/fig_performance_evaluation
# Scripts for computational time figure
FIG2_SRC_DIR=${SRC_DIR}/fig_computational_time
# Scripts for feature selection figure
FIG3_SRC_DIR=${SRC_DIR}/fig_feature_selection

# Cleaning scripts (for preprocessing data)
# Script to clean/preprocess performance evaluation data
FIG1_WRANGLE_SRC=${FIG1_SRC_DIR}/clean.R
# Script to clean/preprocess computational time data
FIG2_WRANGLE_SRC=${FIG2_SRC_DIR}/clean.R
# Script to clean/preprocess feature selection data
FIG3_WRANGLE_SRC=${FIG3_SRC_DIR}/clean.R

# Plotting scripts (for generating figures)
# Script to plot performance evaluation figure
FIG1_PLOT_SRC=${FIG1_SRC_DIR}/plot.R
# Script to plot computational time figure
FIG2_PLOT_SRC=${FIG2_SRC_DIR}/plot.R
# Script to plot feature selection figure
FIG3_PLOT_SRC=${FIG3_SRC_DIR}/plot.R

# Figure output names
# Performance evaluation
FIG_REAL_PERF_OUT=${FIG_DIR}/fig_performance_evaluation_real.${DEVICE}
FIG_SIM_PERF_OUT=${FIG_DIR}/fig_performance_evaluation_sim.${DEVICE}

# Computational time
# FIG_REAL_TIME_OUT=${FIG_DIR}/fig_computational_time_real.${DEVICE}
FIG_SIM_TIME_OUT=${FIG_DIR}/fig_computational_time_sim.${DEVICE}

# Feature selection
# FIG_REAL_FS_OUT=${FIG_DIR}/fig_feature_selection_real.${DEVICE}
FIG_SIM_FS_OUT=${FIG_DIR}/fig_feature_selection_sim.${DEVICE}

# ====================================================================================
# All the outputs
# Real data targets are always included
#OUTPUTS=${FIG_REAL_PERF_OUT} ${FIG_REAL_TIME_OUT} ${FIG_REAL_FS_OUT}
OUTPUTS=${FIG_REAL_PERF_OUT}
# Conditionally include simulated data targets if input files exist
ifneq ($(wildcard ${SIM_METRICS_CSV}),)
OUTPUTS+= ${FIG_SIM_PERF_OUT}
endif
# ifneq ($(wildcard ${SIM_METADATA_CSV}),)
# OUTPUTS+= ${FIG_SIM_TIME_OUT}
# endif
# ifneq ($(wildcard ${SIM_FS_RESULTS_CSV}),)
# OUTPUTS+= ${FIG_SIM_FS_OUT}
# endif

all: ${OUTPUTS}


.PHONY: clean
clean: clean_figures clean_data

clean_figures:
	@echo "Cleaning files in ${FIG_DIR} ..."
	@find ${FIG_DIR} ! -name ${KEEP} -type f -exec rm -f {} +

clean_data:
	@echo "Cleaning file in ${DATA_PROCESSED_DIR} ..."
	@find ${DATA_PROCESSED_DIR} ! -name ${KEEP} -type f -exec rm -f {} +

# ==============================================================================
# PREPROCESSING

# Figure 1: Performance evaluation (Real Data)
${FIG1_REAL_PROCESSED}: ${FIG1_WRANGLE_SRC} ${REAL_METRICS_CSV}
	@echo ${BANNER}
	@echo "Processing real data for performance evaluation"
	Rscript ${FIG1_WRANGLE_SRC} \
		--input_csv ${REAL_METRICS_CSV} \
		--output_path ${FIG1_REAL_PROCESSED} \
		--data_type real

# Figure 1: Performance evaluation (Simulated Data)
${FIG1_SIM_PROCESSED}: ${FIG1_WRANGLE_SRC} ${SIM_METRICS_CSV}
	@echo ${BANNER}
	@echo "Processing simulated data for performance evaluation"
	Rscript ${FIG1_WRANGLE_SRC} \
		--input_csv ${SIM_METRICS_CSV} \
		--output_path ${FIG1_SIM_PROCESSED} \
		--data_type sim

# # Figure 2: Computational time (Real Data)
# ${FIG2_REAL_PROCESSED}: ${FIG2_WRANGLE_SRC} ${REAL_METADATA_CSV} ${REAL_TRACE_TXT}
# 	@echo ${BANNER}
# 	@echo "Processing real data for computational time"
# 	Rscript ${FIG2_WRANGLE_SRC} \
# 		--metadata ${REAL_METADATA_CSV} \
# 		--trace ${REAL_TRACE_TXT} \
# 		--output_csv ${FIG2_REAL_PROCESSED} \
# 		--data_type real

# # Figure 2: Computational time (Simulated Data)
# ${FIG2_SIM_PROCESSED}: ${FIG2_WRANGLE_SRC} ${SIM_METADATA_CSV} ${SIM_TRACE_TXT}
# 	@echo ${BANNER}
# 	@echo "Processing simulated data for computational time"
# 	Rscript ${FIG2_WRANGLE_SRC} \
# 		--metadata ${SIM_METADATA_CSV} \
# 		--trace ${SIM_TRACE_TXT} \
# 		--output_csv ${FIG2_SIM_PROCESSED} \
# 		--data_type sim

# # Figure 3: Feature selection (Real Data)
# ${FIG3_REAL_PROCESSED}: ${FIG3_WRANGLE_SRC} ${REAL_FS_RESULTS_CSV}
# 	@echo ${BANNER}
# 	@echo "Processing real data for feature selection"
# 	Rscript ${FIG3_WRANGLE_SRC} \
# 		--input_csv ${REAL_FS_RESULTS_CSV} \
# 		--output_csv ${FIG3_REAL_PROCESSED} \
# 		--data_type real

# # Figure 3: Feature selection (Simulated Data)
# ${FIG3_SIM_PROCESSED}: ${FIG3_WRANGLE_SRC} ${SIM_FS_RESULTS_CSV}
# 	@echo ${BANNER}
# 	@echo "Processing simulated data for feature selection"
# 	Rscript ${FIG3_WRANGLE_SRC} \
# 		--input_csv ${SIM_FS_RESULTS_CSV} \
# 		--output_csv ${FIG3_SIM_PROCESSED} \
# 		--data_type sim

# ==============================================================================
# FIGURE 1: Performance evaluation (Real Data)
${FIG_REAL_PERF_OUT}: ${FIG1_PLOT_SRC} ${FIG1_REAL_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting performance evaluation (Real Data)..."
	Rscript ${FIG1_PLOT_SRC} \
		--input_path ${FIG1_REAL_PROCESSED} \
		--output_path ${FIG_REAL_PERF_OUT} \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--data_type real

# FIGURE 1: Performance evaluation (Simulated Data)
${FIG_SIM_PERF_OUT}: ${FIG1_PLOT_SRC} ${FIG1_SIM_PROCESSED}
	@echo ${BANNER}
	@echo "Plotting performance evaluation (Simulated Data)..."
	Rscript ${FIG1_PLOT_SRC} \
		--input_path ${FIG1_SIM_PROCESSED} \
		--output_path ${FIG_SIM_PERF_OUT} \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI} \
		--data_type sim

# # ==============================================================================
# # FIGURE 2: Computational time (Real Data)
# ${FIG_REAL_TIME_OUT}: ${FIG2_PLOT_SRC} ${FIG2_REAL_PROCESSED}
# 	@echo ${BANNER}
# 	@echo "Plotting computational time (Real Data)..."
# 	Rscript ${FIG2_PLOT_SRC} \
# 		--input_csv ${FIG2_REAL_PROCESSED} \
# 		--output_path ${FIG_REAL_TIME_OUT} \
# 		--width ${WIDTH} \
# 		--height ${HEIGHT} \
# 		--device ${DEVICE} \
# 		--dpi ${DPI} \
# 		--data_type real

# # FIGURE 2: Computational time (Simulated Data)
# ${FIG_SIM_TIME_OUT}: ${FIG2_PLOT_SRC} ${FIG2_SIM_PROCESSED}
# 	@echo ${BANNER}
# 	@echo "Plotting computational time (Simulated Data)..."
# 	Rscript ${FIG2_PLOT_SRC} \
# 		--input_csv ${FIG2_SIM_PROCESSED} \
# 		--output_path ${FIG_SIM_TIME_OUT} \
# 		--width ${WIDTH} \
# 		--height ${HEIGHT} \
# 		--device ${DEVICE} \
# 		--dpi ${DPI} \
# 		--data_type sim

# # ==============================================================================
# # FIGURE 3: Feature selection (Real Data)
# ${FIG_REAL_FS_OUT}: ${FIG3_PLOT_SRC} ${FIG3_REAL_PROCESSED}
# 	@echo ${BANNER}
# 	@echo "Plotting feature selection (Real Data)..."
# 	Rscript ${FIG3_PLOT_SRC} \
# 		--input_csv ${FIG3_REAL_PROCESSED} \
# 		--output_path ${FIG_REAL_FS_OUT} \
# 		--width ${WIDTH} \
# 		--height ${HEIGHT} \
# 		--device ${DEVICE} \
# 		--dpi ${DPI} \
# 		--data_type real

# # FIGURE 3: Feature selection (Simulated Data)
# ${FIG_SIM_FS_OUT}: ${FIG3_PLOT_SRC} ${FIG3_SIM_PROCESSED}
# 	@echo ${BANNER}
# 	@echo "Plotting feature selection (Simulated Data)..."
# 	Rscript ${FIG3_PLOT_SRC} \
# 		--input_csv ${FIG3_SIM_PROCESSED} \
# 		--output_path ${FIG_SIM_FS_OUT} \
# 		--width ${WIDTH} \
# 		--height ${HEIGHT} \
# 		--device ${DEVICE} \
# 		--dpi ${DPI} \
# 		--data_type sim
