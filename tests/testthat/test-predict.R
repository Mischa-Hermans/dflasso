test_that("predict returns one predicted cost per row", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  predicted <- predict(fit, simulation$x)
  expect_type(predicted, "double")
  expect_length(predicted, nrow(simulation$x))
})

test_that("predict type coefficients and nonzero behave", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  coefficients <- predict(fit, simulation$x, type = "coefficients")
  expect_equal(rownames(coefficients)[[1]], "(Intercept)")

  kept <- predict(fit, simulation$x, type = "nonzero")
  expect_type(kept, "character")
  expect_true(all(kept %in% colnames(simulation$x)))
})

test_that("predict reads any of the three stages", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  for (stage in c("decision", "adaptive", "plain")) {
    predicted <- predict(fit, simulation$x, penalty = stage)
    expect_length(predicted, nrow(simulation$x))
  }
  expect_error(predict(fit, simulation$x, penalty = "nonsense"),
               class = "dflasso_error_usage")
})

test_that("coef returns the sparse vector including the intercept", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  coefficients <- coef(fit)
  expect_equal(nrow(coefficients), ncol(simulation$x) + 1L)
  expect_equal(rownames(coefficients)[[1]], "(Intercept)")
  expect_equal(rownames(coefficients)[-1], colnames(simulation$x))
})

test_that("a numeric lambda is accepted and a bad s is rejected", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  expect_length(predict(fit, simulation$x, s = lambda_min(fit)),
                nrow(simulation$x))
  expect_error(predict(fit, simulation$x, s = "lambda.bogus"),
               class = "dflasso_error_usage")
})

test_that("new data matched by name rejects a missing feature column", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  dropped <- simulation$x[, -1, drop = FALSE]
  expect_error(predict(fit, dropped, type = "response"),
               class = "dflasso_error_dimension")
})
