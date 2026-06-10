#' Wrap a custom solver as a dflasso problem
#'
#' Builds a problem from a custom solver, for the case where no built-in fits.
#' Supply one function that turns a vector of predicted costs into a decision,
#' plus the objective sense, and dflasso treats it like any other problem.
#'
#' @param solve A function of `(costs, instance)` returning the decision
#'   vector for that instance. Its length and row order match `costs`.
#' @param sense Objective direction for `cost' decision`, `"min"` (default) or
#'   `"max"`.
#' @param solve_support Optional function of one argument (the instance)
#'   returning the integer row indices the solver could use in a feasible
#'   decision. This sets the coverage rule: a scenario is eligible for the
#'   decision-quality step only when every row in its support has an observed
#'   cost. `NULL` (default) assumes every row of an instance may be used,
#'   which on partially observed data can make scenarios ineligible. Supply one
#'   when the solver can never use some rows (so those rows being unobserved
#'   should not disqualify the scenario), most often when only a subset of
#'   elements can ever enter a feasible decision.
#' @param name Optional character label shown by `show()`. `NULL` (default)
#'   uses `"custom"`.
#'
#' @return A `FunctionProblem`, one of the concrete
#'   [OptimizationProblem-class] classes. Pass it to `dfl_fit()` as the
#'   `problem` argument.
#'
#' @examples
#' pick_cheapest_half <- function(costs, instance) {
#'   as.numeric(costs <= stats::median(costs))
#' }
#' problem <- optimization_problem(solve = pick_cheapest_half, sense = "min")
#' problem
#' solve_decision(problem, c(3, 1, 4, 2), instance = list())
#'
#' @family dflasso problems
#' @seealso [knapsack_problem()], [shortest_path_problem()],
#'   [capital_allocation_problem()], [solve_decision()]
#' @export
#' @include problem-classes.R
optimization_problem <- function(solve,
                                 sense = c("min", "max"),
                                 solve_support = NULL,
                                 name = NULL) {
  sense <- match.arg(sense)
  if (missing(solve) || !is.function(solve)) {
    stop("`solve` must be a function of (costs, instance).", call. = FALSE)
  }
  if (is.null(name)) {
    name <- "custom"
  }
  new(
    "FunctionProblem",
    sense = sense,
    solve_function = solve,
    solve_support_function = solve_support,
    name = name
  )
}

#' Shortest path through a graph
#'
#' A built-in problem for routing decisions: find the least-cost path from an
#' origin node to a destination node over predicted arc costs. The solver is a
#' compiled Dijkstra.
#'
#' @param allow_unreachable Single logical. `TRUE` (default) lets a fit carry
#'   instances where the destination cannot be reached after closures, marking
#'   them infeasible rather than failing the batch. `FALSE` treats an
#'   unreachable destination as a hard error.
#'
#' @return A `ShortestPathProblem`, one of the concrete
#'   [OptimizationProblem-class] classes, with sense fixed at `"min"`. Pass it
#'   to `dfl_fit()` as the `problem` argument.
#'
#' @examples
#' problem <- shortest_path_problem()
#' problem
#' instance <- list(
#'   from = c(1L, 1L, 2L, 3L),
#'   to = c(2L, 3L, 4L, 4L),
#'   n_nodes = 4L,
#'   origin = 1L,
#'   destination = 4L
#' )
#' solve_decision(problem, costs = c(1, 4, 1, 1), instance = instance)
#'
#' @family dflasso problems
#' @seealso [knapsack_problem()], [capital_allocation_problem()],
#'   [optimization_problem()], [solve_decision()]
#' @export
shortest_path_problem <- function(allow_unreachable = TRUE) {
  new(
    "ShortestPathProblem",
    sense = "min",
    solve_function = NULL,
    solve_support_function = NULL,
    name = "shortest path",
    allow_unreachable = allow_unreachable
  )
}

#' Pick a subset under one budget
#'
#' A built-in problem for 0/1 selection under a single capacity: a knapsack.
#' Each instance supplies item weights and a capacity; the solver returns which
#' items to take to maximise total predicted value.
#'
#' @param solver Which engine solves each instance. `"dynamic_program"`
#'   (default) is the exact integer dynamic program and needs integer weights.
#'   `"linear_program"` solves a binary linear program through \pkg{lpSolve},
#'   useful when weights are not integers.
#'
#' @return A `KnapsackProblem`, one of the concrete [OptimizationProblem-class]
#'   classes, with sense fixed at `"max"`. Pass it to `dfl_fit()` as the
#'   `problem` argument.
#'
#' @examples
#' problem <- knapsack_problem()
#' problem
#' solve_decision(
#'   problem,
#'   costs = c(60, 100, 120),
#'   instance = list(weights = c(10L, 20L, 30L), capacity = 50L)
#' )
#'
#' @family dflasso problems
#' @seealso [shortest_path_problem()], [capital_allocation_problem()],
#'   [optimization_problem()], [solve_decision()]
#' @export
knapsack_problem <- function(solver = c("dynamic_program", "linear_program")) {
  solver <- match.arg(solver)
  new(
    "KnapsackProblem",
    sense = "max",
    solve_function = NULL,
    solve_support_function = NULL,
    name = "knapsack",
    solver = solver
  )
}

#' Split capital across choices
#'
#' A built-in problem for continuous allocation: spread a budget across choices
#' so the weights sum to one and no single choice exceeds a maximum share,
#' maximising total predicted return. The solver is a linear program through
#' \pkg{lpSolve}.
#'
#' @param max_weight Single number in `(0, 1]`. The largest share any one
#'   choice may take. Default `0.2`. An instance may override it per call.
#'
#' @return A `CapitalAllocationProblem`, one of the concrete
#'   [OptimizationProblem-class] classes, with sense fixed at `"max"`. Pass it
#'   to `dfl_fit()` as the `problem` argument.
#'
#' @examples
#' problem <- capital_allocation_problem(max_weight = 0.5)
#' problem
#' solve_decision(
#'   problem,
#'   costs = c(0.08, 0.03, 0.05),
#'   instance = list(n_assets = 3)
#' )
#'
#' @family dflasso problems
#' @seealso [knapsack_problem()], [shortest_path_problem()],
#'   [optimization_problem()], [solve_decision()]
#' @export
capital_allocation_problem <- function(max_weight = 0.2) {
  new(
    "CapitalAllocationProblem",
    sense = "max",
    solve_function = NULL,
    solve_support_function = NULL,
    name = "capital allocation",
    max_weight = max_weight
  )
}
