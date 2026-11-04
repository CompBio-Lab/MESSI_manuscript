# =============================================================================
# sim_all_metrics.R
# 为模拟结果算出【全部分类指标】(不只 ROC-AUC),口径与 metrics.csv 对齐,
# 但从逐样本 phat 统一 pooled-OOF 重算 —— 这样能:
#   (1) 避开 pipeline metrics.csv 里"失败被记成 0"的脏行(异常处理默认值);
#   (2) 保留 <0.5 的 ROC/指标不翻转;
#   (3) 和 sim_plot_explore.R 的 roc_auc 口径完全一致。
# 然后与 pipeline 的 metrics.csv 交叉核对(报每个指标的最大绝对差)。
#
# 指标(每 method×scenario×dt×rho,pooled 全部 OOF 预测,阈值 0.5):
#   roc_auc, pr_auc(= Average Precision,sklearn average_precision_score 口径),
#   log_loss, f1_score, matthews_corrcoef, accuracy, balanced_accuracy,
#   precision, recall
#
# 输出(results/simulated_brief/data_derived/):
#   sim_all_metrics_by_rho.csv       长表 method×scenario×dt×rho×metric×value(展开 rho)
#   sim_all_metrics_rho_summary.csv  对 rho 等权平均后的长表(V2 用)
#   sim_metrics_crosscheck.csv       重算 vs pipeline 的核对
# 原始数据只读;不覆盖现有产物。
# =============================================================================
suppressPackageStartupMessages({
  library(data.table); library(dplyr); library(tidyr); library(readr)
  library(stringr); library(ggplot2); library(here)
})
source(here::here("src/simulated_brief/theme_simulation.R"))  # map_method/parse_sim_id/auroc/SCEN_LABS/CLASS_COLORS
OUT <- here::here("results/simulated_brief/data_derived"); dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
RUN <- here::here("data/raw/final_classification_results/simulated",
                  "copied_results_20261003_124923-job13207577-MESSI_results-simulated_data-samplesheet_simulated_full")
PRED <- file.path(RUN, "all_langs-result.csv")
PIPE <- file.path(RUN, "metrics.csv")

METRICS <- c("roc_auc","pr_auc","log_loss","f1_score","matthews_corrcoef",
             "accuracy","balanced_accuracy","precision","recall")

# ------------------------------------------------------------------ metric fns
# Average Precision (sklearn average_precision_score 口径:阶梯式,不做梯形插值)
avg_precision <- function(score, pos) {
  if (sum(pos) == 0 || sum(!pos) == 0) return(NA_real_)
  o <- order(score, decreasing = TRUE); pos <- pos[o]
  tp <- cumsum(pos); fp <- cumsum(!pos)
  prec <- tp / (tp + fp); rec <- tp / sum(pos)
  sum(c(rec[1], diff(rec)) * prec)
}
log_loss <- function(p, y) { eps <- 1e-15; p <- pmin(pmax(p, eps), 1 - eps)
  -mean(y * log(p) + (1 - y) * log(1 - p)) }

# 给一组 (y, phat) 算全部九个指标(阈值 0.5);类退化/单类 -> 对应指标 NA
all_metrics <- function(y, phat, thr = 0.5) {
  y <- as.integer(y); pos <- y == 1L; pred <- phat >= thr
  TP <- sum(pred & pos); FP <- sum(pred & !pos); TN <- sum(!pred & !pos); FN <- sum(!pred & pos)
  n <- length(y)
  prec <- if ((TP + FP) > 0) TP / (TP + FP) else NA_real_
  rec  <- if ((TP + FN) > 0) TP / (TP + FN) else NA_real_
  spec <- if ((TN + FP) > 0) TN / (TN + FP) else NA_real_
  f1   <- if (!is.na(prec) && !is.na(rec) && (prec + rec) > 0) 2 * prec * rec / (prec + rec) else NA_real_
  mcc_den <- sqrt(prod(c(TP + FP, TP + FN, TN + FP, TN + FN)))
  mcc  <- if (mcc_den > 0) (TP * TN - FP * FN) / mcc_den else NA_real_
  c(roc_auc           = auroc(phat, pos),
    pr_auc            = avg_precision(phat, pos),
    log_loss          = log_loss(phat, y),
    f1_score          = f1,
    matthews_corrcoef = mcc,
    accuracy          = (TP + TN) / n,
    balanced_accuracy = if (!is.na(rec) && !is.na(spec)) (rec + spec) / 2 else NA_real_,
    precision         = prec,
    recall            = rec)
}

# =============================================================================
# 1) 从逐样本 phat 重算(多模态数据集,pooled OOF)
# =============================================================================
message("[1] 读预测重算 ...")
p <- fread(PRED, select = c("sample_name","y","phat","method_name","dataset","fold"))
mm <- map_method(p$method_name); sim <- parse_sim_id(p$dataset)
p[, `:=`(method = mm$method, class = mm$class, order = mm$order,
         is_single = sim$is_single, scenario = sim$scenario, dt = sim$dt, rho = sim$rho)]
pmm <- as_tibble(p[is_single == FALSE & !is.na(scenario)])

wide <- pmm %>% group_by(method, class, order, scenario, dt, rho) %>%
  summarise(as_tibble(as.list(all_metrics(y, phat))), n = n(), n_pos = sum(y == 1), .groups = "drop") %>%
  arrange(order, scenario, dt, rho)

long <- wide %>% pivot_longer(all_of(METRICS), names_to = "metric", values_to = "value")
write_csv(long, file.path(OUT, "sim_all_metrics_by_rho.csv"))
message("[1] 指标长表行数: ", nrow(long), "  (configs x 9 metrics)")

# V2: 对 rho 等权平均
summ <- long %>% filter(!is.na(value)) %>%
  group_by(method, class, order, scenario, dt, metric) %>%
  summarise(value = mean(value), n_rho = n(), .groups = "drop") %>%
  arrange(order, scenario, dt, metric)
write_csv(summ, file.path(OUT, "sim_all_metrics_rho_summary.csv"))

# =============================================================================
# 2) 交叉核对 pipeline metrics.csv(并标出"失败被记成 0"的脏行)
# =============================================================================
message("[2] 交叉核对 pipeline metrics.csv ...")
pipe0 <- read_csv(PIPE, show_col_types = FALSE)
.sim <- parse_sim_id(pipe0$dataset); .mm <- map_method(pipe0$method_name)
# pipeline 失败签名:log_loss==0 且 accuracy==0 且 balanced_accuracy==0(异常默认 0)
pipe <- pipe0 %>%
  mutate(is_single = .sim$is_single, scenario = .sim$scenario, dt = .sim$dt, rho = .sim$rho,
         method = .mm$method, class = .mm$class, order = .mm$order) %>%
  filter(is_single == FALSE, !is.na(scenario)) %>%
  mutate(pipe_failed = (log_loss == 0 & accuracy == 0 & balanced_accuracy == 0))
message("[2] pipeline 里'失败被记成 0'的 config 数: ", sum(pipe$pipe_failed))

cross <- inner_join(
  long %>% rename(recomputed = value),
  pipe %>% select(method, scenario, dt, rho, all_of(METRICS), pipe_failed) %>%
    pivot_longer(all_of(METRICS), names_to = "metric", values_to = "pipeline"),
  by = c("method","scenario","dt","rho","metric")) %>%
  mutate(absdiff = abs(recomputed - pipeline))
# 核对汇总:排除 pipeline 失败行后,每个指标的最大/中位绝对差
chk <- cross %>% filter(!pipe_failed) %>% group_by(metric) %>%
  summarise(max_absdiff = max(absdiff, na.rm = TRUE),
            median_absdiff = median(absdiff, na.rm = TRUE),
            n = sum(!is.na(absdiff)), .groups = "drop")
write_csv(cross, file.path(OUT, "sim_metrics_crosscheck.csv"))
cat("\n==== 重算 vs pipeline(已排除 pipeline 失败行)每指标绝对差 ====\n"); print(as.data.frame(chk))
cat("\n(roc_auc/pr_auc 阈值无关,应最吻合;阈值类若差大多半是 pipeline 阈值/舍入或失败 0 导致)\n")

# =============================================================================
# 3) 看一眼 + 一张示例图(所有指标 x dt,某场景)。改这里探索。
# =============================================================================
cat("\n==== wide(重算全指标)前几行 ====\n"); print(head(as.data.frame(wide)))
exfig <- summ %>% filter(scenario == "S1_nonlinear") %>%
  mutate(scenario = scen_lab(scenario)) %>%
  ggplot(aes(dt, value, color = method, group = method)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey60") +
  geom_line(na.rm = TRUE) + geom_point(na.rm = TRUE, size = 1.3) +
  facet_wrap(~metric, scales = "free_y") +
  scale_color_manual(values = setNames(
    unlist(lapply(split(arrange(METHOD_TBL, order), arrange(METHOD_TBL, order)$class),
                  function(d) rep(CLASS_COLORS[d$class[1]], nrow(d)))), arrange(METHOD_TBL, order)$label),
    name = NULL) +
  labs(title = "S1 nonlinear — all metrics vs signal strength (mean over rho)",
       x = "dt (signal strength)", y = NULL) + th_sim() +
  theme(legend.position = "bottom")
dir.create(here::here("results/simulated_brief/figures"), recursive = TRUE, showWarnings = FALSE)
ggsave(here::here("results/simulated_brief/figures/_sim_all_metrics_S1_example.png"),
       exfig, width = 11, height = 7, dpi = 150)

message("\n[done] 全指标表 -> ", OUT,
        "\n  sim_all_metrics_by_rho.csv / sim_all_metrics_rho_summary.csv / sim_metrics_crosscheck.csv",
        "\n示例图 -> results/simulated_brief/figures/_sim_all_metrics_S1_example.png")
