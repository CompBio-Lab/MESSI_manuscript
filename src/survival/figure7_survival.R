# figure7_survival.R - main Figure 7 (survival extension) + supplementary figures.
# Supersedes figure_survival_main.R for the manuscript. Inputs (full survival run, short-path copy):
#   data/processed/survival_src/metrics_summary.csv  per method x dataset, fold mean/sd metrics
#   data/processed/survival_src/all-result.csv       per-sample OOF risk score lp, time, status, fold
# Methods: RSF (scikit-survival) on concatenated features = Early; MOFA+ factors + Cox = Intermediate.
# Colour = integration class (theme_messi CLASS_COLORS), shape = method. Any method present in the
# input is picked up automatically; a method that returns the null (all-zero) Cox
# model on most datasets (currently Multiview, lp = 0 on 9/10) is kept out of the main
# figure and of the per-dataset supplement.
# Outputs:
#   results/final_figures/main/Fig7_survival.{png,pdf,rds}
#   results/final_figures/panels/Fig7_<letter>_<name>.{pdf,svg}   
#   results/final_figures/supp/FigS_survival_{per_dataset,km_example,km_grid}.{png,pdf,rds}
#   results/survival_new/tables/{survival_per_dataset,survival_stats,hr_forest,td_auc_mean}.csv
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr)
  library(ggplot2); library(patchwork); library(survival); library(here)
})
source(here::here("src/common_helpers/theme_messi.R"))
SV  <- here::here("data/processed/survival_src")
TAB <- here::here("results/survival_new/tables"); dir.create(TAB, recursive = TRUE, showWarnings = FALSE)
MAIN <- here::here("results/final_figures/main"); SUPP <- here::here("results/final_figures/supp")
PAN  <- here::here("results/final_figures/panels")
for (d in c(MAIN, SUPP, PAN)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ---- methods: label / integration class / shape (fillable shapes 21-25) ----
KNOWN <- tibble::tribble(
  ~method_name,           ~method,                ~class,          ~shape,
  "sksurv-rsf",           "RSF",                  "Early",         21,
  "mofa",                 "MOFA+ (Cox)",          "Intermediate",  24,
  "cooperative_learning", "Multiview", "Intermediate",  22)
m <- read_csv(file.path(SV, "metrics_summary.csv"), show_col_types = FALSE)
a <- read_csv(file.path(SV, "all-result.csv"), show_col_types = FALSE)
n_ds <- n_distinct(m$dataset)
extra <- setdiff(unique(m$method_name), KNOWN$method_name)
MINFO <- bind_rows(KNOWN, tibble(method_name = extra, method = extra,
                                 class = coalesce(method_class(extra), "Intermediate"),
                                 shape = rep(c(23, 25, 21, 24), length.out = length(extra)))) %>%
  filter(method_name %in% unique(m$method_name))
LAB  <- setNames(MINFO$method, MINFO$method_name)
MCOL <- setNames(unname(CLASS_COLORS[MINFO$class]), MINFO$method)
MSHP <- setNames(MINFO$shape, MINFO$method)

# ---- degeneracy: fraction of samples whose OOF risk score is exactly 0 (null Cox model) ----
degen <- a %>% group_by(method_name, dataset) %>%
  summarise(frac_lp0 = mean(lp == 0), n_folds_null = sum(tapply(lp, fold, function(x) all(x == 0))),
            .groups = "drop")
ds_lab <- m %>% distinct(dataset, n, n_events) %>%
  mutate(ds = str_to_title(str_remove(dataset, "^momix-")),
         ds = ifelse(ds %in% c("Aml", "Gbm"), toupper(ds), ds),
         ds_lab = sprintf("%s (%d/%d)", ds, n, n_events))
per <- m %>% left_join(degen, by = c("method_name", "dataset")) %>%
  left_join(ds_lab, by = c("dataset", "n", "n_events")) %>%
  mutate(method = LAB[method_name], null_model = frac_lp0 > 0.5)
write_csv(per %>% select(method, dataset, n, n_events, c_harrell_mean, c_harrell_std, c_uno_mean,
                         ipa_mean, ibs_mean, ibs_null_mean, mean_auc_mean, frac_lp0, n_folds_null, null_model),
          file.path(TAB, "survival_per_dataset.csv"))
MAIN_METHODS <- per %>% group_by(method_name) %>% summarise(k = sum(null_model)) %>%
  filter(k < n_ds / 2) %>% pull(method_name)
MAIN_METHODS <- MINFO$method_name[MINFO$method_name %in% MAIN_METHODS]
message("[main methods] ", paste(LAB[MAIN_METHODS], collapse = ", "))

# ---- statistics (over datasets; two-sided exact Wilcoxon signed-rank) ----
wt <- function(x, mu = 0) suppressWarnings(wilcox.test(x, mu = mu, exact = TRUE))$p.value
stats <- bind_rows(lapply(MINFO$method_name, function(mn) {
  d <- per %>% filter(method_name == mn)
  tibble(method = LAB[[mn]], n_datasets = nrow(d),
         mean_C = mean(d$c_harrell_mean), median_C = median(d$c_harrell_mean),
         n_C_gt_05 = sum(d$c_harrell_mean > 0.5), p_C_vs_05_two_sided = wt(d$c_harrell_mean, 0.5),
         p_C_vs_05_one_sided = suppressWarnings(wilcox.test(d$c_harrell_mean, mu = 0.5, alternative = "greater"))$p.value,
         mean_IPA = mean(d$ipa_mean), n_IPA_gt_0 = sum(d$ipa_mean > 0), p_IPA_vs_0_two_sided = wt(d$ipa_mean),
         n_null_model_datasets = sum(d$null_model))
}))
pairs <- bind_rows(lapply(setdiff(MAIN_METHODS, "sksurv-rsf"), function(mn) {
  w <- per %>% filter(method_name %in% c("sksurv-rsf", mn)) %>%
    select(dataset, method_name, c_harrell_mean, ipa_mean) %>%
    pivot_wider(names_from = method_name, values_from = c(c_harrell_mean, ipa_mean))
  cr <- w[["c_harrell_mean_sksurv-rsf"]]; co <- w[[paste0("c_harrell_mean_", mn)]]
  ir <- w[["ipa_mean_sksurv-rsf"]];     io <- w[[paste0("ipa_mean_", mn)]]
  tibble(method = sprintf("RSF - %s, paired", LAB[[mn]]), other = LAB[[mn]], n_datasets = nrow(w),
         mean_C = mean(cr - co), n_C_gt_05 = sum(cr > co),
         p_C_vs_05_two_sided = wilcox.test(cr, co, paired = TRUE)$p.value,
         mean_IPA = mean(ir - io), n_IPA_gt_0 = sum(ir > io),
         p_IPA_vs_0_two_sided = wilcox.test(ir, io, paired = TRUE)$p.value)
}))
stats <- bind_rows(stats, pairs)
write_csv(stats, file.path(TAB, "survival_stats.csv"))
print(as.data.frame(stats %>% mutate(across(where(is.numeric), ~ signif(.x, 3)))))

# ---- hazard ratios: high vs low predicted risk. Median split WITHIN each test fold (risk scores of
#      different fold models are not on one scale), then Cox model on the pooled OOF groups ----
ar <- a %>% group_by(method_name, dataset, fold) %>%
  mutate(risk = ifelse(lp > median(lp), "High risk", "Low risk")) %>% ungroup()
hr <- ar %>% group_by(method_name, dataset) %>% group_modify(~ {
  nh <- sum(.x$risk == "High risk")
  if (nh < 5 || nh > nrow(.x) - 5)
    return(tibble(HR = NA_real_, lo = NA_real_, hi = NA_real_, p_logrank = NA_real_, n_high = nh))
  cx <- coxph(Surv(time, status) ~ I(risk == "High risk"), data = .x)
  ci <- exp(suppressMessages(confint(cx)))
  sd <- survdiff(Surv(time, status) ~ risk, data = .x)
  tibble(HR = exp(coef(cx))[[1]], lo = ci[1, 1], hi = ci[1, 2],
         p_logrank = pchisq(sd$chisq, 1, lower.tail = FALSE), n_high = nh)
}) %>% ungroup() %>% left_join(degen, by = c("method_name", "dataset")) %>%
  mutate(method = LAB[method_name], null_model = frac_lp0 > 0.5) %>% left_join(ds_lab, by = "dataset")
write_csv(hr, file.path(TAB, "hr_forest.csv"))
print(as.data.frame(hr %>% select(method, dataset, HR, lo, hi, p_logrank, n_high, frac_lp0) %>%
                      mutate(across(where(is.numeric), ~ signif(.x, 3)))))

# ============================ MAIN FIGURE 7 ============================
ds_order <- per %>% filter(method_name == "sksurv-rsf") %>% arrange(c_harrell_mean) %>% pull(ds_lab)
mk <- function(d) d %>% filter(method_name %in% MAIN_METHODS) %>%
  mutate(method = factor(method, levels = LAB[MAIN_METHODS]),
         ds_lab = factor(ds_lab, levels = ds_order),
         fillkey = ifelse(null_model, "null", as.character(method)))
dodge <- position_dodge(width = 0.6)
scales_m <- list(
  scale_colour_manual(values = MCOL, name = NULL, breaks = unname(LAB[MAIN_METHODS])),
  scale_shape_manual(values = MSHP, name = NULL, breaks = unname(LAB[MAIN_METHODS]),
                     guide = guide_legend(override.aes = list(fill = unname(MCOL[LAB[MAIN_METHODS]]), linetype = 0))),
  scale_fill_manual(values = c(MCOL, null = "white"), breaks = "null",
                    labels = "open symbol = null Cox model in most folds", name = NULL,
                    guide = guide_legend(override.aes = list(shape = 21, colour = "grey30", size = 2.2))))
dot_panel <- function(d, x, xlo, xhi, ref, xlab) {
  ggplot(d, aes(.data[[x]], ds_lab, colour = method, shape = method, fill = fillkey, group = method)) +
    geom_vline(xintercept = ref, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
    geom_errorbar(aes(xmin = .data[[xlo]], xmax = .data[[xhi]]), width = 0, linewidth = 0.4,
                  position = dodge, orientation = "y", na.rm = TRUE) +
    geom_point(size = 2, position = dodge, stroke = 0.8, na.rm = TRUE) +
    scales_m + labs(x = xlab, y = NULL) + theme_messi()
}
pm <- mk(per) %>% mutate(c_lo = c_harrell_mean - c_harrell_std, c_hi = c_harrell_mean + c_harrell_std,
                         ipa_lo = ipa_mean - ipa_std, ipa_hi = ipa_mean + ipa_std)
callout <- if (nrow(pairs)) paste(sprintf("RSF > %s on %d/%d datasets (paired Wilcoxon p = %.3f)",
                                          pairs$other, pairs$n_C_gt_05, pairs$n_datasets, pairs$p_C_vs_05_two_sided),
                                  collapse = "\n") else " "
sub_theme <- theme(plot.subtitle = element_text(face = "bold", colour = "grey20", size = 8))   # callout: 8 pt bold grey20 (all main figs)
# column header above the dataset labels: numbers in brackets = patients / deaths (events)
ds_header <- function(xmin = -Inf) list(annotation_custom(xmin = xmin, xmax = Inf, grob = grid::textGrob("(patients / deaths)", x = unit(-2, "mm"), y = unit(1, "npc") + unit(2.5, "mm"),
                                                  hjust = 1, vjust = 0,
                                                  gp = grid::gpar(fontsize = 7.5, fontface = "italic", col = "grey25"))),
                  coord_cartesian(clip = "off"))   # panel border = theme_messi default (0.4) as in all main figures
pA <- dot_panel(pm, "c_harrell_mean", "c_lo", "c_hi", 0.5, "Harrell's C (fold mean ± SD)") +
  labs(title = "Discrimination", tag = "A") + ds_header()
pB <- dot_panel(pm, "ipa_mean", "ipa_lo", "ipa_hi", 0, "IPA (fold mean ± SD)") +
  labs(title = "Prediction accuracy (IPA)", tag = "B") +
  theme(axis.text.y = element_blank())

# C: time-dependent AUC per horizon; thin lines = datasets, thick = mean over datasets
tauc <- pm %>% select(method, dataset, null_model, matches("^auc_\\d+_mean$")) %>%
  pivot_longer(matches("^auc_\\d+_mean$"), names_to = "h", values_to = "auc") %>%
  mutate(years = as.numeric(str_extract(h, "\\d+")) / 365.25) %>% filter(!is.na(auc))
tauc_m <- tauc %>% group_by(method, years) %>% summarise(auc = mean(auc), n = n(), .groups = "drop")
write_csv(tauc_m, file.path(TAB, "td_auc_mean.csv"))
pC <- ggplot(tauc, aes(years, auc, colour = method)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_line(aes(group = interaction(method, dataset)), alpha = 0.25, linewidth = 0.3) +
  geom_line(data = tauc_m, linewidth = 1) +
  geom_point(data = tauc_m, aes(shape = method, fill = method), size = 2, stroke = 0.8) +
  scale_colour_manual(values = MCOL, name = NULL) + scale_fill_manual(values = MCOL, name = NULL) +
  scale_shape_manual(values = MSHP, name = NULL) +
  scale_x_continuous(breaks = 1:5) + scale_y_continuous(limits = c(0.4, 0.9)) +
  labs(x = "Horizon (years)", y = "Time-dependent AUC", title = "Time-dependent AUC", tag = "C") + theme_messi()

# D: forest plot, HR high vs low predicted risk with 95% CI, all datasets, log scale
# Tie handling: risk = "High" iff lp > within-fold median. In a fold where every lp = 0 (null Cox
# model) nobody exceeds the median, so the whole fold is "Low risk"; for the null-model datasets the
# HR is then driven by the few non-null folds and is not meaningful -> not estimable (n.e.).
ph <- mk(hr) %>% mutate(ne = null_model, HR = ifelse(ne, NA, HR), lo = ifelse(ne, NA, lo), hi = ifelse(ne, NA, hi))
ne_pts <- ph %>% filter(ne)
HR_LIM <- c(0.4, 6)
stopifnot(all(c(ph$lo, ph$hi) >= HR_LIM[1] & c(ph$lo, ph$hi) <= HR_LIM[2], na.rm = TRUE))
pD <- ggplot(ph, aes(HR, ds_lab, colour = method, shape = method, fill = fillkey, group = method)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey50", linewidth = 0.4) +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0, linewidth = 0.4, position = dodge,
                orientation = "y", na.rm = TRUE) +
  geom_point(size = 2, position = dodge, stroke = 0.8, na.rm = TRUE) +
  geom_point(data = ne_pts, aes(x = 1), position = dodge, size = 2, stroke = 0.8, colour = "grey55", fill = "white") +
  geom_text(data = ne_pts, aes(x = 1, label = "n.e."), position = dodge, hjust = 1.5, size = 7 / .pt,
            colour = "grey40", show.legend = FALSE) +
  scale_x_log10(breaks = c(0.5, 1, 2, 4), limits = HR_LIM, expand = c(0, 0)) + scales_m +
  labs(x = "HR, high vs low predicted risk (95% CI)", y = NULL, title = "Risk stratification", tag = "D") +
  theme_messi() + ds_header(HR_LIM[1])

H7 <- c(top = 4.0, bottom = 3.75, legend = 0.3)    # one shared legend row at the bottom
leg7 <- wrap_elements(full = cowplot::get_plot_component(pA + theme(legend.position = "bottom"),
                                                         "guide-box-bottom", return_all = TRUE))
noleg <- theme(legend.position = "none")
top <- (pA + noleg | pB + noleg) + plot_layout(widths = c(1.35, 1))
bot <- (free(pC + noleg) | pD + noleg) + plot_layout(widths = c(0.85, 1.25))
fig7 <- top / bot / leg7 + plot_layout(heights = unname(H7))
save_main(fig7, file.path(MAIN, "Fig7_survival"), height = sum(H7))

# ---- panel exports ----
save_panel <- function(p, name, h, w) for (ext in c("pdf", "svg"))
  ggsave(file.path(PAN, paste0(name, ".", ext)), p, width = w, height = h, bg = "white",
         device = if (ext == "svg") svglite::svglite else cairo_pdf)
save_panel(pA + noleg + labs(tag = NULL), "Fig7_A_cindex", H7[["top"]], 7 * 1.35 / 2.35)
save_panel(pB + noleg + labs(tag = NULL), "Fig7_B_ipa", H7[["top"]], 7 * 1 / 2.35)
save_panel(leg7, "Fig7_legend", H7[["legend"]], 7)
save_panel(pC + noleg + labs(tag = NULL), "Fig7_C_td_auc", H7[["bottom"]], 7 * 0.85 / 2.1)
save_panel(pD + noleg + labs(tag = NULL), "Fig7_D_hr_forest", H7[["bottom"]], 7 * 1.25 / 2.1)

# ============================ SUPP: KM curves ============================
km_curves <- function(d) d %>% group_by(method, ds_lab, risk) %>% group_modify(~ {
  f <- survfit(Surv(time / 365.25, status) ~ 1, data = .x)
  tibble(time = c(0, f$time), surv = c(1, f$surv))
}) %>% ungroup()
akm <- ar %>% filter(method_name %in% MAIN_METHODS) %>% left_join(ds_lab, by = "dataset") %>%
  mutate(method = factor(LAB[method_name], levels = LAB[MAIN_METHODS]),
         ds_lab = factor(ds_lab, levels = rev(ds_order)))
# (a) single example. Rule: among datasets with no null-model fold for any main method, most events.
cand <- degen %>% filter(method_name %in% MAIN_METHODS) %>% group_by(dataset) %>%
  summarise(ok = all(n_folds_null == 0 & frac_lp0 == 0), .groups = "drop") %>% filter(ok) %>%
  left_join(ds_lab, by = "dataset") %>% arrange(desc(n_events))
KM_DS <- cand$dataset[1]
message("[KM example] rule -> ", KM_DS)
hr1 <- hr %>% filter(dataset == KM_DS, method_name %in% MAIN_METHODS) %>%
  mutate(lab = sprintf("%s\nHR %.2f (%.2f–%.2f), p %s", method, HR, lo, hi,
                       ifelse(p_logrank < 0.001, "< 0.001", sprintf("= %.3f", p_logrank))))
pK1 <- ggplot(km_curves(filter(akm, dataset == KM_DS)), aes(time, surv, colour = method, linetype = risk)) +
  geom_step(linewidth = 0.6) +
  facet_wrap(~method, nrow = 1, labeller = as_labeller(setNames(hr1$lab, hr1$method))) +
  coord_cartesian(xlim = c(0, 20)) + scale_y_continuous(limits = c(0, 1)) +
  scale_colour_manual(values = MCOL, guide = "none") +
  scale_linetype_manual(values = c(`High risk` = "solid", `Low risk` = "22"), name = NULL) +
  labs(x = "Years", y = "Survival probability",
       title = sprintf("Kaplan–Meier by predicted risk: %s", ds_lab$ds[ds_lab$dataset == KM_DS])) +
  theme_messi()
save_main(pK1, file.path(SUPP, "FigS_survival_km_example"), height = 3.6)
# (b) all datasets
pK <- ggplot(km_curves(akm), aes(time, surv, colour = method, linetype = risk,
                                 group = interaction(method, risk))) +
  geom_step(linewidth = 0.45) + facet_wrap(~ds_lab, ncol = 5) +
  coord_cartesian(xlim = c(0, 10)) + scale_x_continuous(breaks = c(0, 5, 10)) +
  scale_y_continuous(limits = c(0, 1), breaks = c(0, .5, 1)) +
  scale_colour_manual(values = MCOL, name = NULL) +
  scale_linetype_manual(values = c(`High risk` = "solid", `Low risk` = "22"), name = NULL) +
  labs(x = "Years", y = "Survival probability",
       title = sprintf("Kaplan–Meier by predicted risk, %d MOMIX datasets", n_ds)) +
  theme_messi() + theme(strip.text = element_text(size = 7.5))
save_main(pK + labs(tag = "B") + theme(plot.tag = element_text(face = "bold", size = 14)), file.path(SUPP, "FigS_survival_km_grid"), height = 4.8)

# ============================ SUPP: per-dataset table (all methods) ============================
# Multiview is left out of this figure; it stays in survival_per_dataset.csv.
sup <- per %>% filter(method_name != "cooperative_learning") %>%
  mutate(method = factor(method, levels = setdiff(LAB, "Multiview")),
                      ds_lab = factor(ds_lab, levels = ds_order)) %>%
  select(method, ds_lab, `Harrell's C` = c_harrell_mean, `Uno's C` = c_uno_mean,
         `Mean td-AUC` = mean_auc_mean, IPA = ipa_mean, `Risk score = 0 (%)` = frac_lp0) %>%
  pivot_longer(-c(method, ds_lab), names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(metric, levels = c("Harrell's C", "Uno's C", "Mean td-AUC", "IPA", "Risk score = 0 (%)")),
         lab = ifelse(metric == "Risk score = 0 (%)", sprintf("%.0f", 100 * value),
                      ifelse(metric == "IPA", sprintf("%.3f", value + 0), sprintf("%.2f", value))),
         lab = sub("^-(0[.]0+)$", "\\1", lab),
         fillv = case_when(metric == "IPA" ~ 0.5 + value * 5,
                           metric == "Risk score = 0 (%)" ~ NA_real_, TRUE ~ value))
pS <- ggplot(sup, aes(method, ds_lab)) +
  geom_tile(aes(fill = fillv), colour = "white") +
  geom_text(aes(label = lab), size = 2.3) +
  facet_wrap(~metric, nrow = 1) +
  scale_fill_gradient2(low = "#2166AC", mid = "grey97", high = "#B2182B", midpoint = 0.5,
                       limits = c(0.2, 0.8), oob = scales::squish, na.value = "grey90", guide = "none") +
  labs(x = NULL, y = NULL,
       title = sprintf("Survival metrics per dataset (%d MOMIX datasets; n / events)", n_ds)) +
  theme_messi() + theme(panel.grid = element_blank(), axis.text.x = element_text(angle = 40, hjust = 1))
save_main(pS, file.path(SUPP, "FigS_survival_per_dataset"), height = 4.6)
message("[done] Fig 7 + survival supplementary figures")
