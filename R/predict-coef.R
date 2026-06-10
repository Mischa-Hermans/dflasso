#' Predicted costs and coefficients from a fitted model
#'
#' `predict()` turns new feature rows into the predicted cost vector the
#' decision is made from; `coef()` returns the sparse coefficient vector.
#' Neither needs realised costs.
#'
#' @param object A [DecisionFocusedLasso-class] object.
#' @param x_new Numeric feature matrix of new rows, columns in the same order
#'   (or with the same names) as the matrix the fit was trained on.
#' @param s Penalty strength: `"lambda.min"` (default), `"lambda.1se"`, or a
#'   numeric lambda.
#' @param penalty Which stage to read, `NULL` (default) for the fit's primary
#'   stage, or one of `"decision"`, `"adaptive"`, `"plain"` to inspect a
#'   specific stage.
#' @param type What to return. `"response"` (default) gives the predicted cost
#'   vector, one value per row of `x_new`. `"coefficients"` gives the sparse
#'   coefficient vector. `"nonzero"` gives the names of the kept features.
#' @param ... Unused, present for S4/S3 compatibility.
#'
#' @return `predict()` with `type = "response"` returns a numeric vector of
#'   length `nrow(x_new)`. With `type = "coefficients"` it returns a sparse
#'   coefficient vector including the intercept. With `type = "nonzero"` it
#'   returns a character vector of kept feature names. `coef()` returns the
#'   sparse coefficient vector including the intercept.
#'
#' @examples
#' sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' head(predict(fit, sim$x))
#' coef(fit)
#' predict(fit, sim$x, type = "nonzero")
#'
#' @seealso [decide()] to act on a fit.
#' @family dflasso workflow
#' @name predict-coef
#' @aliases predict.DecisionFocusedLasso coef.DecisionFocusedLasso
#' @importFrom stats predict coef
#' @importFrom methods setMethod
#' @include fitted-class.R
NULL

#' @rdname predict-coef
#' @export
setMethod(
  "predict",
  "DecisionFocusedLasso",
  function(object, x_new, s = "lambda.min", penalty = NULL,
           type = c("response", "coefficients", "nonzero"), ...) {
    type <- match.arg(type)
    if (type == "coefficients") {
      return(stage_coef(object, s, penalty))
    }
    if (type == "nonzero") {
      return(nonzero_features(object, s, penalty))
    }
    matrix_x <- match_new_features(object, x_new, "x_new")
    coefficients <- stage_coef(object, s, penalty)
    as.numeric(cbind(1, matrix_x) %*% as.numeric(coefficients))
  }
)

#' @rdname predict-coef
#' @export
setMethod(
  "coef",
  "DecisionFocusedLasso",
  function(object, s = "lambda.min", penalty = NULL, ...) {
    stage_coef(object, s, penalty)
  }
)

stage_fit <- function(object, penalty) {
  stage <- if (is.null(penalty)) object@penalty_primary else penalty
  if (length(stage) != 1L || !stage %in% c("decision", "adaptive", "plain")) {
    decide_error(
      "penalty must be NULL or one of \"decision\", \"adaptive\", \"plain\".",
      "dflasso_error_usage"
    )
  }
  switch(
    stage,
    decision = object@decision_fit,
    adaptive = object@adaptive_fit,
    plain = object@plain_fit
  )
}

stage_coef <- function(object, s, penalty) {
  fit <- stage_fit(object, penalty)
  lambda <- resolve_lambda(s)
  coefficients <- glmnet::coef.glmnet(fit, s = lambda)
  rownames(coefficients) <- c("(Intercept)", object@feature_names)
  coefficients
}

nonzero_features <- function(object, s, penalty) {
  estimates <- stage_estimates(object, s, penalty)
  object@feature_names[estimates != 0]
}

stage_estimates <- function(object, s, penalty) {
  coefficients <- stage_coef(object, s, penalty)
  as.numeric(coefficients)[-1L]
}

resolve_lambda <- function(s) {
  if (is.numeric(s)) {
    return(s)
  }
  if (length(s) == 1L && s %in% c("lambda.min", "lambda.1se")) {
    return(s)
  }
  decide_error(
    paste0(
      "s must be \"lambda.min\", \"lambda.1se\", or a numeric lambda; got ",
      format_value(s), "."
    ),
    "dflasso_error_usage"
  )
}

match_new_features <- function(object, x_new, argument_name) {
  matrix_x <- as_new_matrix(x_new, argument_name)
  n_features <- length(object@feature_names)
  if (object@features_named && !is.null(colnames(matrix_x))) {
    missing_columns <- setdiff(object@feature_names, colnames(matrix_x))
    if (length(missing_columns) > 0L) {
      decide_error(sprintf(
        paste0(
          "%s is missing feature column(s) the model was fit on: %s."
        ),
        argument_name, truncate_ids(missing_columns)
      ), "dflasso_error_dimension")
    }
    return(matrix_x[, object@feature_names, drop = FALSE])
  }
  if (ncol(matrix_x) != n_features) {
    decide_error(sprintf(
      paste0(
        "%s has %d column(s) but the model was fit on %d feature(s). Pass the ",
        "features in the same order, or with the same names."
      ),
      argument_name, ncol(matrix_x), n_features
    ), "dflasso_error_dimension")
  }
  matrix_x
}

as_new_matrix <- function(x_new, argument_name) {
  if (is.matrix(x_new) && is.numeric(x_new)) {
    storage.mode(x_new) <- "double"
    return(x_new)
  }
  if (is.data.frame(x_new)) {
    return(features_to_matrix(x_new))
  }
  if (is.numeric(x_new)) {
    return(matrix(as.numeric(x_new), ncol = 1L))
  }
  decide_error(sprintf(
    "%s must be a numeric matrix, one row per element.", argument_name
  ), "dflasso_error_dimension")
}

format_value <- function(value) {
  if (is.character(value)) {
    return(sprintf("\"%s\"", paste(value, collapse = "\", \"")))
  }
  paste(format(value), collapse = ", ")
}

decide_error <- function(message, class = "dflasso_error_value") {
  stop(structure(
    class = c(class, "dflasso_error", "error", "condition"),
    list(message = message, call = NULL)
  ))
}
