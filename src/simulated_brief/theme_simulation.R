# theme_simulation.R - shared house style + method mapping for the simulation figure
# (follows MESSI_simulation_figure_brief.md; reuses CLASS_COLORS house style)
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(stringr)})

CLASS_COLORS <- c(Early = "#2B6A9F", Intermediate = "#D68A2A", Late = "#3C8C63")

# Canonical method dictionary: ONE shared label map for every figure.
# src/common_helpers/method_labels.R maps both the prediction-file names
# (sklearn-Logit-empty, diablo-full_ncomp-1) and the feature-file names (sklearn-logit,
# diablo-full) onto the same canonical key / concise label / integration class / order.
source(here::here("src/common_helpers/method_labels.R"))
normalize_method <- function(x) method_key(x)
METHOD_TBL <- METHOD_LABELS

map_method <- function(raw) {
  key <- normalize_method(raw)
  i <- match(key, METHOD_TBL$key)
  tibble(method_raw = raw, key = key,
         method = ifelse(is.na(i), raw, METHOD_TBL$label[i]),
         class  = ifelse(is.na(i), NA_character_, METHOD_TBL$class[i]),
         order  = ifelse(is.na(i), 99L, METHOD_TBL$order[i]))
}

# Parse a simulation dataset id: S0_linear_n-500_p-3000_dt-2_rho-0p5(-omic1)(_processed)
parse_sim_id <- function(ds) {
  ds <- str_replace(ds, "_processed$", "")
  omic <- str_match(ds, "-(omic[123])$")[, 2]          # single-modality tag, else NA
  base <- str_replace(ds, "-omic[123]$", "")
  scenario <- str_match(base, "^(S\\d+_[a-zA-Z]+)_n-")[, 2]
  dt  <- as.integer(str_match(base, "_dt-(\\d+)")[, 2])
  rho_raw <- str_match(base, "_rho-([0-9p]+)")[, 2]
  rho <- as.numeric(str_replace(rho_raw, "p", "."))
  tibble(dataset = ds, base = base, is_single = !is.na(omic), omic = omic,
         scenario = scenario, dt = dt, rho = rho)
}

SCEN_LABS <- c(S0_linear = "S0 Linear", S1_nonlinear = "S1 Nonlinear",
               S2_batch = "S2 Batch effect", S3_noise = "S3 Modality noise")
scen_lab <- function(s) ifelse(s %in% names(SCEN_LABS), SCEN_LABS[s], s)

# rank-based AUROC; higher score => positive. Keeps values <0.5. NA if one class.
auroc <- function(score, pos) {
  ok <- is.finite(score) & !is.na(pos)
  score <- score[ok]; pos <- as.logical(pos[ok])
  n1 <- sum(pos); n0 <- sum(!pos)
  if (n1 == 0L || n0 == 0L) return(NA_real_)
  r <- rank(score, ties.method = "average")
  (sum(r[pos]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

th_sim <- function(b = 10) theme_bw(base_size = b) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom",
        strip.background = element_rect(fill = "grey92", color = NA),
        plot.title = element_text(face = "bold", size = b + 1),
        axis.text = element_text(color = "black"))
