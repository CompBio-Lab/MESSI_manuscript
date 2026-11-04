# 03_sim_cost.R - per-task computational cost of the simulation run (supplementary figure).
# Source: Nextflow execution trace of the simulation job (data/processed/sim_src/sim_trace.txt =
# copy of RUN/execution_trace.txt). Scope (stated in the caption):
#   * Training   = one CROSS_VALIDATION *_TRAIN task = fitting one method on one outer-fold
#                  training set (400 samples x 3 x 3000 features), incl. any internal steps
#                  the method runs inside that task (e.g. caretMultimodal / Multiview
#                  internal lambda CV). Per-dataset PREPROCESS tasks (e.g. MOFA+ factor model
#                  preprocessing, run once per dataset) and PREDICT tasks are NOT included.
#   * Feature selection = one FEATURE_SELECTION *_SELECT_FEATURE task (full-data fit, n = 500).
#   * time = Nextflow `realtime` (task wall time, excludes queueing); memory = `peak_rss` (GiB).
#   * per method x dataset: median over the 5 folds; the figure shows the distribution over the
#     45 simulated multimodal datasets. Parallel tasks are NOT summed into a pipeline wall time.
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(here)
})
source(here::here("src/common_helpers/computational_resources_utils.R"))
source(here::here("src/simulated_brief/theme_simulation.R"))
OUT <- here::here("results/simulated_brief/data_derived")
TRACE <- here::here("data/processed/sim_src/sim_trace.txt")

tr <- read_tsv(TRACE, show_col_types = FALSE) %>%
  mutate(leaf = str_extract(process, "[^:]+$"),
         stage = case_when(str_detect(leaf, "_TRAIN$") ~ "Training",
                           str_detect(leaf, "_SELECT_FEATURE$") ~ "Feature selection",
                           TRUE ~ NA_character_)) %>%
  filter(!is.na(stage)) %>%
  mutate(prefix = str_remove(leaf, "_(TRAIN|SELECT_FEATURE)$"),
         dataset = str_extract(tag, "S\\d_[a-z]+_n-\\d+_p-\\d+_dt-\\d+_rho-[0-9p]+(-omic[123])?"),
         fold = str_extract(tag, "fold_\\d+"),
         design = str_extract(tag, "design_(full|null)"),
         sk = coalesce(str_match(tag, "-fold_\\d+-(Logit|MLP|Random_Forest|XGBoost)")[, 2],  # TRAIN tag
                       str_match(tag, "^(Logit|MLP|Random_Forest|XGBoost)-S\\d")[, 2]),       # SELECT tag
         raw = case_when(
           prefix == "SKLEARN" & !is.na(sk) ~ paste0("sklearn-", sk),
           prefix %in% c("DIABLO", "RGCCA") ~ paste0(tolower(prefix), "-", str_remove(design, "design_")),
           TRUE ~ tolower(prefix)),
         time_s = convert_to_seconds(realtime),
         mem_gib = convert_to_mb(peak_rss) / 1024)

sim <- parse_sim_id(tr$dataset)
mm <- map_method(tr$raw)
tr <- tr %>% mutate(is_single = sim$is_single, scenario = sim$scenario,
                    method = mm$method, class = mm$class, order = mm$order) %>%
  filter(!is.na(scenario), !is_single)

unmapped <- tr %>% filter(is.na(class)) %>% distinct(prefix, tag) %>% head(20)
if (nrow(unmapped)) { print(unmapped); stop("unmapped cost rows") }

# retried / duplicated tasks: keep every attempt visible in the log, use the median
task_counts <- tr %>% count(stage, method, dataset, fold) %>% filter(n > 1)
message("[cost] task keys with >1 trace row: ", nrow(task_counts))

cost_cfg <- tr %>% group_by(stage, method, class, order, dataset, scenario) %>%
  summarise(time_s = median(time_s, na.rm = TRUE), mem_gib = median(mem_gib, na.rm = TRUE),
            n_tasks = n(), .groups = "drop")
write_csv(cost_cfg, file.path(OUT, "cost_by_configuration.csv"))

cost_sum <- cost_cfg %>% group_by(stage, method, class, order) %>%
  summarise(n_datasets = n_distinct(dataset),
            time_med = median(time_s), time_q1 = quantile(time_s, .25), time_q3 = quantile(time_s, .75),
            mem_med = median(mem_gib), mem_q1 = quantile(mem_gib, .25), mem_q3 = quantile(mem_gib, .75),
            .groups = "drop") %>% arrange(stage, order)
write_csv(cost_sum, file.path(OUT, "cost_summary.csv"))
print(as.data.frame(cost_sum %>% mutate(across(where(is.numeric), ~ round(.x, 2)))))
message("[done] cost tables -> ", OUT)
