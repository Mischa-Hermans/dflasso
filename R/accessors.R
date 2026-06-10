#' Objective sense of a problem
#'
#' Reports whether an optimisation problem minimises or maximises. `sense()`
#' returns the direction as a string; `is_minimization()` returns a logical,
#' `TRUE` for `"min"`.
#'
#' @param object An [OptimizationProblem-class] object, such as one returned by
#'   [knapsack_problem()] or [optimization_problem()].
#'
#' @return `sense()` returns a character scalar, `"min"` or `"max"`.
#'   `is_minimization()` returns a single logical, `TRUE` when the sense is
#'   `"min"`.
#'
#' @examples
#' problem <- knapsack_problem()
#' sense(problem)
#' is_minimization(problem)
#'
#' @family dflasso problems
#' @seealso [optimization_problem()]
#' @export
#' @include problem-classes.R
setGeneric("sense", function(object) standardGeneric("sense"))

#' @rdname sense
#' @export
setGeneric("is_minimization", function(object) {
  standardGeneric("is_minimization")
})

#' @rdname sense
setMethod("sense", "OptimizationProblem", function(object) {
  object@sense
})

#' @rdname sense
setMethod("is_minimization", "OptimizationProblem", function(object) {
  object@sense == "min"
})
