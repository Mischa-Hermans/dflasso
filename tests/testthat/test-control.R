test_that("dfl_control returns the documented defaults", {
  control <- dfl_control()
  expect_s3_class(control, "dfl_control")
  expect_equal(control$n_splits, 15L)
  expect_equal(control$nfolds, 10L)
  expect_equal(control$gamma, 2)
  expect_equal(control$kappa, 6)
  expect_false(control$parallel)
  expect_true(control$standardize)
  expect_null(control$seed)
  expect_null(control$eligibility_threshold)
})

test_that("dfl_control rejects out-of-range values", {
  expect_error(dfl_control(nfolds = 0), class = "dflasso_error_value")
  expect_error(dfl_control(split_fraction = 1), class = "dflasso_error_value")
  expect_error(dfl_control(split_fraction = 0), class = "dflasso_error_value")
  expect_error(dfl_control(gamma = -1), class = "dflasso_error_value")
  expect_error(dfl_control(w_min = 600), class = "dflasso_error_value")
  expect_error(dfl_control(parallel = NA), class = "dflasso_error_value")
})

test_that("dfl_control rejects n_splits below 2", {
  expect_error(dfl_control(n_splits = 1L), class = "dflasso_error_value")
  expect_error(dfl_control(n_splits = 1L), "at least 2")
  expect_s3_class(dfl_control(n_splits = 2L), "dfl_control")
})

test_that("dfl_control rejects nfolds below 3 at the call", {
  expect_error(dfl_control(nfolds = 2L), class = "dflasso_error_value")
  expect_error(dfl_control(nfolds = 2L), "at least 3")
  expect_error(dfl_control(nfolds = 1L), "at least 3")
  expect_s3_class(dfl_control(nfolds = 3L), "dfl_control")
})

test_that("dfl_control rejects an unknown argument with a did-you-mean", {
  expect_error(dfl_control(seeed = 1), "did you mean 'seed'")
  expect_error(dfl_control(seeed = 1), class = "dflasso_error_usage")
})

test_that("dfl_control rejects a far-off argument without a suggestion", {
  expect_error(dfl_control(zzzzz = 1), "unknown control argument 'zzzzz'")
})

test_that("the tuned thresholds are the named vector the docs promise", {
  expect_named(dflasso_tuned_thresholds,
               c("shortest_path", "knapsack", "capital_allocation"))
  expect_equal(unname(dflasso_tuned_thresholds[["knapsack"]]), 20)
})

test_that("printing a control object lists both groups", {
  expect_output(print(dfl_control()), "main:")
  expect_output(print(dfl_control()), "method")
})
