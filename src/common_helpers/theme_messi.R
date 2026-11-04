# theme_messi.R - ONE house style for every MESSI figure (main + supp).
# Change things HERE, not in individual scripts, so all figures stay consistent.
#
# Rules:
#  * Design at final print size: main figures 7 in (178 mm) wide, <= 8.5 in tall; one page each.
#  * Look of the ORIGINAL manuscript figures: large bold capital panel tags (A, B, C),
#    thin dark panel border around each plot, generous font size, few panels per figure (3-5), a concept/design
#    panel on top where available. Base text 9 pt at print size; tags 14 pt bold
#    (patchwork plot_annotation(tag_levels = "A")).
#  * Panel titles short (<= 6 words) or none; the message belongs in the legend text, not the panel.
#  * Colour has ONE meaning per figure family:
#      - method identity  -> integration class (CLASS_COLORS) — methods named on the axis
#      - significance     -> SIG_COLORS (dark red = significant, grey = not)
#      - a 2-level contrast (e.g. vs mean / vs best single modality; training / model selection)
#                         -> PAIR_COLORS (never re-use class colours for this)
#    Don't colour points by cohort unless that is the point of the panel.
#  * Methods always in the SAME order (method_levels()), top = first. CD diagrams excepted.
#  * Legends at the bottom, shared across panels where possible (patchwork guides = "collect");
#    readable labels, never TRUE/FALSE.
#  * Reference lines (chance 0.5, zero gain) dashed grey50.
suppressPackageStartupMessages({library(ggplot2)})
if (!exists("method_label")) source(here::here("src/common_helpers/method_labels.R"))

CLASS_COLORS <- c(Early = "#2B6A9F", Intermediate = "#D68A2A", Late = "#3C8C63")
SIG_COLORS   <- c(significant = "#B2182B", `not significant` = "grey60")
PAIR_COLORS  <- c("#5E3C99", "#9E9AC8")      # dark / light purple for any 2-level contrast
REF_LINE     <- list(linetype = "dashed", colour = "grey50", linewidth = 0.4)

MAIN_WIDTH_IN <- 7
MAX_HEIGHT_IN <- 8.5

# Fixed method order (top -> bottom): Early baselines, Intermediate, Late.
method_levels <- function(present = NULL) {
  lv <- METHOD_LABELS$label[order(METHOD_LABELS$order)]
  if (is.null(present)) lv else lv[lv %in% present]
}
# For a y-axis with methods: factor so that the first method is at the TOP.
method_factor_y <- function(x) factor(x, levels = rev(method_levels(unique(x))))

theme_messi <- function(base_size = 9) {
  theme_minimal(base_size = base_size, base_family = "sans") +
    theme(
      text = element_text(colour = "black"),
      axis.text = element_text(colour = "black", size = rel(0.95)),
      axis.title = element_text(size = rel(1)),
      plot.title = element_text(face = "bold", size = rel(1.05), margin = margin(b = 3)),
      plot.subtitle = element_text(size = rel(0.9), colour = "grey30"),
      plot.tag = element_text(face = "bold", size = 14),
      panel.border = element_rect(colour = "grey25", fill = NA, linewidth = 0.4),
      strip.text = element_text(face = "bold", size = rel(0.95)),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "grey92", linewidth = 0.3),
      legend.position = "bottom",
      legend.title = element_text(size = rel(0.9)),
      legend.text = element_text(size = rel(0.9)),
      legend.key.size = unit(3.5, "mm"),
      plot.margin = margin(4, 6, 4, 4)
    )
}

scale_colour_class <- function(...) scale_colour_manual(values = CLASS_COLORS, name = "Integration", ...)
scale_fill_class   <- function(...) scale_fill_manual(values = CLASS_COLORS, name = "Integration", ...)
scale_colour_sig   <- function(...) scale_colour_manual(values = SIG_COLORS, name = NULL, ...)
sig_label <- function(is_sig) factor(ifelse(is_sig, "significant", "not significant"),
                                     levels = names(SIG_COLORS))

# Save a main figure at print size (png 300 dpi + pdf + rds via save_plot_both if available).
save_main <- function(p, path_no_ext, height = MAX_HEIGHT_IN, width = MAIN_WIDTH_IN) {
  stopifnot(height <= MAX_HEIGHT_IN + 1e-9)
  dir.create(dirname(path_no_ext), recursive = TRUE, showWarnings = FALSE)
  save_checked(paste0(path_no_ext, ".png"), p, width = width, height = height, dpi = 300)
  save_checked(paste0(path_no_ext, ".pdf"), p, width = width, height = height, device = cairo_pdf)  # cairo: keeps unicode (Δ, α, ±)
  saveRDS(p, paste0(path_no_ext, ".rds"))
  invisible(path_no_ext)
}

# On Windows the agg/cairo devices can fail to overwrite a file that another process briefly holds
# ("agg could not write to the given file") and ggsave only WARNS, leaving a stale image behind.
# Render to a temp file, copy over the target, verify the target was updated, retry, else stop().
save_checked <- function(file, p, ..., tries = 3) {
  ext <- tools::file_ext(file)
  for (i in seq_len(tries)) {
    tmp <- tempfile(fileext = paste0(".", ext))
    ok <- tryCatch({
      withCallingHandlers(ggsave(tmp, p, bg = "white", ...),
                          warning = function(w) if (grepl("could not write", conditionMessage(w))) stop(w))
      file.exists(tmp) && file.copy(tmp, file, overwrite = TRUE)
    }, error = function(e) FALSE)
    unlink(tmp)
    if (isTRUE(ok) && difftime(Sys.time(), file.info(file)$mtime, units = "secs") < 60) return(invisible(file))
    Sys.sleep(1)
  }
  stop("save_checked: could not write ", file, " (file locked? close any viewer holding it)")
}

# --- Method names on an axis are ALWAYS coloured by integration class (all figures) ------------
# Data marks may use colour for a panel-specific meaning (significance, dataset, ...); the method
# LABELS keep the class colour so readers always see Early / Intermediate / Late.
# (ggtext markdown labels do not render with ggplot2 4.0 here, so we colour axis text per level.)
# Usage:  p + theme_method_axis(levels(d$method))            # y-axis (levels = bottom -> top order)
#         p + theme_method_axis(levels(d$method), axis = "x")
theme_method_axis <- function(levels, axis = c("y", "x")) {
  axis <- match.arg(axis)
  cols <- unname(CLASS_COLORS[method_class(levels)]); cols[is.na(cols)] <- "black"
  el <- suppressWarnings(element_text(colour = cols))
  if (axis == "y") theme(axis.text.y = el) else theme(axis.text.x = el)
}
# kept for backwards compatibility: plain discrete scales (no markup)
scale_y_method <- function(...) scale_y_discrete(...)
scale_x_method <- function(...) scale_x_discrete(...)
