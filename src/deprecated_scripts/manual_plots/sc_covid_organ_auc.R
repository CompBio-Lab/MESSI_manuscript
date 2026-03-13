# Helper to make a ribbon title
ribbon_title <- function(base_size=8, bg_color = "#2c3e50") {
  theme(
    plot.title = ggtext::element_textbox_simple(
      size = base_size+1, face = "bold", color = "white",
      fill = bg_color, padding = margin(5, 5, 5, 5),
      margin = margin(0, 0, 2, 0),
      halign = 0.5, width = unit(1, "npc"),
      r = unit(0, "pt")              # no rounded corners
    )
  )
}

library(ggplot2)
library(dplyr)
#library(ggtext)

source("src/common_helpers/save_plot_both.R")
source("src/common_helpers/plot_utils.R")
source("src/common_helpers/standardize_data_funs.R")
# --- Data ---
df <- data.table::fread("data/raw/sc_data/covid_data/metrics.csv") |>
  dplyr::rename(method = method_name) |>
  filter(dataset == "covid_organ") %>%
  mutate(
    dataset = str_replace_all(dataset, "_", " + ") |>
      tools::toTitleCase()
  ) |>
  dplyr::select(method, dataset, auc) %>%
  #standardize_method_names2() %>%

  filter(!str_detect(method, "-1")) %>%
  mutate(method = standardize_method_names(method, "perf")) %>%
  mutate(color_label = str_remove(method, "-.*") |> toupper()) %>%
  mutate(color_label = case_when(
    str_detect(color_label, "MOFA") ~ "MOFA",
    TRUE ~ color_label)
  )


text_size <- 48



out_plot <- df %>%
  ggplot(aes(x=reorder(method, auc), y=auc, fill=color_label)) +
  geom_bar(stat="identity", width=0.7) +
  theme_bw(base_size=text_size) +
  geom_hline(yintercept=0.5, linetype="dashed", linewidth=1.5, color="red") +
  scale_y_continuous(expand=expansion(mult = c(0, 0.12))) +
  scale_fill_manual(values=method_family_colors) +
  #coord_flip() +
  theme(
    plot.title         = element_text(hjust = 0.5),
    strip.background   = element_rect(fill = "grey95", color = "grey70"),
    strip.text         = element_text(face = "bold", size = 11),
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    legend.position    = "bottom"
  ) +
  ggtitle("Performance Evaluation of sc data only") +
  labs(
    x="Method", y="Mean AUC (5-fold CV)"
  )

the_plot <- out_plot + ggtitle("sc-COVID organ") + coord_flip() +
  theme(legend.position = "none") +
  ribbon_title(text_size) +
  ylab("AUC") +
  xlab(NULL)


ggsave("aaa.svg", the_plot, width=12, height=10, dpi=1200)
