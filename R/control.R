#' Options for a dflasso fit
#'
#' Collects every setting a [dfl_fit()] run uses into one validated object.
#' The arguments fall into two groups. The main settings are a seed, whether to
#' run in parallel, whether to print progress, and the cross-validation and
#' coverage controls. The method settings control how the decision-relevance
#' score rescales each feature's penalty; their defaults are tuned.
#'
#' `dfl_control()` validates everything up front, so a bad value or a mistyped
#' name fails at the call rather than inside a fit.
#' An unknown argument is rejected with a did-you-mean suggestion.
#'
#' @param seed Single integer, or `NULL` (default) to draw one at random. The
#'   resolved seed is stored on the fit.
#' @param parallel Single logical, default `FALSE`. Run the proxy loop in
#'   parallel.
#' @param workers Single positive integer, or `NULL` (default). The number of
#'   parallel workers: set it to start a cluster of that size and run in
#'   parallel; `NULL` leaves parallelism to `parallel`.
#' @param progress Single logical, default [interactive()]. When `TRUE`, the
#'   decision-quality step prints a one-line start and a `Done.` when it
#'   finishes; when `FALSE`, that step is silent.
#' @param standardize Single logical, default `TRUE`, passed to glmnet's
#'   `standardize`, which scales features for the fit and returns coefficients
#'   on the original scale.
#' @param min_elements_per_scenario Single positive integer, default `2`. Drop
#'   scenarios smaller than this after missing costs are removed.
#' @param nfolds Single integer of at least 3 (glmnet's minimum), default `10`.
#'   Cross-validation folds for the final weighted lasso.
#' @param gamma Single positive number, default `2`. The adaptive-weight
#'   exponent in `1 / abs(beta_ridge)^gamma`.
#' @param kappa Single positive number, default `6`, the decision-relevance
#'   strength. A rescued feature's penalty is
#'   `w_max * exp(-kappa * rescaled_score)`, so a higher `kappa` discounts a
#'   high-scoring feature harder.
#' @param proxy_score_reference Single positive number, default `0.2`, typically
#'   `(0, 1]`. The reference the proxy score is rescaled against; must be
#'   positive because it divides the score.
#' @param w_min Single positive number below `w_max`, default `0.1`. The lower
#'   bound on the final weights.
#' @param w_max Single positive number above `w_min`, default `500`. The upper
#'   bound on the final weights, and where the rescue starts: a decision-relevant
#'   feature is pulled down from `w_max` by its score, so it reaches a selectable
#'   penalty whatever its raw adaptive weight.
#' @param n_splits Single integer of at least 2, default `15`. The
#'   train/validation resamples the proxy averages over.
#' @param split_fraction Single number in `(0, 1)`, default `0.7`. The training
#'   share within each proxy split.
#' @param eligibility_threshold `NULL` (default) or a single positive number, a
#'   minimum adaptive weight for rescue. `NULL` applies no such gate: a feature
#'   is rescued on its decision-relevance score alone, whatever its adaptive
#'   weight. A positive number (such as one from [dflasso_tuned_thresholds])
#'   restricts the rescue to features whose adaptive weight is at least that.
#' @param score_floor Single positive number, default `1e-3`. Raw proxy scores
#'   below this trigger no discount.
#' @param ... Caught only to reject unknown arguments with a did-you-mean
#'   suggestion.
#'
#' @return A validated list of class `dfl_control`, ready to pass to the
#'   `control` argument of [dfl_fit()].
#'
#' @examples
#' dfl_control()
#' dfl_control(seed = 2024, workers = 8)
#' dfl_control(eligibility_threshold = dflasso_tuned_thresholds[["knapsack"]])
#'
#' @seealso [dfl_fit()], [dflasso_tuned_thresholds]
#' @export
dfl_control <- function(seed = NULL,
                        parallel = FALSE,
                        workers = NULL,
                        progress = interactive(),
                        standardize = TRUE,
                        min_elements_per_scenario = 2L,
                        nfolds = 10L,
                        gamma = 2,
                        kappa = 6,
                        proxy_score_reference = 0.20,
                        w_min = 0.10,
                        w_max = 500,
                        n_splits = 15L,
                        split_fraction = 0.70,
                        eligibility_threshold = NULL,
                        score_floor = 1e-3,
                        ...) {
  known <- setdiff(names(formals()), "...")
  reject_unknown_arguments(names(list(...)), known)

  seed <- check_optional_count(seed, "seed")
  workers <- check_optional_count(workers, "workers")
  parallel <- check_flag(parallel, "parallel")
  progress <- check_flag(progress, "progress")
  standardize <- check_flag(standardize, "standardize")

  min_elements_per_scenario <- check_count(
    min_elements_per_scenario, "min_elements_per_scenario"
  )
  nfolds <- check_count(nfolds, "nfolds")
  n_splits <- check_count(n_splits, "n_splits")

  gamma <- check_positive(gamma, "gamma")
  kappa <- check_positive(kappa, "kappa")
  proxy_score_reference <- check_positive(
    proxy_score_reference, "proxy_score_reference"
  )
  w_min <- check_positive(w_min, "w_min")
  w_max <- check_positive(w_max, "w_max")
  score_floor <- check_positive(score_floor, "score_floor")
  split_fraction <- check_unit_interval(split_fraction, "split_fraction")
  eligibility_threshold <- check_optional_positive(
    eligibility_threshold, "eligibility_threshold"
  )

  if (w_min >= w_max) {
    control_error(sprintf(
      "w_min (%g) must be below w_max (%g)", w_min, w_max
    ))
  }

  if (n_splits < 2L) {
    control_error(sprintf(
      paste0(
        "n_splits (%d) must be at least 2; a single resample cannot estimate ",
        "decision relevance"
      ),
      n_splits
    ))
  }

  if (nfolds < 3L) {
    control_error(sprintf(
      paste0(
        "nfolds (%d) must be at least 3; cross-validation needs at least ",
        "three folds"
      ),
      nfolds
    ))
  }

  structure(
    list(
      seed = seed,
      parallel = parallel,
      workers = workers,
      progress = progress,
      standardize = standardize,
      min_elements_per_scenario = min_elements_per_scenario,
      nfolds = nfolds,
      gamma = gamma,
      kappa = kappa,
      proxy_score_reference = proxy_score_reference,
      w_min = w_min,
      w_max = w_max,
      n_splits = n_splits,
      split_fraction = split_fraction,
      eligibility_threshold = eligibility_threshold,
      score_floor = score_floor
    ),
    class = "dfl_control"
  )
}

#' Tuned eligibility thresholds
#'
#' Tuned eligibility-threshold values, one for each built-in problem. Pass one
#' to the `eligibility_threshold` argument of `dfl_control()`, for example
#' `dfl_control(eligibility_threshold = dflasso_tuned_thresholds[["knapsack"]])`.
#'
#' @format A named numeric vector with three entries: `shortest_path` (150),
#'   `knapsack` (20), and `capital_allocation` (20).
#' @seealso [dfl_control()]
#' @export
dflasso_tuned_thresholds <- c(
  shortest_path = 150,
  knapsack = 20,
  capital_allocation = 20
)

#' @export
print.dfl_control <- function(x, ...) {
  cat("<dfl_control>\n")
  main_settings <- c(
    "seed", "parallel", "workers", "progress", "standardize",
    "min_elements_per_scenario", "nfolds"
  )
  method_settings <- c(
    "gamma", "kappa", "proxy_score_reference", "w_min", "w_max",
    "n_splits", "split_fraction", "eligibility_threshold", "score_floor"
  )
  cat("main:\n")
  print_control_group(x, main_settings)
  cat("method settings:\n")
  print_control_group(x, method_settings)
  invisible(x)
}

print_control_group <- function(control, fields) {
  for (field in fields) {
    value <- control[[field]]
    rendered <- if (is.null(value)) "NULL" else format(value)
    cat(sprintf("  %-26s %s\n", field, rendered))
  }
}

reject_unknown_arguments <- function(supplied, known) {
  unknown <- setdiff(supplied, known)
  if (length(unknown) == 0L) {
    return(invisible(NULL))
  }
  first <- unknown[[1L]]
  suggestion <- nearest_argument(first, known)
  hint <- if (is.null(suggestion)) {
    ""
  } else {
    sprintf("; did you mean '%s'?", suggestion)
  }
  control_error(
    sprintf("unknown control argument '%s'%s", first, hint),
    class = "dflasso_error_usage"
  )
}

nearest_argument <- function(name, known) {
  distances <- utils::adist(name, known, ignore.case = TRUE)[1L, ]
  best <- which.min(distances)
  threshold <- max(2L, ceiling(nchar(name) / 2))
  if (length(best) == 0L || distances[[best]] > threshold) {
    return(NULL)
  }
  known[[best]]
}

check_flag <- function(value, name) {
  if (length(value) == 1L && is.logical(value) && !is.na(value)) {
    return(value)
  }
  control_error(sprintf(
    "%s must be a single TRUE or FALSE", name
  ))
}

check_count <- function(value, name) {
  if (is_whole_number(value) && value >= 1) {
    return(as.integer(value))
  }
  control_error(sprintf(
    "%s (%s) must be a single positive whole number",
    name, describe_value(value)
  ))
}

check_optional_count <- function(value, name) {
  if (is.null(value)) {
    return(NULL)
  }
  check_count(value, name)
}

check_positive <- function(value, name) {
  if (length(value) == 1L && is.numeric(value) && !is.na(value) && value > 0) {
    return(as.numeric(value))
  }
  control_error(sprintf(
    "%s (%s) must be a single positive number",
    name, describe_value(value)
  ))
}

check_optional_positive <- function(value, name) {
  if (is.null(value)) {
    return(NULL)
  }
  check_positive(value, name)
}

check_unit_interval <- function(value, name) {
  if (length(value) == 1L && is.numeric(value) && !is.na(value) &&
        value > 0 && value < 1) {
    return(as.numeric(value))
  }
  control_error(sprintf(
    "%s (%s) must be a single number strictly between 0 and 1",
    name, describe_value(value)
  ))
}

is_whole_number <- function(value) {
  length(value) == 1L && is.numeric(value) && !is.na(value) &&
    is.finite(value) && abs(value - round(value)) < .Machine$double.eps^0.5
}

describe_value <- function(value) {
  if (length(value) != 1L) {
    return(sprintf("length %d", length(value)))
  }
  if (is.na(value)) {
    return("NA")
  }
  format(value)
}

control_error <- function(message, class = "dflasso_error_value") {
  stop(structure(
    class = c(class, "dflasso_error", "error", "condition"),
    list(message = message, call = NULL)
  ))
}
