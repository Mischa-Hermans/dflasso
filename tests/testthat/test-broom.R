test_that("tidy returns one row per feature with the contract columns", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  tidied <- tidy(fit)
  expect_s3_class(tidied, "tbl_df")
  expect_named(tidied, c("term", "estimate", "proxy_score", "adaptive_weight",
                         "penalty_factor", "role"))
  expect_equal(nrow(tidied), ncol(simulation$x))
  expect_setequal(tidied$term, colnames(simulation$x))
  expect_true(all(levels(tidied$role) %in%
    c("decision-relevant", "both", "prediction-relevant", "neither")))
})

test_that("glance returns the one-row model summary with source", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  glanced <- glance(fit)
  expect_equal(nrow(glanced), 1L)
  expect_named(glanced, c("nobs", "n_instances", "n_proxy_eligible",
                          "n_partial_coverage", "n_features", "n_selected",
                          "lambda_min", "lambda_1se", "sense",
                          "penalty_primary", "source", "seed"))
  expect_equal(glanced$source, "solver")
  expect_equal(glanced$n_features, ncol(simulation$x))
})

test_that("glance source reads 'supplied regret' for a BYOR fit", {
  simulation <- capital_fixture(n_scenarios = 8)
  regret <- named_regret(simulation$scenario)
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario, regret = regret,
    element_id = simulation$element_id, control = small_control()
  )
  expect_equal(glance(fit)$source, "supplied regret")
})

test_that("augment attaches .predicted_cost and the decision columns", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  augmented <- augment(fit, simulation$x, simulation$scenario,
                       element_id_new = simulation$element_id)
  expect_true(".predicted_cost" %in% names(augmented))
  expect_true(all(c(".decision", ".chosen", ".feasible") %in% names(augmented)))
  expect_equal(nrow(augmented), nrow(simulation$x))
})

test_that("augment joins newdata by id and keeps user columns", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  newdata <- data.frame(
    scenario = as.character(simulation$scenario),
    element_id = as.character(simulation$element_id),
    mine = seq_len(nrow(simulation$x)),
    stringsAsFactors = FALSE
  )
  augmented <- augment(fit, simulation$x, simulation$scenario,
                       element_id_new = simulation$element_id,
                       newdata = newdata)
  expect_true("mine" %in% names(augmented))
  expect_true(".predicted_cost" %in% names(augmented))
})

test_that("augment errors when newdata lacks the join keys", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  expect_error(
    augment(fit, simulation$x, simulation$scenario,
            element_id_new = simulation$element_id,
            newdata = data.frame(other = 1)),
    class = "dflasso_error_usage"
  )
})

test_that("as_tibble is long and its contributions total the objective", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  picks <- decide(fit, simulation$x, simulation$scenario,
                  element_id_new = simulation$element_id)
  long <- as_tibble(picks)
  expect_named(long, c("scenario", "element_id", "decision", "chosen",
                       "predicted_cost", "contribution", "feasible", "step"))
  expect_equal(nrow(long), nrow(simulation$x))

  totals <- tapply(long$contribution, long$scenario, sum)
  objective <- objectives(picks)
  expect_equal(as.numeric(totals[names(objective)]),
               as.numeric(objective), tolerance = 1e-8)
})
