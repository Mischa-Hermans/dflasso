#' Optimisation problem classes
#'
#' The S4 classes that represent a dflasso problem. `OptimizationProblem` is the
#' base class, never built directly; each of the four classes that extend it
#' carries a sense (minimise or maximise) and a solver that turns predicted
#' costs into a decision. Build them with the lowercase constructors, not
#' [methods::new()].
#'
#' @slot sense Character scalar, either `"min"` or `"max"`. The direction of
#'   the objective `cost' decision`.
#' @slot solve_function Function of `(costs, instance)` returning a decision
#'   vector, or `NULL` for the built-in problems, where the class determines
#'   the solver.
#' @slot solve_support_function Function of one argument returning the integer
#'   row indices the solver inspects, or `NULL` for the all-rows default.
#' @slot name Character scalar label shown by `show()`.
#'
#' @family dflasso problems
#' @seealso [optimization_problem()], [shortest_path_problem()],
#'   [knapsack_problem()], [capital_allocation_problem()]
#' @keywords internal
#' @importFrom methods setClass setValidity setGeneric setMethod new
#'   validObject is
#' @name OptimizationProblem-class
#' @rdname OptimizationProblem-class
NULL

#' @rdname OptimizationProblem-class
setClass(
  "OptimizationProblem",
  representation(
    "VIRTUAL",
    sense = "character",
    solve_function = "ANY",
    solve_support_function = "ANY",
    name = "character"
  )
)

is_valid_solve_support <- function(candidate) {
  if (is.null(candidate)) {
    return(TRUE)
  }
  is.function(candidate) && length(formals(candidate)) >= 1L
}

setValidity("OptimizationProblem", function(object) {
  problems <- character(0)
  if (length(object@sense) != 1L || !object@sense %in% c("min", "max")) {
    problems <- c(problems, "sense must be one of \"min\" or \"max\"")
  }
  solve_function <- object@solve_function
  if (!is.null(solve_function)) {
    if (!is.function(solve_function) || length(formals(solve_function)) < 2L) {
      problems <- c(
        problems,
        "solve_function must be NULL or a function of (costs, instance)"
      )
    }
  }
  if (!is_valid_solve_support(object@solve_support_function)) {
    problems <- c(
      problems,
      "solve_support_function must be NULL or a function of one argument"
    )
  }
  if (length(object@name) != 1L) {
    problems <- c(problems, "name must be a length-one character vector")
  }
  if (length(problems) == 0L) TRUE else problems
})

#' @rdname OptimizationProblem-class
setClass("FunctionProblem", contains = "OptimizationProblem")

#' @rdname OptimizationProblem-class
setClass(
  "ShortestPathProblem",
  contains = "OptimizationProblem",
  representation(allow_unreachable = "logical")
)

setValidity("ShortestPathProblem", function(object) {
  problems <- character(0)
  if (object@sense != "min") {
    problems <- c(problems, "shortest path sense is fixed at \"min\"")
  }
  if (length(object@allow_unreachable) != 1L ||
      is.na(object@allow_unreachable)) {
    problems <- c(problems, "allow_unreachable must be a single TRUE or FALSE")
  }
  if (length(problems) == 0L) TRUE else problems
})

#' @rdname OptimizationProblem-class
setClass(
  "KnapsackProblem",
  contains = "OptimizationProblem",
  representation(solver = "character")
)

setValidity("KnapsackProblem", function(object) {
  problems <- character(0)
  if (object@sense != "max") {
    problems <- c(problems, "knapsack sense is fixed at \"max\"")
  }
  if (length(object@solver) != 1L ||
      !object@solver %in% c("dynamic_program", "linear_program")) {
    problems <- c(
      problems,
      "solver must be one of \"dynamic_program\" or \"linear_program\""
    )
  }
  if (length(problems) == 0L) TRUE else problems
})

#' @rdname OptimizationProblem-class
setClass(
  "CapitalAllocationProblem",
  contains = "OptimizationProblem",
  representation(max_weight = "numeric")
)

setValidity("CapitalAllocationProblem", function(object) {
  problems <- character(0)
  if (object@sense != "max") {
    problems <- c(problems, "capital allocation sense is fixed at \"max\"")
  }
  max_weight <- object@max_weight
  if (length(max_weight) != 1L || is.na(max_weight) ||
      max_weight <= 0 || max_weight > 1) {
    problems <- c(problems, "max_weight must be a single number in (0, 1]")
  }
  if (length(problems) == 0L) TRUE else problems
})

#' @rdname OptimizationProblem-class
setMethod("show", "FunctionProblem", function(object) {
  cat(sprintf(
    "<FunctionProblem: sense=%s, name=%s>\n",
    object@sense, object@name
  ))
  invisible(object)
})

#' @rdname OptimizationProblem-class
setMethod("show", "ShortestPathProblem", function(object) {
  cat(sprintf(
    "<ShortestPathProblem: sense=%s, allow_unreachable=%s>\n",
    object@sense, object@allow_unreachable
  ))
  invisible(object)
})

#' @rdname OptimizationProblem-class
setMethod("show", "KnapsackProblem", function(object) {
  cat(sprintf(
    "<KnapsackProblem: sense=%s, solver=%s>\n",
    object@sense, object@solver
  ))
  invisible(object)
})

#' @rdname OptimizationProblem-class
setMethod("show", "CapitalAllocationProblem", function(object) {
  cat(sprintf(
    "<CapitalAllocationProblem: sense=%s, max_weight=%s>\n",
    object@sense, format(object@max_weight)
  ))
  invisible(object)
})
