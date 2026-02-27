library(tidyverse)

# ── 1. Load & filter ──────────────────────────────────────────────────────────
df <- multimodal_msigdbr_df   # your tibble

sig <- df %>% filter(padj < 0.05)

# ── 2. Method rename ──────────────────────────────────────────────────────────
method_rename <- c(
  "caret_multimodal"         = "caret_multimodal",
  "diablo-full-ncomp-1"      = "DIABLO-full-ncomp-1",
  "diablo-full-ncomp-2"      = "DIABLO-full-ncomp-2",
  "diablo-null-ncomp-1"      = "DIABLO-null-ncomp-1",
  "diablo-null-ncomp-2"      = "DIABLO-null-ncomp-2",
  "integrao"                 = "integrao",
  "mofa-Factor1 + glmnet"    = "MOFA-Factor1 + glmnet",
  "mofa-Factor2 + glmnet"    = "MOFA-Factor2 + glmnet",
  "mogonet"                  = "MOGONET",
  "multiview"                = "multiview",
  "rgcca-full-ncomp-1 + lda" = "RGCCA-full-ncomp-1 + lda",
  "rgcca-full-ncomp-2 + lda" = "RGCCA-full-ncomp-2 + lda",
  "rgcca-null-ncomp-1 + lda" = "RGCCA-null-ncomp-1 + lda",
  "rgcca-null-ncomp-2 + lda" = "RGCCA-null-ncomp-2 + lda"
)

sig <- sig %>%
  mutate(method_label = recode(method, !!!method_rename))

# ── 3. Best (lowest padj) per pathway × method ────────────────────────────────
best_per_method <- sig %>%
  group_by(pathway, method_label) %>%
  slice_min(padj, n = 1, with_ties = FALSE) %>%
  ungroup()

# ── 4. Select top pathways (significant in >=8 methods) ───────────────────────
pathway_method_count <- best_per_method %>%
  group_by(pathway) %>%
  summarise(n_methods = n_distinct(method_label), .groups = "drop")

top_pathways <- pathway_method_count %>%
  filter(n_methods >= 8) %>%
  pull(pathway)

if (length(top_pathways) < 10) {
  top_pathways <- pathway_method_count %>%
    slice_max(n_methods, n = 25) %>%
    pull(pathway)
  message("Using top 25 pathways instead")
}

# ── 5. Clean pathway names ────────────────────────────────────────────────────
clean_pathway <- function(name) {
  name <- str_remove(name, "^REACTOME_")
  name <- str_replace_all(name, "_", " ")
  name <- str_to_title(name)
  if (nchar(name) > 55) name <- paste0(substr(name, 1, 52), "...")
  name
}

# ── 6. Build plot data ────────────────────────────────────────────────────────
plot_data <- best_per_method %>%
  filter(pathway %in% top_pathways) %>%
  mutate(
    pathway_label  = map_chr(pathway, clean_pathway),
    neg_log10_padj = -log10(pmax(padj, 1e-10))
  )

# Axis orderings
method_order <- sig %>%
  dplyr::count(method_label, sort = TRUE) %>%
  pull(method_label) %>%
  unique()   # <-- add this

pathway_order <- plot_data %>%
  group_by(pathway_label) %>%
  summarise(n = n_distinct(method_label), .groups = "drop") %>%
  arrange(n) %>%          # ascending → most shared at top in ggplot
  pull(pathway_label) %>%
  unique()

plot_data <- plot_data %>%
  mutate(
    method_label  = factor(method_label,  levels = method_order),
    pathway_label = factor(pathway_label, levels = pathway_order)
  )


# Full grid (so missing combos show as grey dots)
full_grid <- expand_grid(
  method_label  = factor(method_order,  levels = method_order),
  pathway_label = factor(pathway_order, levels = pathway_order)
)

plot_data_full <- full_grid %>%
  left_join(plot_data, by = c("method_label", "pathway_label"))

# ── 7. Plot ───────────────────────────────────────────────────────────────────
#library(tidyverse)
library(RColorBrewer)
library(scales)

bg_col <- "#FAF9F3"

p <- ggplot() +
  # Grey dots for non-significant — tiny, barely visible
  geom_point(
    data = filter(plot_data_full, is.na(neg_log10_padj)),
    aes(x = method_label, y = pathway_label),
    shape = 21,
    size  = 0.8,
    fill  = "#D0CEC8",
    colour = NA,
    alpha = 0.4
  ) +
  # Significant dots
  geom_point(
    data = filter(plot_data_full, !is.na(neg_log10_padj)),
    aes(x     = method_label,
        y     = pathway_label,
        size  = neg_log10_padj,
        fill  = NES),
    shape  = 21,
    colour = "#555555",
    stroke = 0.25,
    alpha  = 0.92
  ) +
  scale_fill_gradientn(
    colours = rev(brewer.pal(11, "RdBu")),
    limits  = c(1.0, 2.5),
    oob     = squish,
    name    = "NES",
    guide   = guide_colorbar(
      barheight    = unit(6, "cm"),
      barwidth     = unit(0.4, "cm"),
      ticks.colour = "grey40",
      frame.colour = "grey40"
    )
  ) +
  scale_size_continuous(
    range  = c(0.5, 7),
    name   = expression(-log[10](padj)),
    breaks = c(1, 2, 4, 6),
    labels = c("1", "2", "4", "6")
  ) +
  scale_x_discrete(position = "bottom") +
  labs(
    title = "Top Shared Reactome Pathways Across Methods\n(padj < 0.05)",
    x     = "Method",
    y     = "Pathway"
  ) +
  theme_minimal(base_size = 8.5) +
  theme(
    plot.background    = element_rect(fill = bg_col, colour = NA),
    panel.background   = element_rect(fill = bg_col, colour = NA),
    panel.grid.major   = element_line(colour = "#ECE9E2", linewidth = 0.4),
    panel.grid.minor   = element_blank(),

    # x-axis: rotated, right-aligned, more space
    axis.text.x        = element_text(angle = 45, hjust = 1, vjust = 1,
                                      size = 7.5, colour = "grey20"),
    axis.text.y        = element_text(size = 7.5, colour = "grey20"),
    axis.title.x       = element_text(size = 9, margin = margin(t = 8)),
    axis.title.y       = element_text(size = 9, margin = margin(r = 8)),

    plot.title         = element_text(face = "bold", size = 11,
                                      hjust = 0.5, margin = margin(b = 10)),
    plot.margin        = margin(10, 10, 10, 10),

    legend.background  = element_rect(fill = bg_col, colour = NA),
    legend.key         = element_rect(fill = bg_col, colour = NA),
    legend.title       = element_text(size = 8),
    legend.text        = element_text(size = 7.5),
    legend.spacing.y   = unit(0.3, "cm")
  ) +
  guides(
    size = guide_legend(
      title          = expression(-log[10](padj)),
      override.aes   = list(fill = "grey60", colour = "#555555", stroke = 0.25),
      order          = 2
    ),
    fill = guide_colorbar(order = 1)
  )

ggsave("dotplot_pathways_methods.png", p,
       width = 14, height = 11, dpi = 150, bg = bg_col)
ggsave("dotplot_pathways_methods.svg", p,
       width = 14, height = 11, bg = bg_col)
p
