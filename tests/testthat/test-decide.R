test_that("decide returns named allocation weights that sum to one", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  picks <- decide(fit, simulation$x, simulation$scenario,
                  element_id_new = simulation$element_id)
  expect_s4_class(picks, "DecisionSet")

  first <- decisions(picks)[[1]]
  expect_named(first)
  expect_equal(sum(first), 1, tolerance = 1e-6)
  expect_equal(unname(objectives(picks)), unname(objectives(picks)))
  expect_true(all(is_feasible(picks)))
})

test_that("an infeasible instance comes back feasible = FALSE without aborting", {
  simulation <- simulate_capital_allocation(8, 4, 6, seed = 2)
  problem <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      if (isTRUE(instance$infeasible)) {
        stop(structure(
          class = c("dflasso_infeasible", "error", "condition"),
          list(message = "planted infeasible", call = NULL)
        ))
      }
      as.numeric(costs <= stats::median(costs))
    }
  )
  fit_instances <- make_instances(simulation$scenario,
                                  infeasible = rep(FALSE, 8))
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, instances = fit_instances,
    element_id = simulation$element_id, control = small_control()
  )
  decide_instances <- make_instances(simulation$scenario,
                                     infeasible = c(rep(FALSE, 7), TRUE))
  picks <- decide(fit, simulation$x, simulation$scenario,
                  instances_new = decide_instances,
                  element_id_new = simulation$element_id)

  expect_equal(nrow(picks@records), 8L)
  expect_equal(sum(!is_feasible(picks)), 1L)
  failing <- decisions(picks)[[which(!is_feasible(picks))]]
  expect_length(failing, 0L)
  expect_true(is.numeric(failing))
})

test_that("an infeasible max_weight marks one instance feasible = FALSE via decide", {
  simulation <- capital_fixture(n_scenarios = 6, n_assets = 12)
  fit <- capital_fit(simulation, max_weight = 0.1)

  ids <- as.character(unique(simulation$scenario))
  starved_id <- ids[[1L]]
  scenario_chr <- as.character(simulation$scenario)
  in_starved <- scenario_chr == starved_id
  position_in_scenario <- stats::ave(
    seq_along(scenario_chr), scenario_chr, FUN = seq_along
  )
  keep <- !in_starved | position_in_scenario <= 3L

  picks <- decide(
    fit,
    simulation$x[keep, , drop = FALSE],
    simulation$scenario[keep],
    element_id_new = simulation$element_id[keep]
  )

  expect_equal(nrow(picks@records), length(ids))
  expect_false(is_feasible(picks)[[starved_id]])
  expect_true(all(is_feasible(picks)[setdiff(ids, starved_id)]))
  expect_match(infeasible_reasons(picks)$message, "cannot sum to one")
  weights <- decisions(picks)[[ids[[2L]]]]
  expect_equal(sum(weights), 1, tolerance = 1e-6)
})

test_that("feasible and infeasible partition the decision set", {
  simulation <- simulate_capital_allocation(8, 4, 6, seed = 2)
  problem <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      if (isTRUE(instance$infeasible)) {
        stop(structure(
          class = c("dflasso_infeasible", "error", "condition"),
          list(message = "planted infeasible", call = NULL)
        ))
      }
      as.numeric(costs <= stats::median(costs))
    }
  )
  fit_instances <- make_instances(simulation$scenario,
                                  infeasible = rep(FALSE, 8))
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, instances = fit_instances,
    element_id = simulation$element_id, control = small_control()
  )
  decide_instances <- make_instances(simulation$scenario,
                                     infeasible = c(rep(FALSE, 7), TRUE))
  picks <- decide(fit, simulation$x, simulation$scenario,
                  instances_new = decide_instances,
                  element_id_new = simulation$element_id)

  expect_equal(
    nrow(feasible(picks)@records) + nrow(infeasible(picks)@records),
    nrow(picks@records)
  )
  reasons <- infeasible_reasons(picks)
  expect_named(reasons, c("scenario", "message"))
  expect_equal(nrow(reasons), 1L)
})

test_that("decide on a supplied-regret fit errors then works with problem =", {
  simulation <- capital_fixture(n_scenarios = 8)
  regret <- named_regret(simulation$scenario)
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario, regret = regret,
    element_id = simulation$element_id, control = small_control()
  )
  expect_error(
    decide(fit, simulation$x, simulation$scenario,
           element_id_new = simulation$element_id),
    class = "dflasso_error_no_solver"
  )
  picks <- decide(
    fit, simulation$x, simulation$scenario,
    element_id_new = simulation$element_id,
    problem = capital_allocation_problem(max_weight = 0.5)
  )
  expect_s4_class(picks, "DecisionSet")
})

test_that("attaching a problem when the fit already has one errors", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  expect_error(
    decide(fit, simulation$x, simulation$scenario,
           element_id_new = simulation$element_id,
           problem = capital_allocation_problem()),
    class = "dflasso_error_usage"
  )
})

test_that("a wrong-length decision at decide time fails only that instance", {
  simulation <- simulate_capital_allocation(8, 4, 6, seed = 2)
  problem <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      decision <- as.numeric(costs <= stats::median(costs))
      if (isTRUE(instance$truncate)) decision[-1] else decision
    }
  )
  fit_instances <- make_instances(simulation$scenario,
                                  truncate = rep(FALSE, 8))
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, instances = fit_instances,
    element_id = simulation$element_id, control = small_control()
  )
  decide_instances <- make_instances(simulation$scenario,
                                     truncate = c(rep(FALSE, 7), TRUE))
  picks <- decide(fit, simulation$x, simulation$scenario,
                  instances_new = decide_instances,
                  element_id_new = simulation$element_id)

  expect_equal(nrow(picks@records), 8L)
  expect_equal(sum(!is_feasible(picks)), 1L)
  expect_match(infeasible_reasons(picks)$message, "expected")
})

test_that("a non-finite decision at decide time fails only that instance", {
  simulation <- simulate_capital_allocation(8, 4, 6, seed = 2)
  problem <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      decision <- as.numeric(costs <= stats::median(costs))
      if (isTRUE(instance$spoil)) decision[1] <- Inf
      decision
    }
  )
  fit_instances <- make_instances(simulation$scenario, spoil = rep(FALSE, 8))
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, instances = fit_instances,
    element_id = simulation$element_id, control = small_control()
  )
  decide_instances <- make_instances(simulation$scenario,
                                     spoil = c(rep(FALSE, 7), TRUE))
  picks <- decide(fit, simulation$x, simulation$scenario,
                  instances_new = decide_instances,
                  element_id_new = simulation$element_id)

  expect_equal(nrow(picks@records), 8L)
  expect_equal(sum(!is_feasible(picks)), 1L)
  expect_match(infeasible_reasons(picks)$message, "non-finite")
})

test_that("decide rejects a cost vector passed where the scenario id goes", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  expect_error(
    decide(fit, simulation$x, simulation$cost,
           element_id_new = simulation$element_id),
    class = "dflasso_error_usage"
  )
  picks <- decide(fit, simulation$x, simulation$scenario,
                  element_id_new = simulation$element_id)
  expect_s4_class(picks, "DecisionSet")
})

test_that("the decision-set printout is stable", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  picks <- decide(fit, simulation$x, simulation$scenario,
                  element_id_new = simulation$element_id)
  expect_snapshot(picks)
})
