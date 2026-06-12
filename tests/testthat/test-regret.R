test_that("regret reports the comparison fields on the same instances", {
  simulation <- capital_fixture(n_scenarios = 20)
  fit <- capital_fit(simulation)
  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario
  )))

  expect_s3_class(result, "dfl_regret")
  expect_equal(result$baseline, "adaptive")
  expect_equal(result$n_instances, length(unique(simulation$scenario)))
  expect_equal(result$n_proxy_eligible, result$n_instances)
  expect_length(result$regret_per_instance, result$n_proxy_eligible)
  expect_length(result$regret_baseline_per_instance, result$n_proxy_eligible)
  expect_true(all(result$regret_per_instance >= 0))
  expect_true(all(result$regret_baseline_per_instance >= 0))
})

test_that("the printed signed percent is honest about direction", {
  simulation <- capital_fixture(n_scenarios = 20)
  fit <- capital_fit(simulation)
  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario
  )))
  rendered <- paste(dflasso:::format_dfl_regret(result), collapse = "\n")
  verb <- if (result$regret <= result$regret_baseline) "cut regret" else "RAISED regret"
  expect_match(rendered, verb, fixed = TRUE)
  expect_match(rendered, "Both approaches were compared on the same instances",
               fixed = TRUE)
})

test_that("regret with baseline none reports a single model", {
  simulation <- capital_fixture(n_scenarios = 16)
  fit <- capital_fit(simulation)
  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario,
    baseline = "none"
  )))
  expect_true(is.na(result$regret_baseline))
  expect_null(result$regret_baseline_per_instance)
})

test_that("regret excludes partial-coverage instances and counts them", {
  simulation <- capital_fixture(n_scenarios = 16)
  fit <- capital_fit(simulation)
  cost <- simulation$cost
  first_row_of_last <- which(simulation$scenario ==
                               tail(unique(simulation$scenario), 1L))[1]
  cost[first_row_of_last] <- NA
  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, cost, simulation$scenario
  )))
  expect_equal(result$n_partial_coverage, 1L)
  expect_lt(result$n_proxy_eligible, result$n_instances)
})

test_that("regret on a supplied-regret fit refuses for want of a solver", {
  simulation <- capital_fixture(n_scenarios = 8)
  regret_values <- named_regret(simulation$scenario)
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario, regret = regret_values,
    element_id = simulation$element_id, control = small_control()
  )
  expect_error(
    regret(fit, simulation$x, simulation$cost, simulation$scenario),
    class = "dflasso_error_no_solver"
  )
})

test_that("regret rejects a cost vector passed where the scenario id goes", {
  simulation <- capital_fixture(n_scenarios = 16)
  fit <- capital_fit(simulation)
  expect_error(
    regret(fit, simulation$x, simulation$cost, scenario_test = simulation$cost),
    class = "dflasso_error_usage"
  )
  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario
  )))
  expect_s3_class(result, "dfl_regret")
})

test_that("regret_from_objectives and regret_from_decisions clamp at zero", {
  from_objectives <- regret_from_objectives(
    scenario = c("a", "b", "c"),
    value_model = c(12, 9, 15), value_oracle = c(10, 9, 11), sense = "min"
  )
  expect_equal(from_objectives, c(a = 2, b = 0, c = 4))

  from_decisions <- regret_from_decisions(
    scenario = c("a", "a", "b", "b"),
    cost = c(3, 1, 2, 4),
    decision_model = c(1, 0, 0, 1),
    decision_oracle = c(0, 1, 1, 0),
    sense = "min"
  )
  expect_equal(unname(from_decisions[["a"]]), 2)
  expect_true(all(from_decisions >= 0))
})

test_that("regret counts an instance the model cannot solve but the oracle can", {
  simulation <- simulate_capital_allocation(10, 4, 6, seed = 2)
  problem <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      predicted_call <- !isTRUE(all.equal(costs, instance$realized))
      if (isTRUE(instance$starve) && predicted_call) {
        stop(structure(
          class = c("dflasso_infeasible", "error", "condition"),
          list(message = "planted", call = NULL)
        ))
      }
      as.numeric(costs <= stats::median(costs))
    }
  )
  fit_instances <- make_instances(
    simulation$scenario,
    realized = simulation$cost, starve = rep(FALSE, 10)
  )
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, instances = fit_instances,
    element_id = simulation$element_id, control = small_control()
  )
  test_instances <- make_instances(
    simulation$scenario,
    realized = simulation$cost, starve = c(rep(FALSE, 9), TRUE)
  )
  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario,
    instances_test = test_instances
  )))
  expect_gte(result$n_infeasible, 1L)
})

test_that("regret excludes and counts instances whose oracle solve fails", {
  simulation <- simulate_capital_allocation(10, 4, 6, seed = 2)
  problem <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      oracle_call <- isTRUE(all.equal(costs, instance$realized))
      if (isTRUE(instance$starve) && oracle_call) {
        stop(structure(
          class = c("dflasso_infeasible", "error", "condition"),
          list(message = "planted oracle failure", call = NULL)
        ))
      }
      as.numeric(costs <= stats::median(costs))
    }
  )
  fit_instances <- make_instances(
    simulation$scenario,
    realized = simulation$cost, starve = rep(FALSE, 10)
  )
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, instances = fit_instances,
    element_id = simulation$element_id, control = small_control()
  )
  test_instances <- make_instances(
    simulation$scenario,
    realized = simulation$cost, starve = c(rep(FALSE, 8), TRUE, TRUE)
  )

  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario,
    instances_test = test_instances
  )))

  expect_s3_class(result, "dfl_regret")
  expect_equal(result$n_infeasible, 2L)
  expect_length(result$regret_per_instance,
                result$n_proxy_eligible - result$n_infeasible)
  expect_length(result$regret_baseline_per_instance,
                result$n_proxy_eligible - result$n_infeasible)
  expect_true(all(is.finite(result$regret_per_instance)))
})

test_that("a custom solver infeasible on the predicted decision is excluded", {
  simulation <- simulate_capital_allocation(10, 4, 6, seed = 2)
  problem <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      predicted_call <- !isTRUE(all.equal(costs, instance$realized))
      if (isTRUE(instance$starve) && predicted_call) {
        stop(structure(
          class = c("dflasso_error_solver", "error", "condition"),
          list(message = "planted predicted failure", call = NULL)
        ))
      }
      as.numeric(costs <= stats::median(costs))
    }
  )
  fit_instances <- make_instances(
    simulation$scenario,
    realized = simulation$cost, starve = rep(FALSE, 10)
  )
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, instances = fit_instances,
    element_id = simulation$element_id, control = small_control()
  )
  test_instances <- make_instances(
    simulation$scenario,
    realized = simulation$cost, starve = c(rep(FALSE, 9), TRUE)
  )

  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario,
    instances_test = test_instances
  )))

  expect_equal(result$n_infeasible, 1L)
  expect_length(result$regret_per_instance,
                result$n_proxy_eligible - 1L)
})

test_that("the well-behaved regret numbers are unchanged by the solve guard", {
  simulation <- capital_fixture(n_scenarios = 20)
  fit <- capital_fit(simulation)
  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario
  )))

  expect_equal(result$n_infeasible, 0L)
  expect_length(result$regret_per_instance, result$n_proxy_eligible)
  expect_equal(result$regret, mean(result$regret_per_instance))
  expect_equal(result$regret_baseline,
               mean(result$regret_baseline_per_instance))
})

test_that("regret on an all-infeasible covered set returns and plots without error", {
  simulation <- simulate_capital_allocation(10, 4, 6, seed = 2)
  problem <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      if (isTRUE(instance$starve)) {
        stop(structure(
          class = c("dflasso_infeasible", "error", "condition"),
          list(message = "all infeasible", call = NULL)
        ))
      }
      as.numeric(costs <= stats::median(costs))
    }
  )
  fit_instances <- make_instances(
    simulation$scenario, starve = rep(FALSE, 10)
  )
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, instances = fit_instances,
    element_id = simulation$element_id, control = small_control()
  )
  test_instances <- make_instances(
    simulation$scenario, starve = rep(TRUE, 10)
  )

  result <- suppressWarnings(suppressMessages(regret(
    fit, simulation$x, simulation$cost, simulation$scenario,
    instances_test = test_instances
  )))

  expect_s3_class(result, "dfl_regret")
  expect_true(isTRUE(result$all_infeasible))
  expect_true(is.na(result$regret))
  expect_length(result$regret_per_instance, 0L)
  expect_equal(result$n_infeasible, result$n_proxy_eligible)

  rendered <- paste(dflasso:::format_dfl_regret(result), collapse = "\n")
  expect_match(rendered, "No instance could be scored", fixed = TRUE)
  expect_no_match(rendered, "100%", fixed = TRUE)

  expect_no_error(capture.output(print(result)))
  expect_s3_class(plot(result), "ggplot")
})

test_that("the verdict prints RAISED when decision regret exceeds the baseline", {
  raised <- structure(
    list(regret = 5, regret_baseline = 2, baseline = "adaptive",
         n_instances = 10, n_proxy_eligible = 10, n_partial_coverage = 0,
         n_infeasible = 0),
    class = "dfl_regret"
  )
  rendered <- paste(dflasso:::format_dfl_regret(raised), collapse = "\n")
  expect_match(rendered, "RAISED regret", fixed = TRUE)
})

test_that("the verdict is undefined when the baseline regret is zero", {
  zero <- structure(
    list(regret = 0, regret_baseline = 0, baseline = "adaptive",
         n_instances = 5, n_proxy_eligible = 5, n_partial_coverage = 0,
         n_infeasible = 0),
    class = "dfl_regret"
  )
  rendered <- paste(dflasso:::format_dfl_regret(zero), collapse = "\n")
  expect_match(rendered, "undefined", fixed = TRUE)
})
