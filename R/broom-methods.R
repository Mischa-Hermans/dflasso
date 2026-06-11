#' Broom methods for a fitted decision-focused lasso
#'
#' The broom verbs for a [DecisionFocusedLasso-class] fit. `tidy()` returns one
#' row per feature with its decision-stage coefficient, its
#' decision-relevance score, the penalty the decision focus used, and its role.
#' `glance()` returns a one-row model summary. `augment()` runs [decide()] on
#' new rows and attaches the predicted cost (and, with a solver, the decision)
#' under broom's `.`-prefix convention. `augment()` reads only the features,
#' never the realised cost.
#'
#' @param x A [DecisionFocusedLasso-class] object.
#' @param s Penalty strength the reported coefficient is read at:
#'   `"lambda.min"` (default), `"lambda.1se"`, or a numeric lambda.
#' @param ... Unused, present for method compatibility.
#'
#' @return `tidy()` returns a tibble with one row per feature and columns
#'   `term`, `estimate`, `proxy_score`, `adaptive_weight`, `penalty_factor`,
#'   `role`. `glance()` returns a one-row tibble of model-level fields.
#'   `augment()` returns the new rows with `.predicted_cost` (and the decision
#'   columns when a solver is available) attached.
#'
#' @examples
#' sim <- simulate_capital_allocation(60, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' tidy(fit)
#' glance(fit)
#' augment(fit, sim$x, sim$scenario, element_id_new = sim$element_id)
#'
#' @seealso [dfl_fit()], [summary.DecisionFocusedLasso], [regret()]
#' @name dfl-broom
#' @importFrom generics tidy glance augment
#' @importFrom tibble tibble as_tibble
#' @importFrom stats setNames predict
#' @include fitted-class.R predict-coef.R summary-print.R decide.R
NULL

#' @rdname dfl-broom
#' @export
tidy.DecisionFocusedLasso <- function(x, s = "lambda.min", ...) {
  estimates <- coef_estimates(x, s, "decision")
  roles <- classify_feature_roles(x)
  table <- tibble::tibble(
    term = x@feature_names,
    estimate = as.numeric(estimates),
    proxy_score = x@proxy_score,
    adaptive_weight = x@adaptive_weight,
    penalty_factor = x@penalty_factor,
    role = factor(
      roles,
      levels = c("decision-relevant", "both", "prediction-relevant", "neither")
    )
  )
  table[order(table$role, -table$proxy_score), , drop = FALSE]
}

#' @rdname dfl-broom
#' @export
glance.DecisionFocusedLasso <- function(x, ...) {
  decision_kept <- coefficients_of(x@decision_fit) != 0
  tibble::tibble(
    nobs = as.integer(x@decision_fit$glmnet.fit$nobs),
    n_instances = total_instances(x),
    n_proxy_eligible = x@n_proxy_eligible,
    n_partial_coverage = x@n_partial_coverage,
    n_features = length(x@feature_names),
    n_selected = sum(decision_kept),
    lambda_min = x@lambda_min,
    lambda_1se = x@lambda_1se,
    sense = x@sense,
    penalty_primary = x@penalty_primary,
    source = x@source,
    seed = x@seed
  )
}

#' @rdname dfl-broom
#' @param x_new Numeric feature matrix of new rows, the [decide()] features.
#' @param scenario_new Vector grouping the new rows into instances.
#' @param instances_new Optional named list of per-instance data, `NULL`
#'   auto-builds it from `scenario_new`.
#' @param element_id_new Optional per-row element ids, `NULL` uses per-scenario
#'   row positions.
#' @export
augment.DecisionFocusedLasso <- function(x, x_new, scenario_new,
                                         instances_new = NULL,
                                         element_id_new = NULL,
                                         newdata = NULL, s = "lambda.min",
                                         ...) {
  matrix_x <- match_new_features(x, x_new, "x_new")
  scenario <- as.character(scenario_new)
  element_id <- resolve_element_id(element_id_new, scenario_new,
                                   nrow(matrix_x))
  predicted_cost <- as.numeric(
    cbind(1, matrix_x) %*% as.numeric(stage_coef(x, s, "decision"))
  )
  attached <- augment_columns(x, matrix_x, scenario, element_id,
                              instances_new, predicted_cost, s)
  if (is.null(newdata)) {
    return(attached)
  }
  join_augment(newdata, attached)
}

coef_estimates <- function(object, s, penalty) {
  estimates <- stage_estimates(object, s, penalty)
  stats::setNames(estimates, object@feature_names)
}

augment_columns <- function(object, matrix_x, scenario, element_id,
                            instances_new, predicted_cost, s) {
  if (is.null(object@problem)) {
    return(tibble::tibble(
      scenario = scenario,
      element_id = element_id,
      .predicted_cost = predicted_cost
    ))
  }
  picks <- decide(object, matrix_x, scenario, instances_new = instances_new,
                  element_id_new = element_id, s = s)
  long <- as_tibble(picks)
  tibble::tibble(
    scenario = long$scenario,
    element_id = long$element_id,
    .decision = long$decision,
    .chosen = long$chosen,
    .predicted_cost = long$predicted_cost,
    .contribution = long$contribution,
    .feasible = long$feasible,
    .step = long$step
  )
}

join_augment <- function(newdata, attached) {
  keys <- c("scenario", "element_id")
  missing_keys <- setdiff(keys, names(newdata))
  if (length(missing_keys) > 0L) {
    decide_error(sprintf(
      paste0(
        "newdata must carry the join key(s) %s so the decision attaches by ",
        "id, not by row order."
      ),
      paste(sprintf("'%s'", missing_keys), collapse = ", ")
    ), "dflasso_error_usage")
  }
  frame <- as.data.frame(newdata, stringsAsFactors = FALSE)
  frame$scenario <- as.character(frame$scenario)
  frame$element_id <- as.character(frame$element_id)
  decision_columns <- setdiff(names(attached), keys)
  merged <- merge(frame, attached, by = keys, all.x = TRUE, sort = FALSE)
  tibble::as_tibble(merged[, c(setdiff(names(frame), keys), keys,
                               decision_columns), drop = FALSE])
}

total_instances <- function(object) {
  if (!is.null(object@coverage)) {
    return(nrow(object@coverage))
  }
  length(object@element_ids)
}
