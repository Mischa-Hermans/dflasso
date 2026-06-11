test_that("a fit produces all three lasso stages on one fold structure", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  expect_s4_class(fit, "DecisionFocusedLasso")
  expect_s3_class(fit@decision_fit, "cv.glmnet")
  expect_s3_class(fit@adaptive_fit, "cv.glmnet")
  expect_s3_class(fit@plain_fit, "cv.glmnet")
  expect_length(proxy_score(fit), ncol(simulation$x))
  expect_length(penalty_factor(fit), ncol(simulation$x))
  expect_length(adaptive_weight(fit), ncol(simulation$x))
})

test_that("a fit is reproducible from the seed", {
  simulation <- capital_fixture()
  first <- capital_fit(simulation)
  second <- capital_fit(simulation)
  expect_equal(proxy_score(first), proxy_score(second))
  expect_equal(penalty_factor(first), penalty_factor(second))
  expect_equal(as.numeric(coef(first)), as.numeric(coef(second)))
})

test_that("a sequential fit equals a parallel fit bit-for-bit", {
  skip_on_cran()
  simulation <- capital_fixture()
  problem <- capital_allocation_problem(max_weight = 0.5)
  sequential <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, element_id = simulation$element_id,
    control = small_control()
  )
  parallel <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, element_id = simulation$element_id,
    control = small_control(workers = 2L)
  )
  expect_equal(proxy_score(sequential), proxy_score(parallel))
  expect_equal(penalty_factor(sequential), penalty_factor(parallel))
  expect_equal(as.numeric(coef(sequential)), as.numeric(coef(parallel)))
})

test_that("progress = FALSE is silent and progress = TRUE prints status", {
  simulation <- capital_fixture()
  problem <- capital_allocation_problem(max_weight = 0.5)
  expect_silent(
    dfl_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = problem, element_id = simulation$element_id,
      control = dfl_control(n_splits = 3L, seed = 1L, progress = FALSE)
    )
  )
  expect_message(
    dfl_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = problem, element_id = simulation$element_id,
      control = dfl_control(n_splits = 3L, seed = 1L, progress = TRUE)
    ),
    "Scoring features"
  )
})

test_that("the proxy ranks the planted decision features highest", {
  simulation <- capital_fixture(n_scenarios = 25)
  fit <- capital_fit(simulation)
  scores <- proxy_score(fit)
  top_two <- names(sort(scores, decreasing = TRUE))[1:2]
  expect_setequal(top_two, c("feat_01", "feat_02"))
})

test_that("thin coverage warns at the default resample count", {
  simulation <- capital_fixture(n_scenarios = 12)
  expect_warning(
    suppressMessages(dfl_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = capital_allocation_problem(max_weight = 0.5),
      element_id = simulation$element_id,
      control = dfl_control(seed = 1, progress = FALSE)
    )),
    class = "dflasso_warning_value"
  )
})

test_that("zero eligible scenarios is a loud coverage error", {
  simulation <- capital_fixture(n_scenarios = 8)
  cost <- simulation$cost
  cost[!duplicated(as.character(simulation$scenario))] <- NA
  expect_error(
    suppressMessages(suppressWarnings(dfl_fit(
      simulation$x, cost, simulation$scenario,
      problem = capital_allocation_problem(max_weight = 0.5),
      element_id = simulation$element_id, control = small_control()
    ))),
    class = "dflasso_error_coverage"
  )
})

test_that("all-NA cost is rejected before any model is fit", {
  simulation <- capital_fixture(n_scenarios = 8)
  cost <- rep(NA_real_, length(simulation$cost))
  expect_error(
    suppressMessages(dfl_fit(
      simulation$x, cost, simulation$scenario,
      problem = capital_allocation_problem(max_weight = 0.5),
      element_id = simulation$element_id, control = small_control()
    )),
    "Every value in cost is NA"
  )
})

test_that("a character cost is rejected up front, but numeric cost still fits", {
  simulation <- capital_fixture(n_scenarios = 8)
  failure <- tryCatch(
    suppressMessages(dfl_fit(
      simulation$x, as.character(simulation$cost), simulation$scenario,
      problem = capital_allocation_problem(max_weight = 0.5),
      element_id = simulation$element_id, control = small_control()
    )),
    error = function(condition) condition
  )
  expect_s3_class(failure, "dflasso_error_usage")
  expect_match(conditionMessage(failure), "cost is character, not numeric")
  expect_no_match(conditionMessage(failure), "Every value in cost is NA")
  expect_s4_class(capital_fit(simulation), "DecisionFocusedLasso")
})

test_that("a too-small modelling set stops with a dflasso usage error, not glmnet", {
  simulation <- capital_fixture(n_scenarios = 8)
  failure <- tryCatch(
    suppressMessages(dfl_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = capital_allocation_problem(max_weight = 0.5),
      element_id = simulation$element_id,
      control = small_control(min_elements_per_scenario = 100L)
    )),
    error = function(condition) condition
  )
  expect_s3_class(failure, "dflasso_error_usage")
  expect_match(conditionMessage(failure), "min_elements_per_scenario")
  expect_no_match(conditionMessage(failure), "nfolds must be bigger")
})

test_that("fewer scenarios than nfolds reduces folds with a warning, not an error", {
  simulation <- capital_fixture(n_scenarios = 5)
  run_fit <- function() {
    suppressMessages(dfl_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = capital_allocation_problem(max_weight = 0.5),
      element_id = simulation$element_id,
      control = dfl_control(seed = 1, n_splits = 3L, progress = FALSE)
    ))
  }
  expect_warning(run_fit(), "reduced to 5 folds")
  fit <- suppressWarnings(run_fit())
  expect_s4_class(fit, "DecisionFocusedLasso")
  expect_equal(fit@control$nfolds, 5L)
})

test_that("a single structural problem prints without a bullet prefix", {
  simulation <- capital_fixture(n_scenarios = 8)
  failure <- tryCatch(
    suppressMessages(suppressWarnings(dfl_fit(
      simulation$x, simulation$cost, simulation$scenario[-1],
      problem = capital_allocation_problem(max_weight = 0.5),
      element_id = simulation$element_id, control = small_control()
    ))),
    error = function(condition) condition
  )
  expect_false(startsWith(conditionMessage(failure), "- "))
})

test_that("two structural problems render as a bulleted list", {
  expect_match(
    dflasso:::report_problems_body(c("first problem", "second problem")),
    "^- first problem\n- second problem$"
  )
})

test_that("capital allocation auto-builds instances from the scenario", {
  simulation <- capital_fixture()
  fit <- capital_fit(simulation)
  expect_equal(fit@n_proxy_eligible, length(unique(simulation$scenario)))
})

test_that("dfl_fit on a data frame with features = guides to dfl_data", {
  frame <- data.frame(
    feat_a = rnorm(12), feat_b = rnorm(12),
    scenario = rep(c("s1", "s2", "s3"), each = 4),
    regret = rep(c(1.0, 2.0, 3.0), each = 4)
  )
  failure <- tryCatch(
    suppressMessages(dfl_fit(
      frame,
      features = starts_with("feat_"),
      scenario = scenario, regret = regret
    )),
    error = function(condition) condition
  )
  expect_s3_class(failure, "dflasso_error_usage")
  expect_match(conditionMessage(failure), "dfl_data()", fixed = TRUE)
  expect_no_match(conditionMessage(failure), "unused argument", fixed = TRUE)
})

test_that("a knapsack fit demands instances rather than inventing them", {
  simulation <- simulate_knapsack(8, 5, 5, seed = 1)
  expect_error(
    suppressMessages(dfl_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = knapsack_problem(), element_id = simulation$item_id,
      control = small_control()
    )),
    class = "dflasso_error_usage"
  )
})

test_that("a knapsack fit runs once instances are supplied", {
  simulation <- knapsack_fixture()
  fit <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = knapsack_problem(), instances = simulation$instances,
    element_id = simulation$item_id, control = small_control()
  )
  expect_s4_class(fit, "DecisionFocusedLasso")
})

test_that("dfl_fit insists on exactly one of problem or regret", {
  simulation <- capital_fixture(n_scenarios = 8)
  regret <- named_regret(simulation$scenario)
  expect_error(
    suppressMessages(dfl_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = capital_allocation_problem(max_weight = 0.5),
      regret = regret, control = small_control()
    )),
    class = "dflasso_error_usage"
  )
  expect_error(
    suppressMessages(dfl_fit(
      simulation$x, simulation$cost, simulation$scenario,
      control = small_control()
    )),
    class = "dflasso_error_usage"
  )
})

test_that("regret without cost routes the user to dfl_score", {
  simulation <- capital_fixture(n_scenarios = 8)
  regret <- named_regret(simulation$scenario)
  expect_error(
    suppressMessages(dfl_fit(
      simulation$x, scenario = simulation$scenario, regret = regret,
      control = small_control()
    )),
    "dfl_score"
  )
})

test_that("a solver returning a wrong-length decision is caught at the probe", {
  simulation <- capital_fixture(n_scenarios = 8)
  bad <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) costs[-1]
  )
  expect_error(
    quiet_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = bad, element_id = simulation$element_id,
      control = small_control()
    ),
    class = "dflasso_error_solver"
  )
})

test_that("a solver returning non-finite values is caught at the probe", {
  simulation <- capital_fixture(n_scenarios = 8)
  bad <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) {
      decision <- rep(0, length(costs))
      decision[1] <- Inf
      decision
    }
  )
  expect_error(
    quiet_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = bad, element_id = simulation$element_id,
      control = small_control()
    ),
    class = "dflasso_error_solver"
  )
})

test_that("a solver that errors surfaces as a solver error", {
  simulation <- capital_fixture(n_scenarios = 8)
  bad <- optimization_problem(
    sense = "min",
    solve = function(costs, instance) stop("boom")
  )
  expect_error(
    quiet_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = bad, element_id = simulation$element_id,
      control = small_control()
    ),
    class = "dflasso_error_solver"
  )
})

test_that("instances with wrong names are rejected naming the missing ids", {
  simulation <- knapsack_fixture()
  bad <- simulation$instances
  names(bad)[1] <- "not_a_scenario"
  expect_error(
    quiet_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = knapsack_problem(), instances = bad,
      element_id = simulation$item_id, control = small_control()
    ),
    class = "dflasso_error_usage"
  )
})

test_that("an unnamed instances list is rejected", {
  simulation <- knapsack_fixture()
  expect_error(
    quiet_fit(
      simulation$x, simulation$cost, simulation$scenario,
      problem = knapsack_problem(),
      instances = unname(simulation$instances),
      element_id = simulation$item_id, control = small_control()
    ),
    class = "dflasso_error_usage"
  )
})

test_that("a 2-worker fit runs and matches the sequential fit", {
  skip_on_cran()
  simulation <- capital_fixture(n_scenarios = 10)
  problem <- capital_allocation_problem(max_weight = 0.5)
  sequential <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, element_id = simulation$element_id,
    control = small_control()
  )
  parallel <- quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = problem, element_id = simulation$element_id,
    control = small_control(workers = 2L)
  )
  expect_equal(proxy_score(sequential), proxy_score(parallel))
  expect_equal(penalty_factor(sequential), penalty_factor(parallel))
  expect_equal(as.numeric(coef(sequential)), as.numeric(coef(parallel)))
})
