test_that("the decision focus has lower held-out regret than the baseline on the demo", {
  skip_on_cran()
  data("capital_allocation_demo", package = "dflasso")
  problem <- capital_allocation_problem(max_weight = 0.5)

  train <- subset(capital_allocation_demo, split == "train")
  test <- subset(capital_allocation_demo, split == "test")

  prepared_train <- dfl_data(
    train,
    features = starts_with("feat_"), cost = realized_return,
    scenario = scenario, element_id = asset_id
  )
  prepared_test <- dfl_data(
    test,
    features = starts_with("feat_"), cost = realized_return,
    scenario = scenario, element_id = asset_id
  )

  fit <- quiet_fit(
    prepared_train$x, prepared_train$cost, prepared_train$scenario,
    problem = problem, element_id = prepared_train$element_id,
    control = dfl_control(seed = 1, progress = FALSE)
  )
  result <- suppressWarnings(suppressMessages(regret(
    fit, prepared_test$x, prepared_test$cost, prepared_test$scenario
  )))

  expect_lt(result$regret, result$regret_baseline)
})
