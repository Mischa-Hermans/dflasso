test_that("simulate_capital_allocation is bit-identical on a re-run", {
  expect_identical(
    simulate_capital_allocation(8, 5, 6, seed = 1),
    simulate_capital_allocation(8, 5, 6, seed = 1)
  )
})

test_that("simulate_capital_allocation returns the documented data shape", {
  simulation <- simulate_capital_allocation(8, 5, 6, seed = 1)
  expect_equal(nrow(simulation$data), 8 * 5)
  expect_true(all(
    c("feat_01", "feat_06", "realized_return", "scenario", "asset_id") %in%
      names(simulation$data)
  ))
  expect_s3_class(simulation$data$scenario, "factor")
  expect_equal(
    attr(simulation$data, "decision_relevant_features"),
    c("feat_01", "feat_02")
  )
})

test_that("the decision-relevant features vary across assets within a scenario", {
  simulation <- simulate_capital_allocation(8, 5, 6, seed = 1)
  scenario <- as.character(simulation$scenario)
  for (column in c("feat_01", "feat_02")) {
    within_variance <- tapply(simulation$x[, column], scenario, stats::var)
    expect_true(all(within_variance > 1e-8))
  }
})

test_that("simulate_knapsack is reproducible and carries weights", {
  expect_identical(
    simulate_knapsack(6, 5, 5, seed = 1),
    simulate_knapsack(6, 5, 5, seed = 1)
  )
  simulation <- simulate_knapsack(6, 5, 5, seed = 1)
  expect_true(all(
    c("realized_value", "scenario", "item_id", "weight") %in%
      names(simulation$data)
  ))
  expect_equal(
    attr(simulation$data, "decision_relevant_features"),
    c("feat_01", "feat_02")
  )
})

test_that("simulate_knapsack ships a binding capacity that fits straight through", {
  simulation <- simulate_knapsack(6, 5, 5, seed = 1)
  item_weights <- simulation$weights[seq_len(5)]
  expect_equal(simulation$capacity, as.integer(ceiling(0.5 * sum(item_weights))))
  expect_gt(simulation$capacity, min(item_weights))
  expect_lt(simulation$capacity, sum(item_weights))
  instances <- make_instances(
    simulation$scenario, weights = simulation$weights,
    capacity = simulation$capacity
  )
  expect_named(instances, as.character(unique(simulation$scenario)))
})

test_that("simulate_shortest_path is reproducible and returns every field", {
  expect_identical(
    simulate_shortest_path(10, 16, 8, seed = 1),
    simulate_shortest_path(10, 16, 8, seed = 1)
  )
  simulation <- simulate_shortest_path(10, 16, 8, seed = 1)
  expect_true(all(c(
    "arcs", "nodes", "training_days", "arc_day_features", "observed_times",
    "holdout_days", "tomorrow_days"
  ) %in% names(simulation)))
  expect_true(all(c(
    "congestion", "rainfall", "flood_depth", "mud_depth"
  ) %in% names(simulation$arc_day_features)))
})

test_that("a simulator with too few features fails loudly", {
  expect_error(
    simulate_capital_allocation(4, 3, 2, seed = 1),
    class = "dflasso_error_value"
  )
})
