# Custom palette for the methods
get_method_custom_colors <- function(method_palette="Paired") {
  # This fun is to match the color choices used for the methods
  custom_method_palette <-  RColorBrewer::brewer.pal(n = 12, name = method_palette)
  method_order_names <- c(
    "diablo-full_ncomp-1",
    "diablo-full_ncomp-2",
    "diablo-null_ncomp-1",
    "diablo-null_ncomp-2",
    "mofa-Factor1 + glmnet",
    "mofa-Factor2 + glmnet",
    "mogonet",
    "multiview",
    "rgcca-full_ncomp-1 + lda",
    "rgcca-null_ncomp-1 + lda",
    "rgcca-full_ncomp-2 + lda",
    "rgcca-null_ncomp-2 + lda"
  )
  names(custom_method_palette) <- method_order_names
  return(custom_method_palette)
}
