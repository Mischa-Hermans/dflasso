#' Realised regret of the decision focus against the baseline
#'
#' On held-out data, `regret()` measures how much worse the decision-focused
#' fit's decisions turned out than the best possible in hindsight, and does the
#' same for a prediction-focused baseline on the same instances.
#'
#' Instances where a solved element has no realised cost are set aside (and
#' counted), as are infeasible ones. Both approaches are scored on the same
#' eligible instances.
#'
#' @param object A [DecisionFocusedLasso-class] object.
#' @param x_test Numeric feature matrix of held-out rows.
#' @param cost_test Numeric vector of realised costs for the held-out rows, `NA`
#'   allowed for unobserved elements.
#' @param scenario_test Vector grouping the held-out rows into instances.
#' @param instances_test Optional named list of per-instance data. `NULL`
#'   (default) auto-builds it from `scenario_test`.
#' @param element_id_test Optional per-row element ids. `NULL` (default) uses
#'   per-scenario row positions.
#' @param s Penalty strength for the predicted costs: `"lambda.min"` (default),
#'   `"lambda.1se"`, or a numeric lambda.
#' @param baseline Which baseline to compare against: `"adaptive"` (default, the
#'   prediction-focused adaptive lasso), `"plain"` (the plain lasso), or `"none"`
#'   for no comparison.
#' @param ... Unused, present for S4 compatibility.
#'
#' @return An S3 `dfl_regret` object with the mean and per-instance regret for
#'   the decision focus and the baseline, the baseline label, and the instance
#'   counts (`n_instances`, `n_proxy_eligible`, `n_partial_coverage`,
#'   `n_infeasible`). Its `print()` shows the head-to-head, the signed percent
#'   change, and the coverage line.
#'
#' @examples
#' sim <- simulate_capital_allocation(60, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' regret(fit, sim$x, sim$cost, sim$scenario)
#'
#' @seealso [decide()], [dfl_fit()].
#' @family dflasso workflow
#' @importFrom methods setGeneric setMethod is
#' @importFrom stats setNames
#' @include fitted-class.R predict-coef.R
#' @export
setGeneric("regret", function(object, x_test, cost_test, scenario_test,
                              instances_test = NULL, element_id_test = NULL,
                              s = "lambda.min",
                              baseline = c("adaptive", "plain", "none"),
                              ...) {
  standardGeneric("regret")
})

#' @rdname regret
setMethod(
  "regret",
  "DecisionFocusedLasso",
  function(object, x_test, cost_test, scenario_test, instances_test = NULL,
           element_id_test = NULL, s = "lambda.min",
           baseline = c("adaptive", "plain", "none"), ...) {
    baseline <- match.arg(baseline)
    if (is.null(object@problem)) {
      decide_error(
        paste0(
          "this model was fit from supplied regret and has no solver, so ",
          "out-of-sample regret cannot be measured. Fit with a problem, or ",
          "attach one and use decide() to act."
        ),
        "dflasso_error_no_solver"
      )
    }
    problem <- object@problem
    matrix_x <- match_new_features(object, x_test, "x_test")
    scenario <- as.character(scenario_test)
    cost <- as.numeric(cost_test)
    check_regret_lengths(matrix_x, scenario, cost)

    ids <- as.character(unique(scenario))
    instances <- resolve_instances(instances_test, scenario_test, problem)

    eligibility <- eligible_test_scenarios(problem, instances, scenario, cost,
                                           ids)
    eligible_ids <- eligibility$eligible
    n_partial_coverage <- length(ids) - length(eligible_ids)
    if (length(eligible_ids) == 0L) {
      decide_error(
        paste0(
          "no held-out instance has complete realised costs over its solved ",
          "elements, so regret cannot be measured. Supply test instances ",
          "where every solved element has an observed cost."
        ),
        "dflasso_error_coverage"
      )
    }

    cost_hat_decision <- predict(object, matrix_x, s = s, penalty = "decision")
    scored <- score_regret(
      problem, instances, scenario, cost, eligible_ids, cost_hat_decision
    )
    baseline_scored <- score_baseline(
      object, problem, instances, scenario, cost, eligible_ids, matrix_x, s,
      baseline
    )

    make_dfl_regret(
      scored, baseline_scored, baseline, length(ids), length(eligible_ids),
      n_partial_coverage
    )
  }
)

check_regret_lengths <- function(matrix_x, scenario, cost) {
  if (length(scenario) != nrow(matrix_x) || length(cost) != nrow(matrix_x)) {
    decide_error(sprintf(
      paste0(
        "nrow(x_test) (%d), length(cost_test) (%d), and ",
        "length(scenario_test) (%d) must all be equal, one row per element."
      ),
      nrow(matrix_x), length(cost), length(scenario)
    ), "dflasso_error_dimension")
  }
  invisible(NULL)
}

eligible_test_scenarios <- function(problem, instances, scenario, cost, ids) {
  observed <- !is.na(cost)
  eligible <- vapply(ids, function(scenario_id) {
    rows <- which(scenario == scenario_id)
    support <- resolve_support(problem, instances[[scenario_id]], rows)
    support_rows <- rows[support]
    length(support_rows) > 0L && all(observed[support_rows])
  }, logical(1L))
  list(eligible = ids[eligible])
}

score_regret <- function(problem, instances, scenario, cost, eligible_ids,
                         cost_hat) {
  per_scenario <- lapply(eligible_ids, function(scenario_id) {
    realised_regret_one(
      problem, instances[[scenario_id]], scenario, cost, scenario_id, cost_hat
    )
  })
  collect_regret(per_scenario, eligible_ids)
}

score_baseline <- function(object, problem, instances, scenario, cost,
                           eligible_ids, matrix_x, s, baseline) {
  if (baseline == "none") {
    return(NULL)
  }
  cost_hat <- predict(object, matrix_x, s = s, penalty = baseline)
  per_scenario <- lapply(eligible_ids, function(scenario_id) {
    realised_regret_one(
      problem, instances[[scenario_id]], scenario, cost, scenario_id, cost_hat
    )
  })
  collect_regret(per_scenario, eligible_ids)
}

realised_regret_one <- function(problem, instance, scenario, cost, scenario_id,
                                cost_hat) {
  rows <- which(scenario == scenario_id)
  realized_cost <- cost[rows]
  predicted_cost <- cost_hat[rows]
  decision <- guarded_solve(problem, predicted_cost, instance)
  oracle_decision <- guarded_solve(problem, realized_cost, instance)
  if (is.null(decision) || is.null(oracle_decision)) {
    return(list(regret = NA_real_, feasible = FALSE))
  }
  oracle_value <- decision_objective(realized_cost, oracle_decision)
  achieved_value <- decision_objective(realized_cost, as.numeric(decision))
  gap <- if (sense(problem) == "min") {
    achieved_value - oracle_value
  } else {
    oracle_value - achieved_value
  }
  list(regret = max(0, gap), feasible = TRUE)
}

guarded_solve <- function(problem, costs, instance) {
  tryCatch(
    solve_decision(problem, costs, instance),
    dflasso_infeasible = function(condition) NULL,
    dflasso_error_solver = function(condition) NULL,
    error = function(condition) NULL
  )
}

collect_regret <- function(per_scenario, eligible_ids) {
  regret_values <- vapply(per_scenario, `[[`, numeric(1L), "regret")
  feasible <- vapply(per_scenario, `[[`, logical(1L), "feasible")
  list(
    regret = stats::setNames(regret_values, eligible_ids),
    feasible = stats::setNames(feasible, eligible_ids)
  )
}

make_dfl_regret <- function(scored, baseline_scored, baseline, n_instances,
                            n_eligible, n_partial_coverage) {
  jointly_feasible <- if (is.null(baseline_scored)) {
    scored$feasible
  } else {
    scored$feasible & baseline_scored$feasible
  }
  n_infeasible <- sum(!jointly_feasible)
  per_instance <- scored$regret[jointly_feasible]
  mean_regret <- mean_or_na(per_instance)
  baseline_per_instance <- if (is.null(baseline_scored)) {
    NULL
  } else {
    baseline_scored$regret[jointly_feasible]
  }
  baseline_mean <- if (is.null(baseline_scored)) {
    NA_real_
  } else {
    mean_or_na(baseline_per_instance)
  }
  structure(
    list(
      regret = mean_regret,
      regret_per_instance = per_instance,
      regret_baseline = baseline_mean,
      regret_baseline_per_instance = baseline_per_instance,
      baseline = baseline,
      n_instances = n_instances,
      n_proxy_eligible = n_eligible,
      n_partial_coverage = n_partial_coverage,
      n_infeasible = n_infeasible,
      all_infeasible = n_eligible > 0L && n_infeasible == n_eligible
    ),
    class = "dfl_regret"
  )
}

mean_or_na <- function(values) {
  if (length(values) == 0L) {
    return(NA_real_)
  }
  mean(values, na.rm = TRUE)
}

#' @rdname regret
#' @param x A `dfl_regret` object.
#' @export
print.dfl_regret <- function(x, ...) {
  cat(format_dfl_regret(x), sep = "\n")
  invisible(x)
}

format_dfl_regret <- function(x) {
  lines <- c(
    "Decision quality vs the prediction-focused approach (dflasso regret)",
    "  Lower regret is better. Regret = how much worse a decision was than the",
    "  best possible in hindsight, averaged over instances.",
    ""
  )
  if (isTRUE(x$all_infeasible)) {
    return(c(lines, all_infeasible_lines(x)))
  }
  if (x$baseline == "none" || is.na(x$regret_baseline)) {
    lines <- c(lines, sprintf(
      "  Decision-focused model : %s average regret",
      format_regret_total(x$regret)
    ))
  } else {
    lines <- c(lines, head_to_head_lines(x))
  }
  c(lines, "", coverage_line(x))
}

all_infeasible_lines <- function(x) {
  sprintf(
    paste0(
      "  No instance could be scored: all %d covered held-out instance(s) ",
      "reached no feasible decision for one or both models, so there is no ",
      "regret to average. Supply held-out instances the solver can solve."
    ),
    x$n_proxy_eligible
  )
}

head_to_head_lines <- function(x) {
  decision_label <- "Decision-focused model "
  baseline_label <- "Prediction-focused model"
  decision_line <- sprintf("  %s: %s average regret", decision_label,
                           format_regret_total(x$regret))
  baseline_line <- sprintf("  %s: %s average regret", baseline_label,
                           format_regret_total(x$regret_baseline))
  verdict <- regret_verdict(x$regret, x$regret_baseline)
  if (x$regret <= x$regret_baseline) {
    return(c(decision_line, baseline_line, "", verdict))
  }
  c(baseline_line, decision_line, "", verdict)
}

regret_verdict <- function(decision, baseline) {
  if (!is.finite(baseline) || baseline == 0) {
    return("  -> regret comparison undefined (baseline regret is zero).")
  }
  percent <- abs(decision - baseline) / baseline * 100
  if (decision <= baseline) {
    return(sprintf(
      "  -> the decision focus cut regret by %s%% on this held-out data.",
      format_percent(percent)
    ))
  }
  sprintf(
    paste0(
      "  -> the decision focus RAISED regret by %s%% on this held-out data; ",
      "it lost here."
    ),
    format_percent(percent)
  )
}

coverage_line <- function(x) {
  percent <- if (x$n_instances > 0L) {
    round(x$n_proxy_eligible / x$n_instances * 100)
  } else {
    0
  }
  sprintf(
    paste0(
      "  Measured on %d of %d instances (%d%%); %d set aside for missing ",
      "costs, %d had no feasible decision. Both approaches were compared on ",
      "the very same instances."
    ),
    x$n_proxy_eligible, x$n_instances, percent, x$n_partial_coverage,
    x$n_infeasible
  )
}

format_percent <- function(value) {
  formatC(value, digits = 1L, format = "f")
}

format_regret_total <- function(value) {
  if (is.na(value)) {
    return("NA")
  }
  formatC(value, digits = 2L, format = "f")
}
