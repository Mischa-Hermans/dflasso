test_that("summary reports a coherent kept count and role tally", {
  fit <- capital_fit()
  rendered_summary <- summary(fit)
  expect_s3_class(rendered_summary, "summary.DecisionFocusedLasso")
  kept_roles <- c("decision-relevant", "prediction-relevant", "both")
  expect_equal(
    rendered_summary$n_selected,
    sum(rendered_summary$role_counts[kept_roles])
  )
  expect_equal(sum(rendered_summary$role_counts), length(proxy_score(fit)))
})

test_that("summary of a BYOR fit shows the no-solver banner and changed settings", {
  simulation <- capital_fixture(n_scenarios = 8)
  regret <- named_regret(simulation$scenario)
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    regret = regret, element_id = simulation$element_id,
    control = small_control(kappa = 3)
  )
  rendered <- paste(
    dflasso:::format_dfl_summary(summary(fit)),
    collapse = "\n"
  )
  expect_match(rendered, "no solver attached", fixed = TRUE)
  expect_match(rendered, "kappa = 3", fixed = TRUE)
})

test_that("summary explains a reduced instance count when scenarios are set aside", {
  simulation <- capital_fixture(n_scenarios = 20)
  cost <- simulation$cost
  set_aside <- unique(simulation$scenario)[1:3]
  cost[simulation$scenario %in% set_aside] <- NA
  fit <- quiet_fit(
    simulation$x, cost, simulation$scenario,
    problem = capital_allocation_problem(max_weight = 0.5),
    element_id = simulation$element_id, control = small_control()
  )
  rendered <- paste(
    dflasso:::format_dfl_summary(summary(fit)),
    collapse = "\n"
  )
  expect_match(rendered, "17 of 20 instances scored", fixed = TRUE)
  expect_match(rendered, "set aside for missing or partial cost coverage")
})

test_that("summary omits the set-aside line when every instance is scored", {
  fit <- capital_fit()
  rendered <- paste(
    dflasso:::format_dfl_summary(summary(fit)),
    collapse = "\n"
  )
  expect_no_match(rendered, "set aside")
})

test_that("the summary render is stable", {
  fit <- capital_fit()
  expect_snapshot(summary(fit))
})
