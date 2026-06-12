#' Rank features by how strongly they track regret
#'
#' When per-instance regret is already available, `dfl_score()` ranks features
#' by how strongly each correlates with that regret, skipping the model fit and
#' solver that [dfl_fit()] runs.
#'
#' @param data_or_x One data frame read like [dfl_data()] (with `features` a
#'   tidyselect spec and `scenario`/`regret` column names), or a numeric feature
#'   matrix `x` with loose `scenario`/`regret` vectors. In the matrix form
#'   `regret` must self-key: a numeric named by scenario id, or a two-column
#'   `(id, regret)` data frame. A bare positional vector is rejected.
#' @param features The feature columns when `data_or_x` is a data frame, a
#'   tidyselect specification.
#' @param scenario The grouping column (data-frame form) or per-row scenario
#'   vector (matrix form).
#' @param regret The realised-regret column (data-frame form) or the self-keyed
#'   regret (matrix form). One value per scenario.
#' @param sense Objective sense of the diagnosed model, `"min"` (default) or
#'   `"max"`. Recorded, not used to transform supplied regret.
#' @param control A `dfl_control` list. Only `score_floor` is read here.
#'
#' @return An S3 `dfl_score` object: a ranked tibble with columns `rank`, `term`,
#'   `proxy_score`, `role` (an ordered factor, `decision-relevant` or
#'   `neither`), and `reading` (a plain gloss of the score band). Its `print()`
#'   shows the ranking and the not-validated footer.
#'
#' @examples
#' set.seed(1)
#' backtest <- data.frame(
#'   date = rep(c("d1", "d2", "d3", "d4", "d5", "d6"), each = 4),
#'   feat_rain = rnorm(24), feat_speed = rnorm(24), feat_hist = rnorm(24),
#'   regret = rep(c(4.1, 0.0, 7.8, 1.2, 6.5, 0.3), each = 4)
#' )
#' dfl_score(
#'   backtest,
#'   features = starts_with("feat_"), scenario = date, regret = regret
#' )
#'
#' @seealso [dfl_fit()] to also fit a model, [regret_from_objectives()] and
#'   [regret_from_decisions()] to build the regret vector first.
#' @family dflasso workflow
#' @importFrom rlang enquo quo_is_null
#' @importFrom tibble tibble
#' @importFrom stats setNames
#' @include fit.R data-helpers.R
#' @export
dfl_score <- function(data_or_x, features, scenario, regret,
                      sense = c("min", "max"), control = dfl_control()) {
  sense <- match.arg(sense)
  if (!inherits(control, "dfl_control")) {
    data_error("control must come from dfl_control().", "dflasso_error_usage")
  }
  prepared <- if (is.data.frame(data_or_x)) {
    score_inputs_from_frame(
      data_or_x, rlang::enquo(features), rlang::enquo(scenario),
      rlang::enquo(regret)
    )
  } else {
    score_inputs_from_matrix(data_or_x, scenario, regret)
  }

  aligned_regret <- align_score_regret(prepared$regret, prepared$scenario)
  aligned_regret <- guard_regret_values(aligned_regret, sense)
  note_supplied_regret()

  scores <- score_features(prepared$x, prepared$scenario, aligned_regret)
  build_dfl_score(
    scores, prepared$feature_names, sense,
    length(unique(prepared$scenario))
  )
}

score_inputs_from_frame <- function(data, features_quo, scenario_quo,
                                    regret_quo) {
  if (nrow(data) == 0L) {
    data_error("data has no rows, so there is nothing to score.")
  }
  feature_columns <- select_columns(features_quo, data, "features")
  if (length(feature_columns) == 0L) {
    data_error(paste0(
      "features selected no columns. Name at least one feature ",
      "column."
    ))
  }
  scenario_values <- select_single_column(scenario_quo, data, "scenario")
  if (rlang::quo_is_null(regret_quo)) {
    data_error("regret must name a column for the data-frame form.")
  }
  regret_values <- select_single_column(regret_quo, data, "regret")
  matrix_x <- features_to_matrix(data[, feature_columns, drop = FALSE])
  list(
    x = matrix_x,
    scenario = as.character(scenario_values),
    regret = regret_constant_per_scenario(
      regret_values, as.character(scenario_values)
    ),
    feature_names = colnames(matrix_x)
  )
}

score_inputs_from_matrix <- function(x, scenario, regret) {
  if (!is.matrix(x) || !is.numeric(x)) {
    data_error(
      paste0(
        "data_or_x must be a data frame or a numeric matrix. For the loose ",
        "form pass a numeric x with self-keyed scenario and regret."
      ),
      "dflasso_error_usage"
    )
  }
  reject_bare_positional_regret(regret)
  storage.mode(x) <- "double"
  scenario_values <- as.character(scenario)
  if (length(scenario_values) != nrow(x)) {
    data_error(sprintf(
      paste0(
        "nrow(x) (%d) and length(scenario) (%d) must be equal, one row per ",
        "element."
      ),
      nrow(x), length(scenario_values)
    ), "dflasso_error_dimension")
  }
  list(
    x = x,
    scenario = scenario_values,
    regret = regret,
    feature_names = feature_labels(x)
  )
}

regret_constant_per_scenario <- function(regret_values, scenario) {
  by_scenario <- split(as.numeric(regret_values), scenario)
  reduced <- vapply(names(by_scenario), function(scenario_id) {
    values <- unique(by_scenario[[scenario_id]])
    if (length(values) != 1L) {
      data_error(sprintf(
        paste0(
          "regret varies within scenario '%s'; it must be one value per ",
          "instance (constant across that instance's rows)."
        ),
        scenario_id
      ), "dflasso_error_value")
    }
    values
  }, numeric(1L))
  stats::setNames(reduced, names(by_scenario))
}

reject_bare_positional_regret <- function(regret) {
  bare <- is.numeric(regret) && !inherits(regret, "AsIs") &&
    is.null(names(regret))
  if (bare) {
    data_error(
      paste0(
        "regret must be named by scenario id (or a column / data frame keyed ",
        "by the scenario id), so it cannot fall out of line with x; a bare ",
        "positional vector is the row-misalignment trap dflasso refuses."
      ),
      "dflasso_error_alignment"
    )
  }
  invisible(NULL)
}

align_score_regret <- function(regret, scenario) {
  ids <- as.character(unique(scenario))
  if (inherits(regret, "AsIs")) {
    aligned <- as.numeric(regret)
    if (length(aligned) != length(ids)) {
      data_error(
        paste0(
          "an I() regret vector must have one value per scenario, in ",
          "scenario order."
        ),
        "dflasso_error_alignment"
      )
    }
    return(stats::setNames(aligned, ids))
  }
  if (is.data.frame(regret)) {
    regret <- regret_frame_to_named(regret, ids)
  }
  aligned <- align_scenario_regret(regret, ids)
  stats::setNames(aligned, ids)
}

regret_frame_to_named <- function(regret, ids) {
  if (ncol(regret) != 2L) {
    data_error(
      "a data-frame regret must have two columns: the scenario id and regret.",
      "dflasso_error_alignment"
    )
  }
  regret_column <- if ("regret" %in% names(regret)) {
    "regret"
  } else {
    names(regret)[[2L]]
  }
  id_column <- setdiff(names(regret), regret_column)[[1L]]
  keyed <- stats::setNames(
    as.numeric(regret[[regret_column]]), as.character(regret[[id_column]])
  )
  align_scenario_regret(keyed, ids)
}

score_features <- function(x, scenario, regret) {
  ids <- as.character(unique(scenario))
  scenario_features <- scenario_level_features(
    list(x = x, scenario = scenario), ids
  )
  ordered_regret <- regret[rownames(scenario_features)]
  as.numeric(column_correlation_abs(scenario_features, ordered_regret))
}

build_dfl_score <- function(scores, feature_names, sense, n_instances) {
  table <- tibble::tibble(
    term = feature_names,
    proxy_score = scores,
    role = score_role(scores),
    reading = score_reading(scores)
  )
  ordered <- table[order(-table$proxy_score), , drop = FALSE]
  ordered$rank <- seq_len(nrow(ordered))
  ordered <- ordered[, c("rank", "term", "proxy_score", "role", "reading")]
  structure(
    ordered,
    class = c("dfl_score", class(ordered)),
    sense = sense,
    n_instances = n_instances
  )
}

score_role <- function(scores) {
  level <- ifelse(scores >= score_association_threshold(),
                  "decision-relevant", "neither")
  factor(level, levels = c("decision-relevant", "neither"), ordered = TRUE)
}

score_reading <- function(scores) {
  reading <- rep("no association", length(scores))
  reading[scores >= score_association_threshold()] <- "tracks regret somewhat"
  reading[scores >= 0.5] <- "strongly tracks regret"
  reading[is.na(scores)] <- "no signal in any instance"
  reading
}

score_association_threshold <- function() {
  0.1
}

#' @rdname dfl_score
#' @param x A `dfl_score` object.
#' @param ... Unused, present for method compatibility.
#' @export
print.dfl_score <- function(x, ...) {
  cat(format_dfl_score(x), sep = "\n")
  invisible(x)
}

format_dfl_score <- function(x) {
  header <- sprintf(
    paste0(
      "Which features track decision failures?  ",
      "(supplied regret, %d features)"
    ),
    nrow(x)
  )
  table_lines <- score_table_lines(x)
  footer <- c(
    "  score = |correlation(feature, regret)|, 0-1.",
    paste0(
      "  Not a validated result: with no held-out decisions ",
      "dflasso can't confirm this ranking."
    ),
    paste0(
      "  Valid only if the regret is OUT-OF-SAMPLE from the model being ",
      "diagnosed (>= 0, not in-sample, not dflasso's)."
    ),
    paste0(
      "  Association with decision failure. decide() ",
      "needs a solver."
    )
  )
  c(header, "", table_lines, "", footer)
}

score_table_lines <- function(x) {
  header <- sprintf("  %4s  %-14s %6s   %s", "rank", "feature", "score",
                    "reading")
  body <- vapply(seq_len(nrow(x)), function(row_index) {
    sprintf(
      "  %4d  %-14s %6s   %s",
      x$rank[[row_index]], x$term[[row_index]],
      format_score(x$proxy_score[[row_index]]), x$reading[[row_index]]
    )
  }, character(1L))
  c(header, body)
}

format_score <- function(value) {
  if (is.na(value)) {
    return("NA")
  }
  formatC(value, digits = 2L, format = "f")
}


#' Build a regret vector from objective values or decisions
#'
#' `regret_from_objectives()` and `regret_from_decisions()` return a per-scenario
#' regret vector that feeds [dfl_score()] or [dfl_fit()].
#'
#' @param scenario Per-instance or per-row scenario vector.
#' @param value_model The diagnosed model's achieved objective, one value per
#'   instance or per row.
#' @param value_oracle The best achievable objective, one value per instance or
#'   per row.
#' @param sense Objective sense, `"min"` (default) or `"max"`.
#'
#' @return A named numeric, one regret per unique scenario, clamped at zero.
#'
#' @examples
#' regret_from_objectives(
#'   scenario = c("a", "b", "c"),
#'   value_model = c(12, 9, 15),
#'   value_oracle = c(10, 9, 11),
#'   sense = "min"
#' )
#'
#' @seealso [dfl_score()], [dfl_fit()]
#' @export
regret_from_objectives <- function(scenario, value_model, value_oracle,
                                   sense = c("min", "max")) {
  sense <- match.arg(sense)
  ids <- as.character(unique(scenario))
  model_value <- reduce_to_scenario(value_model, scenario, ids, "value_model")
  oracle_value <- reduce_to_scenario(value_oracle, scenario, ids,
                                     "value_oracle")
  gap <- if (sense == "min") {
    model_value - oracle_value
  } else {
    oracle_value - model_value
  }
  stats::setNames(pmax(0, gap), ids)
}

#' @rdname regret_from_objectives
#' @param cost Per-element realised cost vector.
#' @param decision_model The diagnosed model's per-element decision (0/1 or
#'   weight).
#' @param decision_oracle The oracle per-element decision.
#' @export
regret_from_decisions <- function(scenario, cost, decision_model,
                                  decision_oracle, sense = c("min", "max")) {
  sense <- match.arg(sense)
  ids <- as.character(unique(scenario))
  scenario_values <- as.character(scenario)
  model_value <- decision_value_per_scenario(
    cost, decision_model, scenario_values, ids
  )
  oracle_value <- decision_value_per_scenario(
    cost, decision_oracle, scenario_values, ids
  )
  regret_from_objectives(ids, model_value, oracle_value, sense = sense)
}

decision_value_per_scenario <- function(cost, decision, scenario, ids) {
  contribution <- as.numeric(cost) * as.numeric(decision)
  by_scenario <- split(contribution, scenario)
  values <- vapply(ids, function(scenario_id) {
    sum(by_scenario[[scenario_id]])
  }, numeric(1L))
  stats::setNames(values, ids)
}

reduce_to_scenario <- function(values, scenario, ids, label) {
  numeric_values <- as.numeric(values)
  if (length(numeric_values) == length(ids)) {
    return(stats::setNames(numeric_values, ids))
  }
  if (length(numeric_values) != length(scenario)) {
    data_error(sprintf(
      paste0(
        "%s has length %d, which matches neither the number of scenarios ",
        "(%d) nor the number of rows (%d)."
      ),
      label, length(numeric_values), length(ids), length(scenario)
    ), "dflasso_error_dimension")
  }
  by_scenario <- split(numeric_values, as.character(scenario))
  reduced <- vapply(ids, function(scenario_id) {
    unique_values <- unique(by_scenario[[scenario_id]])
    if (length(unique_values) != 1L) {
      data_error(sprintf(
        paste0(
          "%s varies within scenario '%s'; it must be constant within an ",
          "instance, or pass one value per instance."
        ),
        label, scenario_id
      ), "dflasso_error_value")
    }
    unique_values
  }, numeric(1L))
  stats::setNames(reduced, ids)
}
