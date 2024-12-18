get_all_counts_df <- function(feats_df, noise_label="noise", signal_label="signal") {
  # Should have method, dataset, feature_type columns

  feats_df %>%
    group_by(method, dataset, feature_type) %>%
    summarize(n = n()) %>%
    ungroup() %>%
    pivot_wider(names_from = "feature_type", values_from = "n") %>%
    rename(
      signal_count = !!signal_label,
      noise_count = !!noise_label
      ) %>%
    # From n_total to p_total
    mutate(p_total = noise_count + signal_count)
}


library(testthat)
n <- 39
signal_p_n <- floor(n * 0.3)
noise_p_n <- ceiling(n * 0.7)

dummy_df <- data.frame(
  feature = c(
    paste("signal_var", seq(signal_p_n), sep="_"),
    paste("noise_var", seq(noise_p_n), sep="_")),
  feature_type = c(rep("signal", signal_p_n), rep("noise", noise_p_n)),
  method = "test",
  dataset = "dset"
)



dummy_df %>%
  get_all_counts_df(noise_label="noise", signal_label="signal")


test_that("Getting expected results", {
  actual_df <- get_all_counts_df(dummy_df)
  expect_equal(actual_df$p_total[1], n)
  expect_equal(actual_df$signal_count[1], signal_p_n)
  expect_equal(actual_df$noise_count[1], noise_p_n)
})


