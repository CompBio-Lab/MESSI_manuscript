# This should be all the relevant figs

# ===============================================================================
# Important variables
RAW_GZ=raw/results.tar.gz
# Data has raw dir and processed
DATA_DIR=data
DATA_RAW_DIR=${DATA_DIR}/raw
DATA_PROCESSED_DIR=${DATA_DIR}/processed
SRC_DIR=src
# Similarly results could have figures and other files
OUTPUT_DIR=results
FIG_DIR=results/figures

KEEP='.gitkeep'
BANNER="======================================================================="

# ==============================================================================

# Input data files
METRICS_CSV=${DATA_RAW_DIR}/metrics.csv

# Figure directories
FIG1_SRC_DIR=${SRC_DIR}/fig_performance_evaluation
FIG2_SRC_DIR=${SRC_DIR}

# Cleaning scripts
FIG1_WRANGLE_SRC=${FIG1_SRC_DIR}/clean.R


# Plotting scripts
FIG1_PLOT_SRC=${FIG1_SRC_DIR}/plot.R
# FIG1_SRC=${SRC_DIR}/fig_performance_evaluation.R
# FIG2_SRC=${SRC_DIR}/fig_computational_time.R
# FIG3_SRC=${SRC_DIR}/fig_feature_selection.R
# Input data files
# FIG3_CSV=${DATA_RAW_DIR}/all_feature_selection_results.csv
# FIG1_CSV=${DATA_RAW_DIR}/metrics.csv
# FIG2_TRACE=${DATA_RAW_DIR}/execution_trace.txt
# FIG2_METADATA=${DATA_RAW_DIR}/parsed_metadata.csv

# Processed file names
FIG1_PROCESSED=${DATA_PROCESSED_DIR}/fig_performance_evaluation_plot_data.csv


# ==========================
# Plotting params
WIDTH=7
HEIGHT=7
DEVICE=png # default is png
DPI=700 # default is 300
# Output files
# For performance evaluation
FIG_REAL_OUT=${FIG_DIR}/fig_performance_evaluation.${DEVICE}
FIG_SIM_OUT=${FIG_DIR}/fig_simulated_performance.${DEVICE}
FIG1_OUTPUT=$(FIG_REAL_OUT) $(FIG_SIM_OUT)
# For computational time
# FIG_COMP_TIME=${OUTPUT_DIR}/fig_computational_time.${DEVICE}
# FIG2_OUTPUT=$(FIG_COMP_TIME)
# # For feature selection
# FIG_FEAT_SELECTION_REAL_CORR=${FIG_DIR}/fig_feature_selection_weights.${DEVICE}
# FIG_FEAT_SELECTION_SIM_RANK=${FIG_DIR}/fig_feature_selection_sim_rank.${DEVICE}
# FIG3_OUTPUT=$(FIG_FEAT_SELECTION_REAL_CORR) $(FIG_FEAT_SELECTION_SIM_RANK)

# =========================
# All the outputs
#OUTPUTS=$(FIG1_OUTPUT) $(FIG2_OUTPUT) $(FIG3_OUTPUT)
#OUTPUTS=$(FIG1_OUTPUT)
OUTPUTS=$(FIG1_OUTPUT)
all: $(OUTPUTS)

.PHONY: clean
clean: clean_figures

clean_figures:
	@echo "Cleaning files in ${FIG_DIR} ..."
	@find ${FIG_DIR} ! -name ${KEEP} -type f -exec rm -f {} +
#untar: $(RAW_GZ)
#	@tar -xf $(RAW_GZ) \
#	--transform="s/.*\///" \
#	--directory ${DATA_DIR}

# ==============================================================================
# PREPROCESSING

# Figure 1 processing
# Runs through a bit a wrangle then plot it
$(FIG1_PROCESSED): ${FIG1_WRANGLE_SRC} ${METRICS_CSV}
	@echo ${BANNER}
	@echo -e "Processing data for figure 1 performance evaluation"
	Rscript ${FIG1_WRANGLE_SRC} \
		--input_csv $(METRICS_CSV) \
		--output_csv ${FIG1_PROCESSED}


# ==============================================================================


# ======================================================
# FIGURE 1 Performance Evaluation
$(FIG1_OUTPUT): ${FIG1_PLOT_SRC} ${FIG1_PROCESSED}
	@echo ${BANNER}
	@echo -e "Plotting figures of performance evaluation ... \n"
	Rscript $(FIG1_PLOT_SRC) \
		--input_csv $(FIG1_PROCESSED) \
		--real_out $(FIG_REAL_OUT) \
		--sim_out $(FIG_SIM_OUT) \
		--width ${WIDTH} \
		--height ${HEIGHT} \
		--device ${DEVICE} \
		--dpi ${DPI}



# $(FIG1_OUTPUT): ${FIG1_SRC} ${FIG1_PROCESSED}
# 	@echo ${BANNER}
# 	@echo -e "Plotting figures of performance evaluation ... \n"
# 	Rscript $(FIG1_SRC) \
# 		--csv $(FIG1_CSV) \
# 		--real_out $(FIG_REAL_OUT) \
# 		--sim_out $(FIG_SIM_OUT) \
# 		--width ${WIDTH} \
# 		--height ${HEIGHT} \
# 		--device ${DEVICE} \
# 		--dpi ${DPI}

# ============================================================

# $(FIG2_OUTPUT): ${FIG2_SRC} ${FIG2_TRACE} ${FIG2_METADATA}
# 	@echo ${BANNER}
# 	@echo -e "Plotting figure of computational time\n"
# 	Rscript $(FIG2_SRC) \
# 		--metadata ${FIG2_METADATA} \
# 		--trace ${FIG2_TRACE} \
# 		--output ${FIG_COMP_TIME} \
# 		--width ${WIDTH} \
# 		--height ${HEIGHT} \-
# 		--device ${DEVICE} \
# 		--dpi ${DPI}

# $(FIG3_OUTPUT): ${FIG3_SRC} ${FIG3_CSV}
# 	@echo ${BANNER}
# 	@echo -e "Plotting figure of feature selection comparison... \n"
# 	Rscript ${FIG3_SRC} \
# 		--csv ${FIG3_CSV} \
# 		--real_output ${FIG_FEAT_SELECTION_REAL_CORR} \
# 		--sim_output ${FIG_FEAT_SELECTION_SIM_RANK} \
# 		--width ${WIDTH} \
# 		--height ${HEIGHT} \
# 		--device ${DEVICE} \
# 		--dpi ${DPI}
