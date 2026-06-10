#' Make decisions on new data
#'
#' Given new feature rows, `decide()` predicts costs and solves each instance
#' to a decision, returning a [DecisionSet-class] to act on. It needs no
#' realised costs.
#'
#' One infeasible instance never aborts the batch: a scenario the solver cannot
#' satisfy comes back with `feasible = FALSE` and a reason, while the others
#' still return their decisions.
#'
#' A fit made from supplied regret has no solver, so `decide()` errors unless a
#' solver is attached with `problem =` (no re-fit needed). Passing `problem =`
#' to a fit that already has one also errors.
#'
#' @param object A [DecisionFocusedLasso-class] object.
#' @param x_new Numeric feature matrix of new rows, columns in the same order
#'   (or with the same names) as the matrix the fit was trained on.
#' @param scenario_new Vector grouping the new rows into instances, one value
#'   per row.
#' @param instances_new Optional named list of per-instance data, one entry per
#'   scenario. `NULL` (default) auto-builds it from `scenario_new` exactly as
#'   [dfl_fit()] does.
#' @param element_id_new Optional per-row element ids, used to name every
#'   decision. `NULL` (default) uses per-scenario row positions.
#' @param problem Optional [OptimizationProblem-class] to attach to a fit made
#'   from supplied regret. `NULL` (default) uses the fit's own solver and errors
#'   if there is none.
#' @param s Penalty strength for the predicted costs: `"lambda.min"` (default),
#'   `"lambda.1se"`, or a numeric lambda.
#' @param ... Unused, present for S4 compatibility.
#'
#' @return A [DecisionSet-class] object, one record per instance. Read it with
#'   `decisions()`, `selected_elements()`, `objectives()`, `is_feasible()`, and
#'   `element_sequence()`; subset it with `feasible()` / `infeasible()`; list the
#'   reasons with `infeasible_reasons()`; and pull a long, join-ready table with
#'   `as_tibble()`.
#'
#' @details
#' Each record carries the per-instance `decision` (named by `element_id`: `0`/`1`
#' for selection and routing, the weight for allocation), `selected_elements`
#' (the chosen ids), `element_sequence` (the ordered ids for graph problems, else
#' `NULL`), `predicted_objective` (`cost_hat' decision`), `feasible`, and a
#' `message` reason when infeasible. An infeasible instance carries a typed empty
#' decision (`numeric(0)`), not a bare `NULL`, so downstream code spots it with
#' `length(decision) == 0L`.
#'
#' @examples
#' sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' picks <- decide(fit, sim$x, sim$scenario, element_id_new = sim$element_id)
#' picks
#' head(as_tibble(picks))
#'
#' @seealso [dfl_fit()], [regret()] to trust-check the decisions,
#'   [DecisionSet-class].
#' @family dflasso workflow
#' @importFrom methods setClass setGeneric setMethod setValidity new is slot
#' @importFrom tibble tibble as_tibble
#' @importFrom stats setNames
#' @include fitted-class.R predict-coef.R
#' @export
setGeneric("decide", function(object, x_new, scenario_new,
                              instances_new = NULL, element_id_new = NULL,
                              problem = NULL, s = "lambda.min", ...) {
  standardGeneric("decide")
})

#' @rdname decide
setMethod(
  "decide",
  "DecisionFocusedLasso",
  function(object, x_new, scenario_new, instances_new = NULL,
           element_id_new = NULL, problem = NULL, s = "lambda.min", ...) {
    solver <- resolve_decide_problem(object, problem)
    matrix_x <- match_new_features(object, x_new, "x_new")
    scenario <- as.character(scenario_new)
    if (length(scenario) != nrow(matrix_x)) {
      decide_error(sprintf(
        paste0(
          "nrow(x_new) (%d) and length(scenario_new) (%d) must be equal, one ",
          "row per element."
        ),
        nrow(matrix_x), length(scenario)
      ), "dflasso_error_dimension")
    }
    element_id <- resolve_element_id(
      element_id_new, scenario_new, nrow(matrix_x)
    )
    ids <- as.character(unique(scenario))
    instances <- resolve_instances(instances_new, scenario_new, solver)

    cost_hat <- as.numeric(
      cbind(1, matrix_x) %*% as.numeric(stage_coef(object, s, NULL))
    )

    records <- lapply(ids, function(scenario_id) {
      decide_one_instance(
        solver, scenario_id, scenario, cost_hat, element_id,
        instances[[scenario_id]]
      )
    })
    new(
      "DecisionSet",
      records = bind_decision_records(records),
      sense = sense(solver),
      s = if (is.numeric(s)) as.character(s) else s
    )
  }
)

resolve_decide_problem <- function(object, problem) {
  has_solver <- !is.null(object@problem)
  if (has_solver && !is.null(problem)) {
    decide_error(
      paste0(
        "this fit already has a solver; decide() uses it, so drop the problem ",
        "argument."
      ),
      "dflasso_error_usage"
    )
  }
  if (!has_solver && is.null(problem)) {
    decide_error(
      paste0(
        "this model was fit from supplied regret and has no solver; to ",
        "produce decisions, attach one: decide(model, x_new, scenario_new, ",
        "instances_new, problem = knapsack_problem())."
      ),
      "dflasso_error_no_solver"
    )
  }
  if (!has_solver) {
    if (!is(problem, "OptimizationProblem")) {
      decide_error(
        paste0(
          "problem must be an OptimizationProblem, as built by the problem ",
          "constructors."
        ),
        "dflasso_error_usage"
      )
    }
    return(problem)
  }
  object@problem
}

decide_one_instance <- function(problem, scenario_id, scenario, cost_hat,
                                element_id, instance) {
  rows <- which(scenario == scenario_id)
  instance_costs <- cost_hat[rows]
  instance_ids <- element_id[rows]
  decision <- tryCatch(
    {
      solved <- solve_decision(problem, instance_costs, instance)
      check_decision_shape(solved, length(rows), scenario_id)
      solved
    },
    dflasso_infeasible = function(condition) {
      structure(list(message = conditionMessage(condition)),
                class = "decide_infeasible")
    },
    dflasso_error_solver = function(condition) {
      structure(list(message = conditionMessage(condition)),
                class = "decide_infeasible")
    },
    error = function(condition) {
      structure(list(message = sprintf(
        "solve failed: %s", conditionMessage(condition)
      )), class = "decide_infeasible")
    }
  )
  if (inherits(decision, "decide_infeasible")) {
    return(infeasible_record(scenario_id, instance_ids, instance_costs,
                             decision$message))
  }
  feasible_record(problem, scenario_id, instance_ids, instance_costs,
                  as.numeric(decision))
}

feasible_record <- function(problem, scenario_id, instance_ids,
                            instance_costs, decision) {
  named_decision <- stats::setNames(decision, instance_ids)
  selected <- instance_ids[decision != 0]
  sequence <- if (is(problem, "ShortestPathProblem")) {
    instance_ids[decision != 0]
  } else {
    NULL
  }
  objective <- sum(instance_costs * decision)
  tibble::tibble(
    scenario = scenario_id,
    decision = list(named_decision),
    selected_elements = list(selected),
    element_sequence = list(sequence),
    element_ids = list(instance_ids),
    predicted_cost = list(instance_costs),
    predicted_objective = objective,
    feasible = TRUE,
    message = NA_character_
  )
}

infeasible_record <- function(scenario_id, instance_ids, instance_costs,
                              message) {
  empty <- stats::setNames(numeric(0), character(0))
  tibble::tibble(
    scenario = scenario_id,
    decision = list(empty),
    selected_elements = list(instance_ids[0L]),
    element_sequence = list(numeric(0)),
    element_ids = list(instance_ids),
    predicted_cost = list(instance_costs),
    predicted_objective = NA_real_,
    feasible = FALSE,
    message = message
  )
}

bind_decision_records <- function(records) {
  do.call(rbind, records)
}


#' A set of decisions from a fitted model
#'
#' The object [decide()] returns. It holds one record per instance: the
#' decision named by element id, the chosen elements, the predicted objective,
#' and whether the instance was feasible (with a reason if not).
#'
#' @slot records A tibble with one row per instance and the list-columns
#'   `decision`, `selected_elements`, `element_sequence`, `element_ids`,
#'   `predicted_cost`, plus `scenario`, `predicted_objective`, `feasible`, and
#'   `message`.
#' @slot sense Character scalar, `"min"` or `"max"`, the objective direction.
#' @slot s Character scalar recording the penalty strength the decisions used.
#'
#' @seealso [decide()], [decisions()], [feasible()], [infeasible_reasons()]
#' @keywords internal
#' @name DecisionSet-class
#' @rdname DecisionSet-class
NULL

#' @rdname DecisionSet-class
setClass(
  "DecisionSet",
  representation(
    records = "ANY",
    sense = "character",
    s = "character"
  )
)

setValidity("DecisionSet", function(object) {
  problems <- character(0)
  records <- object@records
  required <- c(
    "scenario", "decision", "selected_elements", "element_sequence",
    "predicted_objective", "feasible", "message"
  )
  missing_columns <- setdiff(required, names(records))
  if (length(missing_columns) > 0L) {
    problems <- c(problems, sprintf(
      "records is missing column(s): %s",
      paste(missing_columns, collapse = ", ")
    ))
  }
  if ("feasible" %in% names(records) && anyNA(records$feasible)) {
    problems <- c(problems, "feasible must be a non-missing logical")
  }
  if (length(object@sense) != 1L || !object@sense %in% c("min", "max")) {
    problems <- c(problems, "sense must be one of \"min\" or \"max\"")
  }
  if (length(problems) == 0L) TRUE else problems
})

#' @rdname DecisionSet-class
setMethod("show", "DecisionSet", function(object) {
  cat(format_decision_set(object), sep = "\n")
  invisible(object)
})

format_decision_set <- function(object) {
  records <- object@records
  n_instances <- nrow(records)
  n_feasible <- sum(records$feasible)
  n_infeasible <- n_instances - n_feasible
  sense_line <- if (object@sense == "min") {
    "minimise cost"
  } else {
    "maximise value"
  }
  lines <- c(
    sprintf("Decisions for %d instances (dflasso)", n_instances),
    sprintf(
      "  %d reached a decision; %d had no feasible decision.",
      n_feasible, n_infeasible
    ),
    sprintf("  Objective sense: %s.", sense_line)
  )
  feasible_sequences <- records$element_sequence[records$feasible]
  graph_problem <- length(feasible_sequences) > 0L &&
    any(!vapply(feasible_sequences, is.null, logical(1L)))
  lines <- c(lines, "", peek_lines(records, object@sense, graph_problem))
  if (n_infeasible > 0L) {
    lines <- c(lines, "", infeasible_group_lines(records))
  }
  c(lines, "", decision_set_pointer())
}

peek_lines <- function(records, sense, graph_problem) {
  feasible_rows <- which(records$feasible)
  if (length(feasible_rows) == 0L) {
    return("  No instance reached a decision.")
  }
  shown <- utils::head(feasible_rows, 2L)
  header <- "  A look at two:"
  body <- vapply(shown, function(row_index) {
    peek_one(records[row_index, ], sense, graph_problem)
  }, character(1L))
  c(header, body)
}

peek_one <- function(record, sense, graph_problem) {
  scenario_id <- record$scenario
  objective <- record$predicted_objective[[1L]]
  total_word <- if (sense == "min") "cost" else "value"
  if (graph_problem) {
    sequence <- record$element_sequence[[1L]]
    return(sprintf(
      "    %s  -> %d-step path, predicted total %s %s\n                   %s",
      scenario_id, length(sequence), total_word, format_total(objective),
      format_sequence(sequence)
    ))
  }
  selected <- record$selected_elements[[1L]]
  n_elements <- length(record$element_ids[[1L]])
  sprintf(
    "    %s  -> %d of %d chosen: %s   (predicted total %s %s)",
    scenario_id, length(selected), n_elements,
    format_id_list(selected), total_word, format_total(objective)
  )
}

infeasible_group_lines <- function(records) {
  infeasible_rows <- which(!records$feasible)
  shown <- utils::head(infeasible_rows, 6L)
  header <- sprintf("  No feasible decision (%d):", length(infeasible_rows))
  body <- vapply(shown, function(row_index) {
    sprintf("    %s  -> %s", records$scenario[[row_index]],
            records$message[[row_index]])
  }, character(1L))
  more <- length(infeasible_rows) - length(shown)
  if (more > 0L) {
    body <- c(body, sprintf("    (+%d more)", more))
  }
  c(header, body)
}

decision_set_pointer <- function() {
  c(
    paste0(
      "  -> decisions(x) for the full action per instance (named by the ",
      "element ids);"
    ),
    "     as_tibble(x) for one tidy row per (instance, element), join-ready."
  )
}

format_sequence <- function(sequence) {
  if (length(sequence) <= 8L) {
    return(paste(sequence, collapse = " -> "))
  }
  head_ids <- utils::head(sequence, 1L)
  tail_ids <- utils::tail(sequence, 1L)
  sprintf("%s -> ... -> %s (%d steps)", head_ids, tail_ids, length(sequence))
}

format_id_list <- function(ids, limit = 6L) {
  if (length(ids) == 0L) {
    return("none")
  }
  shown <- utils::head(ids, limit)
  more <- length(ids) - length(shown)
  joined <- paste(shown, collapse = ", ")
  if (more > 0L) {
    return(sprintf("%s (+%d more)", joined, more))
  }
  joined
}

format_total <- function(value) {
  if (is.na(value)) {
    return("NA")
  }
  formatC(value, digits = 1L, format = "f")
}


#' Read decisions out of a decision set
#'
#' Accessors for a [DecisionSet-class] object. The list and vector accessors are
#' named by `scenario` id, so `names(which(!is_feasible(set)))` gives the failing
#' scenarios and `sum(objectives(set))` totals without building a tibble.
#'
#' @param object A [DecisionSet-class] object.
#'
#' @return `decisions()`, `selected_elements()`, and `element_sequence()` return
#'   lists named by scenario; each `decisions()` entry is a numeric vector named
#'   by element id. `objectives()` returns a numeric vector named by scenario;
#'   `is_feasible()` returns a logical vector named by scenario.
#'
#' @examples
#' sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' picks <- decide(fit, sim$x, sim$scenario, element_id_new = sim$element_id)
#' decisions(picks)[[1]]
#' is_feasible(picks)
#'
#' @seealso [decide()], [feasible()], [infeasible_reasons()]
#' @name decision-set-accessors
#' @aliases decisions selected_elements objectives is_feasible element_sequence
NULL

#' @rdname decision-set-accessors
#' @export
setGeneric("decisions", function(object) standardGeneric("decisions"))

#' @rdname decision-set-accessors
setMethod("decisions", "DecisionSet", function(object) {
  named_by_scenario(object@records$decision, object@records$scenario)
})

#' @rdname decision-set-accessors
#' @export
setGeneric("selected_elements", function(object) {
  standardGeneric("selected_elements")
})

#' @rdname decision-set-accessors
setMethod("selected_elements", "DecisionSet", function(object) {
  named_by_scenario(object@records$selected_elements, object@records$scenario)
})

#' @rdname decision-set-accessors
#' @export
setGeneric("objectives", function(object) standardGeneric("objectives"))

#' @rdname decision-set-accessors
setMethod("objectives", "DecisionSet", function(object) {
  stats::setNames(object@records$predicted_objective, object@records$scenario)
})

#' @rdname decision-set-accessors
#' @export
setGeneric("is_feasible", function(object) standardGeneric("is_feasible"))

#' @rdname decision-set-accessors
setMethod("is_feasible", "DecisionSet", function(object) {
  stats::setNames(object@records$feasible, object@records$scenario)
})

#' @rdname decision-set-accessors
#' @export
setGeneric("element_sequence", function(object) {
  standardGeneric("element_sequence")
})

#' @rdname decision-set-accessors
setMethod("element_sequence", "DecisionSet", function(object) {
  named_by_scenario(object@records$element_sequence, object@records$scenario)
})

named_by_scenario <- function(values, scenario) {
  stats::setNames(values, scenario)
}


#' Subset a decision set by feasibility
#'
#' `feasible()` and `infeasible()` partition a [DecisionSet-class] into the
#' instances that did and did not reach a decision, each returning a
#' `DecisionSet` of the same shape. `infeasible_reasons()` returns the reasons
#' table for the instances that failed.
#'
#' @param object A [DecisionSet-class] object.
#'
#' @return `feasible()` and `infeasible()` return a [DecisionSet-class] object.
#'   `infeasible_reasons()` returns a tibble with columns `scenario` and
#'   `message`.
#'
#' @seealso [decide()], [is_feasible()]
#' @name decision-set-feasibility
#' @aliases feasible infeasible infeasible_reasons
NULL

#' @rdname decision-set-feasibility
#' @export
setGeneric("feasible", function(object) standardGeneric("feasible"))

#' @rdname decision-set-feasibility
setMethod("feasible", "DecisionSet", function(object) {
  subset_decision_set(object, object@records$feasible)
})

#' @rdname decision-set-feasibility
#' @export
setGeneric("infeasible", function(object) standardGeneric("infeasible"))

#' @rdname decision-set-feasibility
setMethod("infeasible", "DecisionSet", function(object) {
  subset_decision_set(object, !object@records$feasible)
})

#' @rdname decision-set-feasibility
#' @export
setGeneric("infeasible_reasons", function(object) {
  standardGeneric("infeasible_reasons")
})

#' @rdname decision-set-feasibility
setMethod("infeasible_reasons", "DecisionSet", function(object) {
  records <- object@records[!object@records$feasible, , drop = FALSE]
  tibble::tibble(
    scenario = records$scenario,
    message = records$message
  )
})

subset_decision_set <- function(object, keep) {
  new(
    "DecisionSet",
    records = object@records[keep, , drop = FALSE],
    sense = object@sense,
    s = object@s
  )
}


#' Tidy a decision set into a long table
#'
#' Returns one row per (instance, element). `element_id` is a real column, so a
#' `left_join` back onto the original rows matches by id, not by row order.
#'
#' @param x A [DecisionSet-class] object.
#' @param ... Unused, present for method compatibility.
#'
#' @return A tibble with columns `scenario`, `element_id`, `decision`, `chosen`,
#'   `predicted_cost`, `contribution`, `feasible`, and `step`. For an infeasible
#'   instance every element row is kept with `decision`, `chosen`, and
#'   `contribution` set to `NA` and `predicted_cost` still filled.
#'
#' @examples
#' sim <- simulate_capital_allocation(40, 6, 6, seed = 1)
#' fit <- dfl_fit(
#'   sim$x, sim$cost, sim$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = sim$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' picks <- decide(fit, sim$x, sim$scenario, element_id_new = sim$element_id)
#' head(as_tibble(picks))
#'
#' @seealso [decide()], [decisions()]
#' @rdname as_tibble.DecisionSet
#' @importFrom tibble as_tibble
#' @exportS3Method tibble::as_tibble
as_tibble.DecisionSet <- function(x, ...) {
  records <- x@records
  per_instance <- lapply(seq_len(nrow(records)), function(row_index) {
    long_one_instance(records[row_index, ])
  })
  do.call(rbind, per_instance)
}

long_one_instance <- function(record) {
  element_ids <- record$element_ids[[1L]]
  predicted_cost <- record$predicted_cost[[1L]]
  feasible <- record$feasible[[1L]]
  n_elements <- length(element_ids)
  if (!feasible) {
    return(tibble::tibble(
      scenario = rep(record$scenario, n_elements),
      element_id = element_ids,
      decision = rep(NA_real_, n_elements),
      chosen = rep(NA, n_elements),
      predicted_cost = predicted_cost,
      contribution = rep(NA_real_, n_elements),
      feasible = rep(FALSE, n_elements),
      step = rep(NA_integer_, n_elements)
    ))
  }
  decision <- as.numeric(record$decision[[1L]])
  sequence <- record$element_sequence[[1L]]
  step <- step_positions(element_ids, sequence)
  tibble::tibble(
    scenario = rep(record$scenario, n_elements),
    element_id = element_ids,
    decision = decision,
    chosen = decision != 0,
    predicted_cost = predicted_cost,
    contribution = predicted_cost * decision,
    feasible = rep(TRUE, n_elements),
    step = step
  )
}

step_positions <- function(element_ids, sequence) {
  if (is.null(sequence)) {
    return(rep(NA_integer_, length(element_ids)))
  }
  position <- match(element_ids, sequence)
  as.integer(position)
}
