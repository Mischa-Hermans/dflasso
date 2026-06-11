test_that("the four constructors build the right classes with fixed senses", {
  expect_s4_class(optimization_problem(function(costs, instance) costs), "FunctionProblem")
  expect_s4_class(shortest_path_problem(), "ShortestPathProblem")
  expect_s4_class(knapsack_problem(), "KnapsackProblem")
  expect_s4_class(capital_allocation_problem(), "CapitalAllocationProblem")

  expect_equal(sense(shortest_path_problem()), "min")
  expect_equal(sense(knapsack_problem()), "max")
  expect_equal(sense(capital_allocation_problem()), "max")
})

test_that("optimization_problem rejects a non-function solve", {
  expect_error(optimization_problem(solve = 1), "function")
})

test_that("shortest path solve_decision finds the least-cost route", {
  instance <- list(
    from = c(1L, 1L, 2L, 3L), to = c(2L, 3L, 4L, 4L),
    n_nodes = 4L, origin = 1L, destination = 4L
  )
  decision <- solve_decision(shortest_path_problem(), c(1, 4, 1, 1), instance)
  expect_equal(decision, c(1L, 0L, 1L, 0L))
})

test_that("shortest path solve_support returns the reachable arc set", {
  instance <- list(
    from = c(1L, 1L, 2L, 3L), to = c(2L, 3L, 4L, 4L),
    n_nodes = 4L, origin = 1L, destination = 4L
  )
  expect_equal(solve_support(shortest_path_problem(), instance), 1:4)
})

test_that("knapsack solves the same way through the DP and the LP fallback", {
  instance <- list(weights = c(10L, 20L, 30L), capacity = 50L)
  values <- c(60, 100, 120)
  dynamic <- solve_decision(knapsack_problem("dynamic_program"), values, instance)
  linear <- solve_decision(knapsack_problem("linear_program"), values, instance)
  expect_equal(dynamic, c(0L, 1L, 1L))
  expect_equal(linear, dynamic)
})

test_that("capital allocation solve_decision allocates a budget of one", {
  decision <- solve_decision(
    capital_allocation_problem(max_weight = 0.5),
    c(0.08, 0.03, 0.05), list(n_assets = 3)
  )
  expect_equal(sum(decision), 1)
  expect_true(all(decision <= 0.5 + 1e-8))
  expect_equal(decision[2], 0, tolerance = 1e-6)
  expect_equal(sort(decision[c(1, 3)]), c(0.5, 0.5), tolerance = 1e-6)
})

test_that("a per-instance max_weight overrides the problem default", {
  decision <- solve_decision(
    capital_allocation_problem(max_weight = 0.2),
    c(0.08, 0.03, 0.05), list(n_assets = 3, max_weight = 1)
  )
  expect_equal(sum(decision), 1)
  expect_equal(max(decision), 1)
})

test_that("an infeasible max_weight raises a classed dflasso_infeasible", {
  condition <- tryCatch(
    solve_decision(
      capital_allocation_problem(max_weight = 0.1),
      c(0.08, 0.03, 0.05), list(n_assets = 3)
    ),
    error = function(condition) condition
  )
  expect_s3_class(condition, "dflasso_infeasible")
  expect_match(conditionMessage(condition), "cannot sum to one")
  expect_match(conditionMessage(condition), "raise max_weight")
})

test_that("a FunctionProblem dispatches to the supplied solver", {
  problem <- optimization_problem(
    solve = function(costs, instance) as.numeric(costs <= stats::median(costs)),
    sense = "min"
  )
  expect_equal(solve_decision(problem, c(3, 1, 4, 2), list()), c(0, 1, 0, 1))
  expect_null(solve_support(problem, list()))
})

test_that("validity rejects a bad sense and a bad max_weight", {
  expect_error(capital_allocation_problem(max_weight = 1.5))
  expect_error(capital_allocation_problem(max_weight = 0))
  expect_error(methods::validObject(methods::new(
    "ShortestPathProblem", sense = "max", solve_function = NULL,
    solve_support_function = NULL,
    name = "bad", allow_unreachable = TRUE
  )))
  expect_error(methods::validObject(methods::new(
    "KnapsackProblem", sense = "max", solve_function = NULL,
    solve_support_function = NULL,
    name = "bad", solver = "nonsense"
  )))
})

test_that("an unreachable shortest path raises a classed dflasso_infeasible", {
  instance <- list(
    from = c(1L, 1L), to = c(2L, 3L),
    n_nodes = 4L, origin = 1L, destination = 4L
  )
  condition <- tryCatch(
    solve_decision(shortest_path_problem(), c(1, 1), instance),
    error = function(condition) condition
  )
  expect_s3_class(condition, "dflasso_infeasible")
  expect_match(conditionMessage(condition), "destination '4' unreachable")
})

test_that("show prints a plain one-line summary for each problem", {
  expect_output(show(shortest_path_problem()), "ShortestPathProblem")
  expect_output(show(knapsack_problem()), "KnapsackProblem")
  expect_output(show(capital_allocation_problem()), "CapitalAllocationProblem")
  expect_output(
    show(optimization_problem(function(costs, instance) costs, name = "mine")),
    "FunctionProblem"
  )
})
