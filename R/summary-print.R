#' Summary of a fitted decision-focused lasso
#'
#' Turns a [DecisionFocusedLasso-class] fit into a one-screen report: how
#' many features were kept for the decision, which weak but decision-relevant
#' features the method rescued, what each feature is for, the filtering strength,
#' and the reproducibility fields. It reports no held-out regret, because that
#' needs test data; run [regret()] on a held-out split for that.
#'
#' Each feature is labelled by how it behaves. A feature the accuracy stage (the
#' ordinary or adaptive lasso) keeps is prediction-relevant. A feature that stage
#' would drop, yet the decision stage keeps because it tracks decision regret, is
#' decision-relevant. A feature both stages keep does both; a feature neither
#' keeps is left out.
#'
#' @param object A [DecisionFocusedLasso-class] object.
#' @param ... Unused, present for method compatibility.
#'
#' @return An S3 `summary.DecisionFocusedLasso` object carrying the role table,
#'   the rescued feature names, the kept count, coverage and reproducibility
#'   fields, and the resolved settings. Its `print()` renders the one-screen
#'   view.
#'
#' @examples
#' sim <- simulate_capital_allocation(60, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' summary(fit)
#'
#' @seealso [dfl_fit()], [regret()] for the held-out comparison, [tidy()] for
#'   every feature and its role.
#' @name summary.DecisionFocusedLasso
#' @importFrom stats setNames
#' @include fitted-class.R predict-coef.R
NULL

#' @rdname summary.DecisionFocusedLasso
#' @export
summary.DecisionFocusedLasso <- function(object, ...) {
  roles <- classify_feature_roles(object)
  rescued <- object@feature_names[roles == "decision-relevant"]
  counts <- role_counts(roles)
  control <- object@control
  structure(
    list(
      source = object@source,
      sense = object@sense,
      n_features = length(object@feature_names),
      n_selected = sum(counts[c("decision-relevant",
                                "prediction-relevant", "both")]),
      role_counts = counts,
      rescued = rescued,
      lambda = object@lambda_min,
      seed = object@seed,
      n_proxy_eligible = object@n_proxy_eligible,
      n_partial_coverage = object@n_partial_coverage,
      n_splits = if (is.null(control)) NA_integer_ else control$n_splits,
      standardize = object@standardize,
      nfolds = if (is.null(control)) NA_integer_ else control$nfolds,
      min_elements = if (is.null(control)) {
        NA_integer_
      } else {
        control$min_elements_per_scenario
      },
      changed_settings = changed_method_settings(control)
    ),
    class = "summary.DecisionFocusedLasso"
  )
}

#' @rdname summary.DecisionFocusedLasso
#' @param x A `summary.DecisionFocusedLasso` object.
#' @export
print.summary.DecisionFocusedLasso <- function(x, ...) {
  cat(format_dfl_summary(x), sep = "\n")
  invisible(x)
}

format_dfl_summary <- function(x) {
  lines <- c(summary_header(x), "")
  if (x$source == "supplied regret") {
    lines <- c(lines, supplied_regret_banner(), "")
  }
  c(
    lines,
    features_kept_block(x), "",
    role_block(x), "",
    pay_off_pointer(x), "",
    filtering_block(x), "",
    reproducibility_block(x), "",
    settings_block(x)
  )
}

summary_header <- function(x) {
  n_total <- x$n_proxy_eligible + x$n_partial_coverage
  header <- c(
    "Summary of a decision-focused cost model (dflasso)",
    sprintf(
      "Objective: %s over %d instances scored, %d features.",
      sense_phrase(x$sense), x$n_proxy_eligible, x$n_features
    )
  )
  if (x$n_partial_coverage > 0L) {
    header <- c(header, sprintf(
      paste0(
        "  %d of %d instances scored; %d set aside for missing or partial cost ",
        "coverage (see regret() and ?dflasso-troubleshooting)."
      ),
      x$n_proxy_eligible, n_total, x$n_partial_coverage
    ))
  }
  header
}

supplied_regret_banner <- function() {
  c(
    "Fit from supplied regret, no solver attached. To make decisions, attach",
    "one: decide(fit, x_new, scenario_new, problem = a_problem). See",
    "?dfl_score."
  )
}

features_kept_block <- function(x) {
  header <- c(
    "FEATURES KEPT",
    sprintf("  %d of %d features were kept for the decision.",
            x$n_selected, x$n_features)
  )
  n_rescued <- length(x$rescued)
  if (n_rescued == 0L) {
    return(c(header,
             "  None were decision-driven rescues on this fit.",
             paste0("  See tidy(fit) for every feature, its coefficient, ",
                    "and its role.")))
  }
  c(
    header,
    sprintf(paste0(
      "  %d of these %s decision-driven rescues, weak at predicting cost on ",
      "their own, but"), n_rescued, if (n_rescued == 1L) "is a" else "are"),
    "  they move the decision, so the model kept them:",
    sprintf("      %s", name_list(x$rescued)),
    paste0("  See tidy(fit) for every feature, its coefficient, ",
           "and its role.")
  )
}

role_block <- function(x) {
  counts <- x$role_counts
  rows <- c(
    sprintf(paste0(
      "  decision-relevant   %-4d were kept for the decision (rescued by the ",
      "decision step)"), counts[["decision-relevant"]]),
    sprintf(paste0(
      "  prediction-relevant %-4d were kept by the accuracy step (the usual ",
      "reason)"), counts[["prediction-relevant"]]),
    sprintf("  both                %-4d do both", counts[["both"]]),
    sprintf("  neither             %-4d not used by either model",
            counts[["neither"]])
  )
  c(
    "WHAT EACH FEATURE IS FOR  (across all features, by how they behave)",
    rows,
    "  These roles come from one random reshuffle of the instances, so they can",
    "  shift a little under a different seed. Judge a feature by its score in",
    "  tidy(fit), not by the bare label."
  )
}

pay_off_pointer <- function(x) {
  if (x$source == "supplied regret") {
    return(c(
      "DOES THE DECISION FOCUS PAY OFF?  (lower regret is better)",
      "  Scores come from the supplied regret (no resampling), not validated:",
      "  with no held-out decisions there is nothing to back-test the ranking",
      "  against."
    ))
  }
  c(
    "DOES THE DECISION FOCUS PAY OFF?  (lower regret is better)",
    "  Regret = how much worse a decision was than the best possible in",
    "  hindsight, averaged over instances.",
    "  This needs held-out data. Run regret(fit, x_test, cost_test,",
    "  scenario_test) to compare against the prediction-focused model.",
    "  See ?dflasso-validation."
  )
}

filtering_block <- function(x) {
  c(
    "HOW HARD FEATURES WERE FILTERED",
    sprintf(paste0(
      "  Filtering strength %s, chosen automatically by trying many settings ",
      "and"), format_lambda(x$lambda)),
    "  keeping the best; smaller keeps more features. (this setting is called",
    "  lambda)"
  )
}

reproducibility_block <- function(x) {
  lines <- c(
    "REPRODUCIBILITY",
    sprintf(paste0(
      "  Fit with seed %d; re-running with this seed gives bit-identical ",
      "features,"), x$seed),
    "  scores, and decisions. Pass seed = <int> to fix it up front and quote",
    "  that number."
  )
  if (x$source == "supplied regret") {
    return(lines)
  }
  c(lines, sprintf(
    paste0(
      "  Decision quality was averaged over %d random reshuffles of the ",
      "instances."
    ),
    x$n_splits
  ))
}

settings_block <- function(x) {
  scale_word <- if (isTRUE(x$standardize)) {
    "features put on a common scale"
  } else {
    "features left on their own scale"
  }
  main <- sprintf(
    paste0(
      "  main  : %s, %d-fold cross-validation, instances must have >= %d ",
      "elements."
    ),
    scale_word, x$nfolds, x$min_elements
  )
  method <- if (length(x$changed_settings) == 0L) {
    "  method: all at defaults."
  } else {
    sprintf("  method: %s (rest at defaults).",
            paste(x$changed_settings, collapse = ", "))
  }
  c("SETTINGS", main, method)
}

role_counts <- function(roles) {
  levels <- c("decision-relevant", "prediction-relevant", "both", "neither")
  counts <- table(factor(roles, levels = levels))
  stats::setNames(as.integer(counts), levels)
}

changed_method_settings <- function(control) {
  if (is.null(control)) {
    return(character(0))
  }
  defaults <- formals(dfl_control)
  method_settings <- c(
    "gamma", "kappa", "proxy_score_reference", "w_min", "w_max",
    "n_splits", "split_fraction", "eligibility_threshold", "score_floor"
  )
  changed <- character(0)
  for (setting in method_settings) {
    default_value <- eval(defaults[[setting]])
    current <- control[[setting]]
    if (!identical_setting(current, default_value)) {
      changed <- c(changed, sprintf("%s = %s", setting, format_setting(current)))
    }
  }
  changed
}

identical_setting <- function(current, default_value) {
  if (is.null(current) || is.null(default_value)) {
    return(is.null(current) && is.null(default_value))
  }
  isTRUE(all.equal(as.numeric(current), as.numeric(default_value)))
}

format_setting <- function(value) {
  if (is.null(value)) "NULL" else format(value)
}

sense_phrase <- function(sense) {
  if (sense == "min") "minimise cost" else "maximise value"
}

name_list <- function(names, limit = 4L) {
  if (length(names) == 0L) {
    return("none")
  }
  shown <- utils::head(names, limit)
  joined <- paste(shown, collapse = ", ")
  more <- length(names) - length(shown)
  if (more > 0L) {
    return(sprintf("%s (+%d more, see tidy(fit))", joined, more))
  }
  joined
}

format_lambda <- function(value) {
  formatC(value, digits = 3L, format = "f")
}

classify_feature_roles <- function(object) {
  decision_kept <- coefficients_of(object@decision_fit) != 0
  predictor <- prediction_stage_kept(object)
  eased <- penalty_eased(object)
  scored <- decision_tracking(object)
  roles <- rep("neither", length(object@feature_names))
  roles[decision_kept & predictor & !(eased & scored)] <- "prediction-relevant"
  roles[decision_kept & predictor & eased & scored] <- "both"
  roles[decision_kept & !predictor & scored] <- "decision-relevant"
  roles[decision_kept & !predictor & !scored] <- "prediction-relevant"
  roles
}

prediction_stage_kept <- function(object) {
  coefficients_of(object@adaptive_fit) != 0
}

penalty_eased <- function(object) {
  object@penalty_factor < object@adaptive_weight - 1e-8
}

decision_tracking <- function(object) {
  control <- object@control
  floor <- if (is.null(control)) 1e-3 else control$score_floor
  object@proxy_score > floor
}
