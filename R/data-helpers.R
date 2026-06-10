#' Shape one data frame into the inputs for `dfl_fit()`
#'
#' The recommended way to feed [dfl_fit()]. Pass one data frame, one row
#' per decision element, and name the feature, cost, and scenario columns.
#' `dfl_data()` slices every piece from the same rows, so the features, costs
#' and scenarios stay aligned.
#'
#' Each row is one decision element in one scenario (for example one asset in
#' one period), not one row per scenario with its elements spread across
#' columns. If the table is wide, pivot it long first.
#'
#' Feature columns are pulled in selection order. Factor or character feature
#' columns are dummy-expanded with `model.matrix(~ . - 1)`, so `x` is always
#' numeric. A text feature with many distinct values (more than 50, or more than
#' half the rows) is rejected rather than expanded, since that is almost always
#' an identifier or free-text column selected by mistake; drop or bin it. Costs
#' and regret may be missing (`NA`) but are never imputed.
#'
#' @param data A data frame with one row per decision element.
#' @param features The feature columns, given as a \pkg{tidyselect}
#'   specification: a character vector, a `c(...)` of bare names, or a selector
#'   such as `starts_with("feat_")`.
#' @param cost The realised-cost column, an unquoted name or a string. `NULL`
#'   (default) for the scores-only or supplied-regret path, which needs no
#'   cost.
#' @param scenario The grouping column, an unquoted name or a string, saying
#'   which instance each row belongs to.
#' @param regret Optional realised-regret column, an unquoted name or a string,
#'   for the supplied-regret path. `NULL` on the plain solver path.
#' @param sense Objective sense of the diagnosed model, recorded for the
#'   supplied-regret path. `"min"` (default) or `"max"`.
#' @param element_id Optional id column, an unquoted name or a string. `NULL`
#'   (default) uses per-scenario row positions.
#'
#' @return A list with `x` (a numeric matrix), `cost` (a numeric vector or
#'   `NULL`), `scenario`, `regret` (a numeric vector or `NULL`), `element_id`
#'   (a vector or `NULL`), and `sense`. Every piece is sliced from the same
#'   rows of `data`. Pass it straight to [dfl_fit()].
#'
#' @examples
#' sim <- simulate_capital_allocation(8, 6, 6, seed = 1)
#' prepared <- dfl_data(
#'   sim$data,
#'   features = starts_with("feat_"),
#'   cost = realized_return,
#'   scenario = scenario,
#'   element_id = asset_id
#' )
#' dim(prepared$x)
#'
#' @seealso [make_instances()], [dfl_fit()]
#' @family dflasso data helpers
#' @importFrom rlang enquo quo_is_null
#' @importFrom tidyselect eval_select
#' @importFrom stats model.matrix
#' @export
dfl_data <- function(data,
                     features,
                     cost = NULL,
                     scenario,
                     regret = NULL,
                     sense = c("min", "max"),
                     element_id = NULL) {
  sense <- match.arg(sense)
  if (!is.data.frame(data)) {
    data_error("data must be a data frame with one row per element.")
  }
  if (nrow(data) == 0L) {
    data_error("data has no rows, so there is nothing to fit.")
  }

  feature_columns <- select_columns(rlang::enquo(features), data, "features")
  if (length(feature_columns) == 0L) {
    data_error(paste0(
      "features selected no columns. Name at least one feature ",
      "column."
    ))
  }

  scenario_values <- select_single_column(
    rlang::enquo(scenario), data, "scenario"
  )
  cost_values <- select_optional_column(rlang::enquo(cost), data, "cost")
  regret_values <- select_optional_column(rlang::enquo(regret), data, "regret")
  element_id_values <- select_optional_column(
    rlang::enquo(element_id), data, "element_id"
  )

  feature_frame <- data[, feature_columns, drop = FALSE]
  check_feature_cardinality(feature_frame)

  list(
    x = features_to_matrix(feature_frame),
    cost = as_numeric_cost(cost_values, "cost"),
    scenario = scenario_values,
    regret = as_numeric_cost(regret_values, "regret"),
    element_id = element_id_values,
    sense = sense
  )
}

#' Build the per-scenario instances list
#'
#' Turns per-element vectors into the named list of per-scenario instances that
#' [dfl_fit()] and `decide()` expect, with the entry names aligned to the
#' scenarios.
#'
#' Each named argument in `...` is placed into every scenario entry by length:
#' \itemize{
#'   \item length equal to `length(scenario)`: sliced by scenario, so entry `k`
#'     gets the values for the rows in scenario `k` (per-element data, such as
#'     item weights).
#'   \item length one: recycled, so every entry gets the same scalar (such as a
#'     shared capacity).
#'   \item length equal to the number of scenarios: placed one per instance, so
#'     entry `k` gets the `k`-th value (such as one grid size per scenario).
#' }
#' List-valued arguments follow the same rules. Slicing is tried before
#' placement. When the two lengths are equal (one element row per scenario) the
#' intent is ambiguous, so `make_instances()` errors rather than guess: pass a
#' list for one-per-scenario placement, or wrap a vector in [I()] to force
#' per-element slicing.
#'
#' @param scenario The per-row scenario vector, the same one passed to
#'   [dfl_fit()].
#' @param ... Named arguments placed into each per-scenario entry by their
#'   length.
#'
#' @return A named list with one entry per unique scenario, names aligned to
#'   `as.character(unique(scenario))`, ready to pass as `instances`.
#'
#' @examples
#' scenario <- rep(c("a", "b"), each = 3)
#' make_instances(scenario, weights = c(2, 4, 1, 3, 5, 2), capacity = 50)
#' make_instances(scenario, capacity = 50)
#'
#' @seealso [dfl_data()], [dfl_fit()]
#' @family dflasso data helpers
#' @export
make_instances <- function(scenario, ...) {
  arguments <- list(...)
  if (length(arguments) > 0L && is.null(names(arguments))) {
    data_error("every argument to make_instances must be named.")
  }
  ids <- as.character(unique(scenario))
  n_scenario <- length(ids)
  n_rows <- length(scenario)
  row_group <- factor(as.character(scenario), levels = ids)

  instances <- replicate(n_scenario, list(), simplify = FALSE)
  names(instances) <- ids

  for (argument_name in names(arguments)) {
    placement <- distribute_argument(
      arguments[[argument_name]], argument_name, row_group, n_rows, n_scenario
    )
    for (scenario_index in seq_len(n_scenario)) {
      instances[[scenario_index]][[argument_name]] <-
        placement[[scenario_index]]
    }
  }
  instances
}

distribute_argument <- function(value, name, row_group, n_rows, n_scenario) {
  if (inherits(value, "AsIs")) {
    return(slice_by_group(unclass_asis(value), row_group))
  }
  length_value <- length(value)

  if (length_value == 1L) {
    return(rep(list(unwrap_scalar(value)), n_scenario))
  }
  if (is.list(value) && length_value == n_scenario) {
    return(place_per_scenario(value))
  }
  if (length_value == n_rows && n_rows == n_scenario) {
    data_error(sprintf(
      paste0(
        "Argument '%s' has length %d. That is both the number of rows and ",
        "the number of instances, so make_instances can't tell whether it ",
        "is one value per element or one value per instance. For one value ",
        "per instance, pass a list with one entry per instance; to force ",
        "one-per-element, wrap it in I()."
      ),
      name, length_value
    ), class = "dflasso_error_alignment")
  }
  if (length_value == n_rows) {
    return(slice_by_group(value, row_group))
  }
  if (length_value == n_scenario) {
    return(place_per_scenario(value))
  }
  data_error(sprintf(
    paste0(
      "Argument '%s' has length %d, which matches neither 1, the number of ",
      "rows (%d), nor the number of scenarios (%d). Pass one value per ",
      "element, one scalar, or one value per scenario."
    ),
    name, length_value, n_rows, n_scenario
  ), class = "dflasso_error_alignment")
}

slice_by_group <- function(value, row_group) {
  if (is.list(value)) {
    return(split(value, row_group))
  }
  unname(split(value, row_group))
}

place_per_scenario <- function(value) {
  if (is.list(value)) {
    return(value)
  }
  as.list(value)
}

unwrap_scalar <- function(value) {
  if (is.list(value)) {
    return(value[[1L]])
  }
  value
}

unclass_asis <- function(value) {
  class(value) <- setdiff(class(value), "AsIs")
  value
}

select_columns <- function(quoted, data, label) {
  selection <- tryCatch(
    tidyselect::eval_select(quoted, data),
    error = function(condition) {
      data_error(sprintf(
        "%s could not be selected: %s", label, conditionMessage(condition)
      ))
    }
  )
  names(selection)
}

select_single_column <- function(quoted, data, label) {
  columns <- select_columns(quoted, data, label)
  if (length(columns) != 1L) {
    data_error(sprintf(
      "%s must name exactly one column (it named %d).", label, length(columns)
    ))
  }
  data[[columns]]
}

select_optional_column <- function(quoted, data, label) {
  if (rlang::quo_is_null(quoted)) {
    return(NULL)
  }
  select_single_column(quoted, data, label)
}

check_feature_cardinality <- function(feature_frame) {
  n_rows <- nrow(feature_frame)
  level_cap <- max(50L, n_rows %/% 2L)
  for (column_name in names(feature_frame)) {
    column <- feature_frame[[column_name]]
    if (!is.character(column) && !is.factor(column)) {
      next
    }
    n_levels <- length(unique(column))
    if (n_levels > level_cap) {
      data_error(sprintf(
        paste0(
          "feature column '%s' is text with %d distinct values, too many to ",
          "dummy-expand. This usually means an identifier or free text was ",
          "selected by mistake. Drop it, or bin it into a few categories."
        ),
        column_name, n_levels
      ))
    }
  }
  invisible(NULL)
}

features_to_matrix <- function(feature_frame) {
  if (all(vapply(feature_frame, is.numeric, logical(1L)))) {
    matrix_form <- as.matrix(feature_frame)
    storage.mode(matrix_form) <- "double"
    return(matrix_form)
  }
  model_form <- stats::model.matrix(
    ~ . - 1,
    data = feature_frame
  )
  attr(model_form, "assign") <- NULL
  attr(model_form, "contrasts") <- NULL
  model_form[, , drop = FALSE]
}

as_numeric_cost <- function(value, label) {
  if (is.null(value)) {
    return(NULL)
  }
  if (!is.numeric(value)) {
    data_error(sprintf(
      paste0(
        "the %s column is %s, not numeric. Coerce it to numbers (for example ",
        "as.numeric()), or check it did not load as text. See ",
        "?dflasso-troubleshooting."
      ),
      label, class(value)[[1L]]
    ))
  }
  as.numeric(value)
}

data_error <- function(message, class = "dflasso_error_value") {
  stop(structure(
    class = c(class, "dflasso_error", "error", "condition"),
    list(message = message, call = NULL)
  ))
}
