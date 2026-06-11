#' Fit a decision-focused lasso
#'
#' Learns a sparse linear cost model whose feature selection is driven by
#' downstream decision quality, not prediction error alone. It fits a plain
#' lasso and an adaptive lasso alongside the decision-focused fit, all on one
#' shared fold structure.
#'
#' @details
#' One row per decision element per scenario (for example one row per asset per
#' period), not one row per scenario. [dfl_data()] shapes it from one frame;
#' `cost` and `scenario` carry one value per row, aligned to the rows of `x`.
#'
#' Two entry modes share this one function. The **solver path** (`problem =`)
#' computes regret by solving each scenario under predicted and realised costs,
#' scores how strongly each feature tracks that regret, and eases the penalty on
#' the features that move the decision. The **supplied-regret path** (`regret =`)
#' skips the solver entirely and reads the per-scenario regret supplied; the rest
#' of the fit is the same. Supply exactly one of `problem` or `regret`.
#'
#' @param data_or_x The numeric feature matrix `x`, one row per element. Build
#'   it from a data frame with [dfl_data()] first, then pass `prepared$x`; a
#'   data frame is not read here (unlike [dfl_score()], which takes a
#'   `features =` spec).
#' @param cost Numeric vector of realised costs, one per row, `NA` allowed.
#'   Required on both paths to fit the cost model.
#' @param scenario Vector grouping rows into instances; each distinct value is
#'   one instance.
#' @param problem An [OptimizationProblem-class] object for the solver path.
#'   Supply this or `regret`, not both.
#' @param regret Named per-scenario regret for the supplied-regret path.
#'   Supply this or `problem`, not both.
#' @param sense Used only with `regret =`, to record and echo the diagnosed
#'   objective's direction. The solver path reads sense off `problem`.
#' @param instances Optional named list of per-scenario instances. `NULL`
#'   auto-builds it from `scenario` for built-ins that derive their instance
#'   from element counts and for custom solvers needing no per-instance data.
#' @param element_id Optional per-row element ids. `NULL` uses per-scenario row
#'   positions.
#' @param penalty Which stage is primary for bare `coef`/`predict`/`decide`,
#'   one of `"decision"` (default), `"adaptive"`, `"plain"`. All three are
#'   always computed.
#' @param control A `dfl_control` list of settings.
#' @param ... Caught only to give a clear error. `dfl_fit` takes the numeric
#'   `x`/`cost`/`scenario` that [dfl_data()] returns, not a `features =`
#'   tidyselect spec like [dfl_score()]; an unmatched argument here is reported
#'   rather than silently dropped.
#'
#' @return An S4 [DecisionFocusedLasso-class] object.
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
#'
#' @seealso [dfl_control()], [dfl_data()], [proxy_score()],
#'   [DecisionFocusedLasso-class]
#' @family dflasso workflow
#' @importFrom glmnet cv.glmnet glmnet coef.glmnet
#' @importFrom foreach foreach %dopar% %do% registerDoSEQ
#' @importFrom doRNG %dorng%
#' @importFrom stats setNames quantile rbinom predict
#' @export
#' @include fitted-class.R
dfl_fit <- function(data_or_x,
                    cost,
                    scenario,
                    problem = NULL,
                    regret = NULL,
                    sense = c("min", "max"),
                    instances = NULL,
                    element_id = NULL,
                    penalty = c("decision", "adaptive", "plain"),
                    control = dfl_control(),
                    ...) {
  call <- match.call()
  guard_dfl_fit_arguments(data_or_x, ...names())
  penalty <- match.arg(penalty)
  sense <- match.arg(sense)
  if (!inherits(control, "dfl_control")) {
    fit_error("control must come from dfl_control().", "dflasso_error_usage")
  }

  inputs <- resolve_fit_inputs(
    data_or_x, cost, scenario, regret, element_id, sense
  )

  if (is.null(problem) && is.null(inputs$regret)) {
    fit_error(
      "supply a problem to solve, or your own regret.",
      "dflasso_error_usage"
    )
  }
  if (!is.null(problem) && !is.null(inputs$regret)) {
    fit_error(
      paste0(
        "supply exactly one of problem (let dflasso compute regret by ",
        "solving) or regret (your own), not both."
      ),
      "dflasso_error_usage"
    )
  }

  if (is.null(problem)) {
    fit_supplied_regret(inputs, sense, penalty, control, call)
  } else {
    fit_solver(inputs, problem, instances, penalty, control, call)
  }
}

guard_dfl_fit_arguments <- function(data_or_x, extra_names) {
  if (is.data.frame(data_or_x)) {
    fit_error(
      paste0(
        "dfl_fit takes the numeric x, cost, and scenario that dfl_data() ",
        "returns, not a data frame with a features = spec like dfl_score(). ",
        "Prepare the data first: prepared <- dfl_data(data, features = ..., ",
        "cost = ..., scenario = ...); dfl_fit(prepared$x, prepared$cost, ",
        "prepared$scenario, problem = ...)."
      ),
      "dflasso_error_usage"
    )
  }
  if (length(extra_names) == 0L) {
    return(invisible(NULL))
  }
  if ("features" %in% extra_names) {
    fit_error(
      paste0(
        "dfl_fit has no features = argument; that is dfl_score()'s tidyselect ",
        "spec. dfl_fit takes the numeric x, cost, and scenario from ",
        "dfl_data(): prepared <- dfl_data(data, features = ..., cost = ..., ",
        "scenario = ...); dfl_fit(prepared$x, prepared$cost, ",
        "prepared$scenario, problem = ...)."
      ),
      "dflasso_error_usage"
    )
  }
  first <- if (extra_names[[1L]] == "") {
    "an unnamed extra argument"
  } else {
    sprintf("unknown argument '%s'", extra_names[[1L]])
  }
  fit_error(
    sprintf("dfl_fit received %s.", first),
    "dflasso_error_usage"
  )
}

fit_solver <- function(inputs, problem, instances, penalty, control, call) {
  validate_fit_inputs(inputs)
  instances <- resolve_instances(instances, inputs$scenario, problem)

  seed <- resolve_seed(control$seed)
  modelling <- modelling_rows(inputs, control)

  probe_solver(problem, instances, inputs)
  coverage <- compute_proxy_coverage(problem, instances, inputs, control)

  foldid <- make_foldid(modelling$scenario, control$nfolds, seed)
  adaptive_weight <- compute_adaptive_weights(modelling, foldid, control)
  plain_fit <- fit_plain_lasso(modelling, foldid, control)
  adaptive_fit <- fit_adaptive_lasso(
    modelling, foldid, adaptive_weight, control
  )

  proxy_splits <- make_proxy_splits(coverage$eligible_scenarios, control, seed)
  proxy_score <- compute_proxy_score(
    problem, instances, inputs, modelling,
    coverage$eligible_scenarios, proxy_splits,
    adaptive_weight, adaptive_fit, control
  )

  reshaped <- reshape_penalty(adaptive_weight, proxy_score, control)
  decision_fit <- fit_decision_lasso(
    modelling, foldid, reshaped$penalty_factor, control
  )

  assemble_fit(
    decision_fit = decision_fit,
    adaptive_fit = adaptive_fit,
    plain_fit = plain_fit,
    adaptive_weight = adaptive_weight,
    proxy_score = proxy_score,
    penalty_factor = reshaped$penalty_factor,
    inputs = inputs,
    coverage = coverage$report,
    problem = problem,
    sense = sense(problem),
    penalty_primary = penalty,
    eligibility_threshold = reshaped$eligibility_threshold,
    n_proxy_eligible = length(coverage$eligible_scenarios),
    n_partial_coverage = coverage$n_partial_coverage,
    splits = proxy_splits,
    seed = seed,
    control = control,
    source = "solver",
    call = call
  )
}

fit_supplied_regret <- function(inputs, sense, penalty, control, call) {
  validate_fit_inputs(inputs)
  if (is.null(inputs$cost)) {
    fit_error(
      paste0(
        "regret without cost cannot fit a cost model (nothing to regress). ",
        "For the feature ranking alone use dfl_score(data, features, ",
        "scenario, regret); to also fit the proxy-weighted model, name the ",
        "realised cost column."
      ),
      "dflasso_error_usage"
    )
  }
  regret <- validate_supplied_regret(inputs$regret, inputs$scenario, sense)
  note_supplied_regret()

  seed <- resolve_seed(control$seed)
  modelling <- modelling_rows(inputs, control)

  foldid <- make_foldid(modelling$scenario, control$nfolds, seed)
  adaptive_weight <- compute_adaptive_weights(modelling, foldid, control)
  plain_fit <- fit_plain_lasso(modelling, foldid, control)
  adaptive_fit <- fit_adaptive_lasso(
    modelling, foldid, adaptive_weight, control
  )

  proxy_score <- score_supplied_regret(inputs, regret)
  reshaped <- reshape_penalty(adaptive_weight, proxy_score, control)
  decision_fit <- fit_decision_lasso(
    modelling, foldid, reshaped$penalty_factor, control
  )

  assemble_fit(
    decision_fit = decision_fit,
    adaptive_fit = adaptive_fit,
    plain_fit = plain_fit,
    adaptive_weight = adaptive_weight,
    proxy_score = proxy_score,
    penalty_factor = reshaped$penalty_factor,
    inputs = inputs,
    coverage = NULL,
    problem = NULL,
    sense = sense,
    penalty_primary = penalty,
    eligibility_threshold = reshaped$eligibility_threshold,
    n_proxy_eligible = length(unique(inputs$scenario)),
    n_partial_coverage = 0L,
    splits = NULL,
    seed = seed,
    control = control,
    source = "supplied regret",
    call = call
  )
}

resolve_fit_inputs <- function(data_or_x, cost, scenario, regret,
                               element_id, sense) {
  x <- as_feature_matrix(data_or_x)
  list(
    x = x,
    cost = if (missing(cost)) NULL else as_fit_cost(cost),
    scenario = as.character(scenario),
    scenario_raw = scenario,
    regret = regret,
    element_id = resolve_element_id(element_id, scenario, nrow(x)),
    features_named = !is.null(colnames(x)),
    feature_names = feature_labels(x)
  )
}

as_feature_matrix <- function(x) {
  if (is.matrix(x) && is.numeric(x)) {
    storage.mode(x) <- "double"
    return(x)
  }
  if (is.numeric(x)) {
    return(matrix(as.numeric(x), ncol = 1L))
  }
  fit_error(
    "x must be a numeric matrix, one row per element.",
    "dflasso_error_dimension"
  )
}

as_fit_cost <- function(cost) {
  if (is.numeric(cost)) {
    return(as.numeric(cost))
  }
  fit_error(sprintf(
    paste0(
      "cost is %s, not numeric. cost must be a numeric vector, one per row; ",
      "if it came from a column, coerce that column to numbers (for example ",
      "as.numeric()) or check it did not load as text. dfl_fit does not ",
      "silently coerce text to numbers. See ?dflasso-troubleshooting."
    ),
    class(cost)[[1L]]
  ), "dflasso_error_usage")
}

feature_labels <- function(x) {
  if (!is.null(colnames(x))) {
    return(colnames(x))
  }
  sprintf("V%d", seq_len(ncol(x)))
}

resolve_element_id <- function(element_id, scenario, n_rows) {
  if (!is.null(element_id)) {
    return(as.character(element_id))
  }
  positions <- stats::ave(
    seq_along(scenario),
    as.character(scenario),
    FUN = seq_along
  )
  as.character(positions)
}

validate_fit_inputs <- function(inputs) {
  problems <- character(0)
  n_rows <- nrow(inputs$x)

  if (!is.null(inputs$cost) && length(inputs$cost) != n_rows) {
    problems <- c(problems, sprintf(
      paste0(
        "nrow(x) (%d), length(cost) (%d), and length(scenario) (%d) must ",
        "all be equal, one row per element."
      ),
      n_rows, length(inputs$cost), length(inputs$scenario)
    ))
  }
  if (length(inputs$scenario) != n_rows) {
    problems <- c(problems, sprintf(
      paste0(
        "nrow(x) (%d) and length(scenario) (%d) must be equal, one row per ",
        "element."
      ),
      n_rows, length(inputs$scenario)
    ))
  }

  missing_features <- which(!is.finite(inputs$x), arr.ind = TRUE)
  if (nrow(missing_features) > 0L) {
    first <- missing_features[1L, ]
    column_label <- if (inputs$features_named) {
      sprintf("'%s'", inputs$feature_names[[first[["col"]]]])
    } else {
      sprintf("column %d (no column names set)", first[["col"]])
    }
    problems <- c(problems, sprintf(
      paste0(
        "x has %d missing value(s); the first is in %s (row %d). Features ",
        "cannot be missing: impute or drop them before fitting."
      ),
      nrow(missing_features), column_label, first[["row"]]
    ))
  }

  if (!is.null(inputs$cost)) {
    problems <- c(problems, check_cost_values(inputs$cost))
  }
  problems <- c(problems, check_duplicate_ids(inputs))

  if (length(problems) > 0L) {
    report_fit_problems(problems)
  }
  invisible(inputs)
}

check_cost_values <- function(cost) {
  if (all(is.na(cost))) {
    return(paste0(
      "Every value in cost is NA, so there is nothing to learn the cost model ",
      "from. Check the realised-cost column was passed (NA is for the ",
      "occasional unobserved element, not the whole vector)."
    ))
  }
  bad <- is.nan(cost) | (is.infinite(cost))
  if (any(bad)) {
    return(sprintf(
      paste0(
        "cost has %d non-finite value(s) (Inf or NaN). Use NA, never ",
        "Inf/NaN, for an unobserved cost."
      ),
      sum(bad)
    ))
  }
  character(0)
}

check_duplicate_ids <- function(inputs) {
  by_scenario <- split(inputs$element_id, inputs$scenario)
  offending <- character(0)
  for (scenario_id in names(by_scenario)) {
    ids <- by_scenario[[scenario_id]]
    duplicated_ids <- unique(ids[duplicated(ids)])
    if (length(duplicated_ids) > 0L) {
      offending <- c(offending, sprintf(
        "element_id has duplicate id(s) within scenario '%s': %s",
        scenario_id, truncate_ids(duplicated_ids)
      ))
    }
  }
  if (length(offending) == 0L) {
    return(character(0))
  }
  paste0(
    offending[[1L]],
    ". Each element in a scenario needs a unique id, because decisions are ",
    "returned named by id."
  )
}

resolve_instances <- function(instances, scenario, problem) {
  ids <- as.character(unique(scenario))
  if (is.null(instances)) {
    return(auto_build_instances(scenario, problem, ids))
  }
  check_instance_names(instances, ids)
  instances
}

auto_build_instances <- function(scenario, problem, ids) {
  if (is(problem, "CapitalAllocationProblem")) {
    counts <- table_counts(scenario, ids)
    instances <- lapply(counts, function(count) list(n_assets = count))
    names(instances) <- ids
    return(instances)
  }
  if (is(problem, "ShortestPathProblem") || is(problem, "KnapsackProblem")) {
    fit_error(sprintf(
      paste0(
        "%s needs per-instance data, so instances cannot be auto-built. ",
        "Build it with make_instances(scenario, ...) (the graph for a ",
        "shortest path, weights and capacity for a knapsack)."
      ),
      problem@name
    ), "dflasso_error_usage")
  }
  instances <- replicate(length(ids), list(), simplify = FALSE)
  names(instances) <- ids
  instances
}

table_counts <- function(scenario, ids) {
  counts <- as.integer(table(factor(as.character(scenario), levels = ids)))
  stats::setNames(counts, ids)
}

check_instance_names <- function(instances, ids) {
  if (is.null(names(instances))) {
    fit_error(
      paste0(
        "names(instances) must be the scenario ids. Build the list with ",
        "make_instances(scenario, ...), which names it automatically."
      ),
      "dflasso_error_usage"
    )
  }
  missing_ids <- setdiff(ids, names(instances))
  unexpected_ids <- setdiff(names(instances), ids)
  if (length(missing_ids) > 0L || length(unexpected_ids) > 0L) {
    fit_error(sprintf(
      paste0(
        "names(instances) must be the scenario ids. Missing: %s. ",
        "Unexpected: %s. Build the list with make_instances(scenario, ...), ",
        "which names it automatically."
      ),
      truncate_ids(missing_ids), truncate_ids(unexpected_ids)
    ), "dflasso_error_usage")
  }
  invisible(instances)
}

probe_solver <- function(problem, instances, inputs) {
  scenario_id <- inputs$scenario[[1L]]
  rows <- which(inputs$scenario == scenario_id)
  probe_costs <- rep(1, length(rows))
  decision <- tryCatch(
    solve_decision(problem, probe_costs, instances[[scenario_id]]),
    dflasso_infeasible = function(condition) NULL,
    error = function(condition) {
      fit_error(sprintf(
        "solve for scenario '%s' failed: %s",
        scenario_id, conditionMessage(condition)
      ), "dflasso_error_solver")
    }
  )
  if (is.null(decision)) {
    return(invisible(NULL))
  }
  check_decision_shape(decision, length(rows), scenario_id)
  invisible(NULL)
}

check_decision_shape <- function(decision, expected, scenario_id) {
  if (!is.numeric(decision) || length(decision) != expected) {
    got <- if (!is.numeric(decision)) {
      sprintf("a %s vector of length %d", class(decision)[[1L]],
              length(decision))
    } else {
      sprintf("a vector of length %d", length(decision))
    }
    fit_error(sprintf(
      paste0(
        "solve for scenario '%s' returned %s; expected %d (one value per ",
        "element row of that instance)."
      ),
      scenario_id, got, expected
    ), "dflasso_error_solver")
  }
  if (any(!is.finite(decision))) {
    fit_error(sprintf(
      paste0(
        "solve for scenario '%s' returned non-finite values; expected a ",
        "finite numeric vector of length %d (one value per element row, in ",
        "row order)."
      ),
      scenario_id, expected
    ), "dflasso_error_solver")
  }
  invisible(NULL)
}

compute_proxy_coverage <- function(problem, instances, inputs, control) {
  ids <- as.character(unique(inputs$scenario))
  observed <- !is.na(inputs$cost)
  per_scenario <- lapply(ids, function(scenario_id) {
    rows <- which(inputs$scenario == scenario_id)
    support <- resolve_support(problem, instances[[scenario_id]], rows)
    support_rows <- rows[support]
    n_support <- length(support_rows)
    n_observed_support <- sum(observed[support_rows])
    list(
      scenario = scenario_id,
      n_elements = length(rows),
      n_solve_set = n_support,
      n_observed = n_observed_support,
      eligible = n_support > 0L && n_observed_support == n_support
    )
  })

  report <- coverage_report(per_scenario)
  eligible_scenarios <- report$scenario[report$eligible]
  n_partial_coverage <- sum(!report$eligible)

  if (length(eligible_scenarios) == 0L) {
    fit_error(
      paste0(
        "No scenario has complete realised costs over its solved elements, ",
        "so decision quality cannot be scored. dflasso needs at least a few ",
        "scenarios where every element the solver looks at has an observed ",
        "cost. See the coverage report for which elements are missing."
      ),
      "dflasso_error_coverage"
    )
  }
  warn_thin_proxy(length(eligible_scenarios), control)

  list(
    report = report,
    eligible_scenarios = eligible_scenarios,
    n_partial_coverage = n_partial_coverage
  )
}

resolve_support <- function(problem, instance, rows) {
  support <- solve_support(problem, instance, costs = rep(1, length(rows)))
  if (is.null(support)) {
    return(seq_along(rows))
  }
  support
}

coverage_report <- function(per_scenario) {
  data.frame(
    scenario = vapply(per_scenario, `[[`, character(1L), "scenario"),
    n_elements = vapply(per_scenario, `[[`, integer(1L), "n_elements"),
    n_solve_set = vapply(per_scenario, `[[`, integer(1L), "n_solve_set"),
    n_observed = vapply(per_scenario, `[[`, integer(1L), "n_observed"),
    eligible = vapply(per_scenario, `[[`, logical(1L), "eligible"),
    stringsAsFactors = FALSE
  )
}

warn_thin_proxy <- function(n_eligible, control) {
  default_n_splits <- formals(dfl_control)$n_splits
  at_default <- isTRUE(control$n_splits == eval(default_n_splits))
  if (n_eligible < 30L && at_default) {
    fit_warning(sprintf(
      paste0(
        "Only %d instances have complete cost data to measure decision ",
        "quality, so the decision-relevance scores will be noisier. Gather ",
        "more fully-covered scenarios, or raise n_splits in dfl_control() to ",
        "average over more resamples. See ?dflasso-troubleshooting."
      ),
      n_eligible
    ))
  }
  invisible(NULL)
}

modelling_rows <- function(inputs, control) {
  keep <- if (is.null(inputs$cost)) {
    rep(TRUE, nrow(inputs$x))
  } else {
    !is.na(inputs$cost)
  }
  scenario <- inputs$scenario[keep]
  sizes <- table(scenario)
  small <- names(sizes)[sizes < control$min_elements_per_scenario]
  if (length(small) > 0L) {
    keep[inputs$scenario %in% small] <- FALSE
  }
  list(
    x = inputs$x[keep, , drop = FALSE],
    cost = if (is.null(inputs$cost)) NULL else inputs$cost[keep],
    scenario = inputs$scenario[keep]
  )
}

make_foldid <- function(scenario, nfolds, seed) {
  ids <- unique(scenario)
  assignment <- with_local_seed(seed, {
    sample(rep_len(seq_len(nfolds), length(ids)))
  })
  fold_of_scenario <- stats::setNames(assignment, ids)
  unname(fold_of_scenario[scenario])
}

compute_adaptive_weights <- function(modelling, foldid, control) {
  ridge <- glmnet::cv.glmnet(
    modelling$x, modelling$cost,
    alpha = 0, foldid = foldid,
    standardize = control$standardize
  )
  beta_ridge <- as.numeric(glmnet::coef.glmnet(ridge, s = "lambda.min"))[-1L]
  weight <- 1 / (abs(beta_ridge)^control$gamma)
  finite_max <- if (any(is.finite(weight))) {
    max(weight[is.finite(weight)])
  } else {
    1
  }
  weight[!is.finite(weight)] <- finite_max
  weight
}

fit_plain_lasso <- function(modelling, foldid, control) {
  glmnet::cv.glmnet(
    modelling$x, modelling$cost,
    alpha = 1, foldid = foldid,
    penalty.factor = rep(1, ncol(modelling$x)),
    standardize = control$standardize
  )
}

fit_adaptive_lasso <- function(modelling, foldid, adaptive_weight, control) {
  glmnet::cv.glmnet(
    modelling$x, modelling$cost,
    alpha = 1, foldid = foldid,
    penalty.factor = adaptive_weight,
    standardize = control$standardize
  )
}

make_proxy_splits <- function(eligible_scenarios, control, seed) {
  n_eligible <- length(eligible_scenarios)
  n_train <- max(1L, min(n_eligible - 1L,
                         round(n_eligible * control$split_fraction)))
  with_local_seed(seed + 1L, {
    lapply(seq_len(control$n_splits), function(split_index) {
      train <- sample(eligible_scenarios, size = n_train)
      list(
        train = train,
        validation = setdiff(eligible_scenarios, train)
      )
    })
  })
}

compute_proxy_score <- function(problem, instances, inputs, modelling,
                                eligible_scenarios, proxy_splits,
                                adaptive_weight, adaptive_fit, control) {
  oracle_value <- oracle_objectives(
    problem, instances, inputs, eligible_scenarios
  )
  scenario_features <- scenario_level_features(inputs, eligible_scenarios)
  working_lambda <- adaptive_fit$lambda.min

  announce_proxy(length(proxy_splits), length(eligible_scenarios), control)
  cluster <- maybe_start_cluster(control)
  on.exit(maybe_stop_cluster(cluster), add = TRUE)

  split_score <- function(split) {
    score_one_split(
      split, problem, instances, inputs, modelling,
      adaptive_weight, working_lambda, oracle_value, scenario_features, control
    )
  }
  per_split <- run_split_loop(proxy_splits, split_score, control)

  announce_done(control)
  stack <- do.call(rbind, per_split)
  colMeans(stack, na.rm = TRUE)
}

run_split_loop <- function(proxy_splits, split_score, control) {
  if (isTRUE(control$parallel)) {
    foreach::foreach(split = proxy_splits) %dorng% split_score(split)
  } else {
    foreach::registerDoSEQ()
    foreach::foreach(split = proxy_splits) %do% split_score(split)
  }
}

score_one_split <- function(split, problem, instances, inputs, modelling,
                            adaptive_weight, working_lambda, oracle_value,
                            scenario_features, control) {
  train_rows <- modelling$scenario %in% split$train
  beta <- split_beta(
    modelling$x[train_rows, , drop = FALSE],
    modelling$cost[train_rows],
    adaptive_weight, working_lambda, control
  )
  regret <- vapply(split$validation, function(scenario_id) {
    scenario_regret(
      problem, instances[[scenario_id]], inputs, scenario_id, beta,
      oracle_value[[scenario_id]]
    )
  }, numeric(1L))
  validation_features <- scenario_features[split$validation, , drop = FALSE]
  as.numeric(column_correlation_abs(validation_features, regret))
}

split_beta <- function(x, cost, adaptive_weight, working_lambda, control) {
  fit <- glmnet::glmnet(
    x, cost,
    alpha = 1, penalty.factor = adaptive_weight,
    standardize = control$standardize
  )
  as.numeric(glmnet::coef.glmnet(fit, s = working_lambda))
}

scenario_regret <- function(problem, instance, inputs, scenario_id, beta,
                            oracle_value) {
  rows <- which(inputs$scenario == scenario_id)
  realized_cost <- inputs$cost[rows]
  features <- cbind(1, inputs$x[rows, , drop = FALSE])
  predicted_cost <- as.numeric(features %*% beta)
  decision_predicted <- tryCatch(
    solve_decision(problem, predicted_cost, instance),
    dflasso_infeasible = function(condition) NULL
  )
  if (is.null(decision_predicted)) {
    return(0)
  }
  predicted_objective <- decision_objective(realized_cost, decision_predicted)
  gap <- if (sense(problem) == "min") {
    predicted_objective - oracle_value
  } else {
    oracle_value - predicted_objective
  }
  max(0, gap)
}

oracle_objectives <- function(problem, instances, inputs, eligible_scenarios) {
  values <- vapply(eligible_scenarios, function(scenario_id) {
    rows <- which(inputs$scenario == scenario_id)
    realized_cost <- inputs$cost[rows]
    decision <- solve_decision(problem, realized_cost, instances[[scenario_id]])
    decision_objective(realized_cost, decision)
  }, numeric(1L))
  stats::setNames(values, eligible_scenarios)
}

decision_objective <- function(realized_cost, decision) {
  sum(realized_cost * decision)
}

scenario_level_features <- function(inputs, eligible_scenarios) {
  aggregated <- vapply(eligible_scenarios, function(scenario_id) {
    rows <- which(inputs$scenario == scenario_id)
    colMeans(inputs$x[rows, , drop = FALSE])
  }, numeric(ncol(inputs$x)))
  matrix_form <- t(aggregated)
  rownames(matrix_form) <- eligible_scenarios
  matrix_form
}

reshape_penalty <- function(adaptive_weight, proxy_score, control) {
  eligibility_threshold <- if (is.null(control$eligibility_threshold)) {
    0
  } else {
    control$eligibility_threshold
  }
  rescaled <- pmin(proxy_score / control$proxy_score_reference, 1)
  discount <- exp(-control$kappa * rescaled)

  weight_gate <- stats::quantile(adaptive_weight, 0.70, names = FALSE)
  gated <- adaptive_weight >= weight_gate &
    adaptive_weight >= eligibility_threshold &
    proxy_score > control$score_floor
  weight <- adaptive_weight
  weight[gated] <- pmin(adaptive_weight[gated], control$w_max * discount[gated])
  weight <- pmin(pmax(weight, control$w_min), control$w_max)

  list(
    penalty_factor = weight,
    eligibility_threshold = eligibility_threshold
  )
}

fit_decision_lasso <- function(modelling, foldid, penalty_factor, control) {
  glmnet::cv.glmnet(
    modelling$x, modelling$cost,
    alpha = 1, foldid = foldid,
    penalty.factor = penalty_factor,
    standardize = control$standardize
  )
}

assemble_fit <- function(decision_fit, adaptive_fit, plain_fit,
                         adaptive_weight, proxy_score, penalty_factor,
                         inputs, coverage, problem, sense, penalty_primary,
                         eligibility_threshold, n_proxy_eligible,
                         n_partial_coverage, splits, seed, control, source,
                         call) {
  primary <- switch(
    penalty_primary,
    decision = decision_fit,
    adaptive = adaptive_fit,
    plain = plain_fit
  )
  new(
    "DecisionFocusedLasso",
    decision_fit = decision_fit,
    adaptive_fit = adaptive_fit,
    plain_fit = plain_fit,
    adaptive_weight = as.numeric(adaptive_weight),
    proxy_score = as.numeric(proxy_score),
    penalty_factor = as.numeric(penalty_factor),
    feature_names = inputs$feature_names,
    features_named = inputs$features_named,
    element_ids = split(inputs$element_id, inputs$scenario),
    coverage = coverage,
    problem = problem,
    sense = sense,
    source = source,
    penalty_primary = penalty_primary,
    lambda_min = primary$lambda.min,
    lambda_1se = primary$lambda.1se,
    eligibility_threshold = eligibility_threshold,
    n_proxy_eligible = as.integer(n_proxy_eligible),
    n_partial_coverage = as.integer(n_partial_coverage),
    splits = splits,
    seed = as.integer(seed),
    standardize = control$standardize,
    control = control,
    call = call
  )
}

validate_supplied_regret <- function(regret, scenario, sense) {
  if (is.null(regret)) {
    fit_error("regret was not supplied.", "dflasso_error_usage")
  }
  ids <- as.character(unique(scenario))
  aligned <- align_scenario_regret(regret, ids)
  guard_regret_values(aligned, sense)
}

guard_regret_values <- function(regret, sense) {
  if (length(unique(regret)) == 1L) {
    fit_error(sprintf(
      paste0(
        "every instance has the same regret (%s), so there is nothing for ",
        "the scores to track; a flat regret cannot rank features. Supply ",
        "regret that varies across instances."
      ),
      format(regret[[1L]])
    ), "dflasso_error_value")
  }
  clamp_negative_regret(regret, sense)
}

align_scenario_regret <- function(regret, ids) {
  if (!is.null(names(regret))) {
    missing_ids <- setdiff(ids, names(regret))
    if (length(missing_ids) > 0L) {
      fit_error(sprintf(
        "regret is missing entries for scenario(s): %s.",
        truncate_ids(missing_ids)
      ), "dflasso_error_alignment")
    }
    return(as.numeric(regret[ids]))
  }
  if (length(regret) != length(ids)) {
    fit_error(
      paste0(
        "regret must be named by scenario id (or a column / data frame keyed ",
        "by the scenario id), so it cannot fall out of line with x; a bare ",
        "positional vector is the row-misalignment trap dflasso refuses."
      ),
      "dflasso_error_alignment"
    )
  }
  as.numeric(regret)
}

clamp_negative_regret <- function(regret, sense) {
  tolerance <- 1e-8
  below <- regret < -tolerance
  if (!any(below)) {
    return(pmax(regret, 0))
  }
  fraction <- mean(below)
  if (fraction > 0.20) {
    fit_error(sprintf(
      paste0(
        "regret had %d negative value(s) (min %s); more than 20%% of regret ",
        "is negative, which usually means a raw signed difference or the ",
        "wrong sense was supplied. Supply regret, not a raw signed ",
        "difference, or fix sense=."
      ),
      sum(below), format(min(regret))
    ), "dflasso_error_value")
  }
  fit_warning(sprintf(
    paste0(
      "regret had %d negative value(s) (min %s); clamped to 0. Regret is how ",
      "much WORSE than best (%s sense), so it cannot be < 0."
    ),
    sum(below), format(min(regret)), sense
  ))
  pmax(regret, 0)
}

score_supplied_regret <- function(inputs, regret) {
  ids <- as.character(unique(inputs$scenario))
  scenario_features <- scenario_level_features(inputs, ids)
  as.numeric(column_correlation_abs(scenario_features, regret))
}

note_supplied_regret <- function() {
  if (isTRUE(getOption("dflasso.quiet"))) {
    return(invisible(NULL))
  }
  message(
    "Using the supplied regret as-is, not regret from a dflasso fit."
  )
  invisible(NULL)
}

announce_proxy <- function(n_splits, n_eligible, control) {
  if (!isTRUE(control$progress)) {
    return(invisible(NULL))
  }
  message(sprintf(
    "Scoring features over %d resamples x %d instances...",
    n_splits, n_eligible
  ))
  invisible(NULL)
}

announce_done <- function(control) {
  if (isTRUE(control$progress)) {
    message("Done.")
  }
  invisible(NULL)
}

maybe_start_cluster <- function(control) {
  if (is.null(control$workers)) {
    return(NULL)
  }
  cluster <- parallel::makeCluster(control$workers)
  doParallel::registerDoParallel(cluster)
  doRNG::registerDoRNG(control$seed)
  cluster
}

maybe_stop_cluster <- function(cluster) {
  if (!is.null(cluster)) {
    parallel::stopCluster(cluster)
    foreach::registerDoSEQ()
  }
  invisible(NULL)
}

resolve_seed <- function(seed) {
  if (!is.null(seed)) {
    return(as.integer(seed))
  }
  as.integer(sample.int(.Machine$integer.max, 1L))
}

with_local_seed <- function(seed, expression) {
  if (exists(".Random.seed", envir = globalenv())) {
    previous <- get(".Random.seed", envir = globalenv())
    on.exit(assign(".Random.seed", previous, envir = globalenv()), add = TRUE)
  } else {
    on.exit(rm_random_seed(), add = TRUE)
  }
  set.seed(as.integer(seed))
  expression
}

rm_random_seed <- function() {
  if (exists(".Random.seed", envir = globalenv())) {
    rm(".Random.seed", envir = globalenv())
  }
}

truncate_ids <- function(ids, limit = 4L) {
  if (length(ids) == 0L) {
    return("none")
  }
  shown <- utils::head(ids, limit)
  quoted <- sprintf("'%s'", shown)
  more <- length(ids) - length(shown)
  if (more > 0L) {
    return(paste0(paste(quoted, collapse = ", "), sprintf(" (+%d more)", more)))
  }
  paste(quoted, collapse = ", ")
}

report_fit_problems <- function(problems) {
  fit_error(report_problems_body(problems), "dflasso_error_dimension")
}

report_problems_body <- function(problems) {
  if (length(problems) == 1L) {
    return(problems[[1L]])
  }
  shown <- utils::head(problems, 8L)
  more <- length(problems) - length(shown)
  body <- paste(sprintf("- %s", shown), collapse = "\n")
  if (more > 0L) {
    body <- paste0(body, sprintf("\n- (+%d more)", more))
  }
  body
}

fit_error <- function(message, class = "dflasso_error_value") {
  stop(structure(
    class = c(class, "dflasso_error", "error", "condition"),
    list(message = message, call = NULL)
  ))
}

fit_warning <- function(message, class = "dflasso_warning_value") {
  warning(structure(
    class = c(class, "dflasso_warning", "warning", "condition"),
    list(message = message, call = NULL)
  ))
}

utils::globalVariables("split")
