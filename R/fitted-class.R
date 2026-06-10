#' A fitted decision-focused lasso
#'
#' The object [dfl_fit()] returns. It holds the three lasso fits (plain,
#' adaptive, and decision-focused) on one shared set of folds so they compare
#' directly. It also keeps the per-feature adaptive weights and
#' decision-relevance scores that shaped the decision-focused fit. The
#' coverage report and the resolved seed are stored too.
#'
#' @slot decision_fit,adaptive_fit,plain_fit The three `cv.glmnet` fits. All
#'   three are computed on one shared `foldid` so they are comparable; `penalty`
#'   chooses which is primary.
#' @slot adaptive_weight Numeric vector, one baseline ridge-adaptive weight per
#'   feature.
#' @slot proxy_score Numeric vector, the regret-proxy score per feature.
#' @slot penalty_factor Numeric vector, the final weights fed to the
#'   decision-focused lasso.
#' @slot feature_names Character vector of feature names.
#' @slot features_named Single logical, `TRUE` when `x` carried column names at
#'   fit, which drives new-data matching by name rather than position.
#' @slot element_ids List of per-scenario element id vectors.
#' @slot coverage Data frame of the per-scenario coverage report, or `NULL` for
#'   a supplied-regret fit.
#' @slot problem The [OptimizationProblem-class] object, or `NULL` for a
#'   supplied-regret fit.
#' @slot sense Character scalar, `"min"` or `"max"`.
#' @slot source Character scalar, `"solver"` or `"supplied regret"`.
#' @slot penalty_primary Character scalar, one of `"decision"`, `"adaptive"`,
#'   `"plain"`.
#' @slot lambda_min,lambda_1se Numeric scalars, the two standard `cv.glmnet`
#'   lambda choices for the primary fit.
#' @slot eligibility_threshold Single number, the resolved ridge-weight gate;
#'   `0` when no weight gate applies (the default).
#' @slot n_proxy_eligible,n_partial_coverage Integer counts of scenarios that
#'   could and could not be scored.
#' @slot splits List of the proxy train/validation splits, or `NULL` for a
#'   supplied-regret fit.
#' @slot seed Single integer, the resolved seed.
#' @slot standardize Single logical.
#' @slot control The `dfl_control` list the fit obeyed.
#' @slot call The matched call.
#'
#' @seealso [dfl_fit()], [proxy_score()], [penalty_factor()],
#'   [adaptive_weight()], [selected_features()], [coverage()], [splits()]
#' @keywords internal
#' @importFrom methods setClass setValidity setGeneric setMethod new is
#' @name DecisionFocusedLasso-class
#' @rdname DecisionFocusedLasso-class
NULL

methods::setOldClass("cv.glmnet")

#' @rdname DecisionFocusedLasso-class
setClass(
  "DecisionFocusedLasso",
  representation(
    decision_fit = "ANY",
    adaptive_fit = "ANY",
    plain_fit = "ANY",
    adaptive_weight = "numeric",
    proxy_score = "numeric",
    penalty_factor = "numeric",
    feature_names = "character",
    features_named = "logical",
    element_ids = "list",
    coverage = "ANY",
    problem = "ANY",
    sense = "character",
    source = "character",
    penalty_primary = "character",
    lambda_min = "numeric",
    lambda_1se = "numeric",
    eligibility_threshold = "numeric",
    n_proxy_eligible = "integer",
    n_partial_coverage = "integer",
    splits = "ANY",
    seed = "integer",
    standardize = "logical",
    control = "ANY",
    call = "ANY"
  )
)

setValidity("DecisionFocusedLasso", function(object) {
  problems <- character(0)
  n_features <- length(object@feature_names)

  for (slot_name in c("adaptive_weight", "proxy_score", "penalty_factor")) {
    if (length(methods::slot(object, slot_name)) != n_features) {
      problems <- c(problems, sprintf(
        "%s must have one value per feature (length %d)",
        slot_name, n_features
      ))
    }
  }

  control <- object@control
  if (!is.null(control)) {
    within_bounds <- object@penalty_factor >= control$w_min &
      object@penalty_factor <= control$w_max
    if (length(object@penalty_factor) > 0L && !all(within_bounds)) {
      problems <- c(
        problems,
        "penalty_factor must lie within the w_min and w_max clamps"
      )
    }
  }

  if (length(object@penalty_primary) != 1L ||
        !object@penalty_primary %in% c("decision", "adaptive", "plain")) {
    problems <- c(
      problems,
      "penalty_primary must be one of \"decision\", \"adaptive\", \"plain\""
    )
  }

  if (length(object@source) != 1L ||
        !object@source %in% c("solver", "supplied regret")) {
    problems <- c(
      problems,
      "source must be one of \"solver\", \"supplied regret\""
    )
  }

  problem_is_null <- is.null(object@problem)
  source_is_regret <- length(object@source) == 1L &&
    object@source == "supplied regret"
  if (problem_is_null != source_is_regret) {
    problems <- c(
      problems,
      "problem must be NULL exactly when source is \"supplied regret\""
    )
  }

  if (object@source == "solver" && object@n_proxy_eligible < 1L) {
    problems <- c(
      problems,
      "a solver fit needs at least one proxy-eligible scenario"
    )
  }

  if (length(problems) == 0L) TRUE else problems
})

#' @rdname DecisionFocusedLasso-class
setMethod("show", "DecisionFocusedLasso", function(object) {
  n_features <- length(object@feature_names)
  n_decision_kept <- sum(coefficients_of(object@decision_fit) != 0)
  cat(sprintf(
    paste0(
      "<DecisionFocusedLasso: %s, sense=%s, %d features, ",
      "%d kept, %d instances scored>\n"
    ),
    object@source, object@sense, n_features,
    n_decision_kept, object@n_proxy_eligible
  ))
  invisible(object)
})

#' Accessors for a fitted decision-focused lasso
#'
#' Read pieces of a [DecisionFocusedLasso-class] object without touching its
#' slots. `proxy_score()`, `adaptive_weight()`, and `penalty_factor()` return
#' the per-feature vectors named by feature; `selected_features()` returns the
#' names the primary fit kept; `coverage()` returns the coverage report (or
#' `NULL` for a supplied-regret fit); `splits()` returns the stored proxy
#' splits; `seed()` returns the resolved seed; `lambda_min()`/`lambda_1se()`
#' return the two standard lambda choices; `problem()` returns the attached
#' optimisation problem (or `NULL`).
#'
#' @param object A [DecisionFocusedLasso-class] object.
#'
#' @return `proxy_score()`, `adaptive_weight()`, and `penalty_factor()` return
#'   named numeric vectors. `selected_features()` returns a character vector.
#'   `coverage()` returns a data frame or `NULL`. `splits()` returns a list or
#'   `NULL`. `seed()` returns a single integer. `lambda_min()`/`lambda_1se()`
#'   return single numbers. `problem()` returns an [OptimizationProblem-class]
#'   object or `NULL`.
#'
#' @examples
#' sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' proxy_score(fit)
#' selected_features(fit)
#' lambda_min(fit)
#'
#' @seealso [dfl_fit()], [DecisionFocusedLasso-class]
#' @name dfl-accessors
#' @aliases proxy_score adaptive_weight penalty_factor selected_features
#'   coverage splits seed lambda_min lambda_1se problem
NULL

#' @rdname dfl-accessors
#' @export
setGeneric("proxy_score", function(object) standardGeneric("proxy_score"))

#' @rdname dfl-accessors
setMethod("proxy_score", "DecisionFocusedLasso", function(object) {
  stats::setNames(object@proxy_score, object@feature_names)
})

#' @rdname dfl-accessors
#' @export
setGeneric("adaptive_weight", function(object) {
  standardGeneric("adaptive_weight")
})

#' @rdname dfl-accessors
setMethod("adaptive_weight", "DecisionFocusedLasso", function(object) {
  stats::setNames(object@adaptive_weight, object@feature_names)
})

#' @rdname dfl-accessors
#' @export
setGeneric("penalty_factor", function(object) {
  standardGeneric("penalty_factor")
})

#' @rdname dfl-accessors
setMethod("penalty_factor", "DecisionFocusedLasso", function(object) {
  stats::setNames(object@penalty_factor, object@feature_names)
})

#' @rdname dfl-accessors
#' @export
setGeneric("selected_features", function(object) {
  standardGeneric("selected_features")
})

#' @rdname dfl-accessors
setMethod("selected_features", "DecisionFocusedLasso", function(object) {
  primary <- primary_fit(object)
  estimates <- coefficients_of(primary)
  object@feature_names[estimates != 0]
})

#' @rdname dfl-accessors
#' @export
setGeneric("coverage", function(object) standardGeneric("coverage"))

#' @rdname dfl-accessors
setMethod("coverage", "DecisionFocusedLasso", function(object) {
  object@coverage
})

#' @rdname dfl-accessors
#' @export
setGeneric("splits", function(object) standardGeneric("splits"))

#' @rdname dfl-accessors
setMethod("splits", "DecisionFocusedLasso", function(object) {
  object@splits
})

#' @rdname dfl-accessors
#' @export
setGeneric("seed", function(object) standardGeneric("seed"))

#' @rdname dfl-accessors
setMethod("seed", "DecisionFocusedLasso", function(object) {
  object@seed
})

#' @rdname dfl-accessors
#' @export
setGeneric("lambda_min", function(object) standardGeneric("lambda_min"))

#' @rdname dfl-accessors
setMethod("lambda_min", "DecisionFocusedLasso", function(object) {
  object@lambda_min
})

#' @rdname dfl-accessors
#' @export
setGeneric("lambda_1se", function(object) standardGeneric("lambda_1se"))

#' @rdname dfl-accessors
setMethod("lambda_1se", "DecisionFocusedLasso", function(object) {
  object@lambda_1se
})

#' @rdname dfl-accessors
#' @export
setGeneric("problem", function(object) standardGeneric("problem"))

#' @rdname dfl-accessors
setMethod("problem", "DecisionFocusedLasso", function(object) {
  object@problem
})

#' @rdname sense
setMethod("sense", "DecisionFocusedLasso", function(object) {
  object@sense
})

#' @rdname sense
setMethod("is_minimization", "DecisionFocusedLasso", function(object) {
  object@sense == "min"
})

primary_fit <- function(object) {
  switch(
    object@penalty_primary,
    decision = object@decision_fit,
    adaptive = object@adaptive_fit,
    plain = object@plain_fit
  )
}

coefficients_of <- function(fit) {
  raw <- as.numeric(glmnet::coef.glmnet(fit, s = "lambda.min"))
  raw[-1L]
}
