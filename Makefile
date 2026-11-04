# MESSI manuscript figures: raw Nextflow output -> derived tables -> figures.
# Run from the repository root (Git Bash on Windows, GNU make, R 4.3.3).
#   make process   derived tables from data/raw   (scripts/process_all.sh)
#   make figures   all figures, then sort them: results/manuscript_figures (numbered as in the
#                  manuscript) and results/other_figures (everything else)
#   make all       process, then figures
# The targets are phony (always re-run); the scripts enforce the step order.

SHELL := bash

.PHONY: all process figures

all:
	$(MAKE) process
	$(MAKE) figures

process:
	bash scripts/process_all.sh

figures:
	bash scripts/replot_figures.sh
	bash scripts/collect_manuscript_figures.sh
