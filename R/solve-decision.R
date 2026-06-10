#' Solve a decision from predicted costs
#'
#' The step that turns a vector of predicted costs into a decision for
#' one instance. `solve_decision()` solves each problem its own way: the
#' built-in problems call their own solvers, and a custom problem calls the
#' solver supplied to it. `solve_support()` reports which element rows a
#' feasible decision could use for the instance. Those rows set the coverage
#' rule: a scenario is eligible for the decision-quality step only when every
#' row in its support has an observed realised cost. The default is all rows,
#' which can drop scenarios on partially observed data; a custom problem
#' supplies a narrower set through the `solve_support` argument of
#' [optimization_problem()] when its solver can never use some rows.
#'
#' @param problem An [OptimizationProblem-class] object.
#' @param costs Numeric vector of predicted costs, one per element row of the
#'   instance.
#' @param instance A list of the per-instance data the solver needs. The
#'   built-in problems expect named fields documented on their constructors.
#' @param ... Reserved for future use.
#'
#' @return `solve_decision()` returns the decision vector, the same length and
#'   row order as `costs`. `solve_support()` returns an integer vector of row
#'   indices into the instance.
#'
#' @details
#' For [shortest_path_problem()] an unreachable destination raises a classed
#' condition with class `dflasso_infeasible`, so a caller can catch it and mark
#' the instance infeasible rather than fail the batch.
#'
#' @examples
#' problem <- knapsack_problem()
#' solve_decision(
#'   problem,
#'   costs = c(60, 100, 120),
#'   instance = list(weights = c(10L, 20L, 30L), capacity = 50L)
#' )
#' solve_support(problem, instance = list(weights = c(10L, 20L, 30L)))
#'
#' @family dflasso problems
#' @seealso [knapsack_problem()], [shortest_path_problem()],
#'   [capital_allocation_problem()], [optimization_problem()]
#' @export
#' @include problem-classes.R
setGeneric("solve_decision", function(problem, costs, instance, ...) {
  standardGeneric("solve_decision")
})

#' @rdname solve_decision
#' @export
setGeneric("solve_support", function(problem, instance, ...) {
  standardGeneric("solve_support")
})

#' @rdname solve_decision
setMethod(
  "solve_decision",
  "ShortestPathProblem",
  function(problem, costs, instance, ...) {
    incidence <- shortest_path_dijkstra(
      instance$from,
      instance$to,
      costs,
      instance$n_nodes,
      instance$origin,
      instance$destination
    )
    if (isTRUE(attr(incidence, "unreachable"))) {
      raise_infeasible(sprintf(
        "destination '%s' unreachable from origin '%s' after closures",
        instance$destination, instance$origin
      ))
    }
    as.integer(incidence)
  }
)

#' @rdname solve_decision
setMethod(
  "solve_support",
  "ShortestPathProblem",
  function(problem, instance, ...) {
    reachable_arcs(
      instance$from,
      instance$to,
      instance$n_nodes,
      instance$origin
    )
  }
)

#' @rdname solve_decision
setMethod(
  "solve_decision",
  "KnapsackProblem",
  function(problem, costs, instance, ...) {
    if (problem@solver == "dynamic_program") {
      selected <- knapsack_dynamic_program(
        costs,
        instance$weights,
        instance$capacity
      )
      return(as.integer(selected))
    }
    solution <- lpSolve::lp(
      direction = "max",
      objective.in = costs,
      const.mat = matrix(instance$weights, nrow = 1L),
      const.dir = "<=",
      const.rhs = instance$capacity,
      all.bin = TRUE
    )
    as.integer(round(solution$solution))
  }
)

#' @rdname solve_decision
setMethod(
  "solve_support",
  "KnapsackProblem",
  function(problem, instance, ...) {
    seq_along(instance$weights)
  }
)

#' @rdname solve_decision
setMethod(
  "solve_decision",
  "CapitalAllocationProblem",
  function(problem, costs, instance, ...) {
    n_assets <- instance$n_assets
    max_weight <- if (is.null(instance$max_weight)) {
      problem@max_weight
    } else {
      instance$max_weight
    }
    if (max_weight * n_assets < 1) {
      raise_capital_infeasible(max_weight, n_assets)
    }
    constraint_matrix <- rbind(rep(1, n_assets), diag(n_assets))
    constraint_directions <- c("=", rep("<=", n_assets))
    constraint_rhs <- c(1, rep(max_weight, n_assets))
    solution <- lpSolve::lp(
      direction = "max",
      objective.in = costs,
      const.mat = constraint_matrix,
      const.dir = constraint_directions,
      const.rhs = constraint_rhs
    )
    weights <- as.numeric(solution$solution)
    if (solution$status != 0 || abs(sum(weights) - 1) > 1e-6) {
      raise_capital_infeasible(max_weight, n_assets)
    }
    weights
  }
)

#' @rdname solve_decision
setMethod(
  "solve_support",
  "CapitalAllocationProblem",
  function(problem, instance, ...) {
    seq_len(instance$n_assets)
  }
)

#' @rdname solve_decision
setMethod(
  "solve_decision",
  "FunctionProblem",
  function(problem, costs, instance, ...) {
    problem@solve_function(costs, instance)
  }
)

#' @rdname solve_decision
setMethod(
  "solve_support",
  "FunctionProblem",
  function(problem, instance, costs = NULL, ...) {
    if (!is.null(problem@solve_support_function)) {
      return(problem@solve_support_function(instance))
    }
    if (!is.null(costs)) {
      return(seq_along(costs))
    }
    NULL
  }
)

raise_infeasible <- function(message) {
  stop(structure(
    class = c("dflasso_infeasible", "error", "condition"),
    list(message = message, call = NULL)
  ))
}

raise_capital_infeasible <- function(max_weight, n_assets) {
  raise_infeasible(sprintf(
    paste0(
      "capital allocation is infeasible: max_weight (%g) times n_assets ",
      "(%d) is below 1, so the weights cannot sum to one; raise max_weight ",
      "or add assets"
    ),
    max_weight, n_assets
  ))
}

reachable_arcs <- function(from, to, n_nodes, origin) {
  tail_node <- factor(from, levels = seq_len(n_nodes))
  outgoing_arcs <- split(seq_along(from), tail_node)
  visited <- logical(n_nodes)
  visited[origin] <- TRUE
  frontier <- origin
  reached_arcs <- integer(0)
  while (length(frontier) > 0L) {
    node <- frontier[[1L]]
    frontier <- frontier[-1L]
    node_arcs <- outgoing_arcs[[node]]
    if (length(node_arcs) == 0L) {
      next
    }
    reached_arcs <- c(reached_arcs, node_arcs)
    for (arc in node_arcs) {
      head_node <- to[[arc]]
      if (!visited[head_node]) {
        visited[head_node] <- TRUE
        frontier <- c(frontier, head_node)
      }
    }
  }
  sort(unique(reached_arcs))
}
