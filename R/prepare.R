#' Turn a routing dataset into rows for `dfl_fit()`
#'
#' Turns a [simulate_shortest_path()]-style routing list (the shape `aid_routing`
#' uses) into the pieces [dfl_fit()], [decide()], and [regret()] consume, one
#' row per arc per day: the per-arc feature matrix `x`, the realised travel-time
#' `cost` (with `NA` where an arc was not driven that day), the `scenario` (the
#' delivery-day id), the `element_id` (the `arc_id`), the per-day `instances`, and
#' a coverage report. It takes arcs, nodes, day panels, and observed times.
#'
#' `which` picks which slice of the dataset to prepare. `"training"` reads
#' `training_days` / `arc_day_features` / `observed_times`; `"holdout"` reads the
#' `*_holdout` fields for the [regret()] test set; `"tomorrow"` reads
#' `tomorrow_days` / `arc_day_features_tomorrow` and has no observed times, so
#' every cost is `NA` (decide time needs no costs).
#'
#' For each day the graph is the arcs minus that day's `closed_arc_ids`, so a
#' closed arc produces no row. Realised cost for a (date, arc) row comes from an
#' inner join against the observed-times panel on `(date, arc_id)`: one matching
#' observation gives that travel time, several give the `aggregate` summary (mean
#' by default), none leaves `cost = NA` (never imputed). Observed rows whose arc
#' was closed that day, or whose `(date, arc_id)` is not a row of the day's graph,
#' cannot be placed; they are dropped, counted, and reported.
#'
#' @section The five pieces of `dataset`:
#' Bring a custom network as a list of these tables:
#' \itemize{
#'   \item `arcs`: one row per directed arc, with `arc_id`, `from_node`,
#'     `to_node`, and any per-arc columns. `arc_id` may be a string or an integer.
#'   \item `nodes`: one row per node, with `node_id`.
#'   \item a day table (`training_days`, `holdout_days`, or `tomorrow_days`): one
#'     row per day, with `date`, `origin`, `destination`, and an optional
#'     `closed_arc_ids` list-column. Origin and destination are read per day from
#'     this table and can be any node, not a fixed pair.
#'   \item a feature panel (`arc_day_features` and its `_holdout` /
#'     `_tomorrow` variants): one row per (date, arc), with `date`, `arc_id`, and
#'     the feature columns. Every column other than `date` and
#'     `arc_id` becomes a feature.
#'   \item an observed-times panel (`observed_times` and its `_holdout` variant):
#'     `date`, `arc_id`, `travel_time`, a row only where a time was observed. The
#'     `"tomorrow"` slice has none.
#' }
#'
#' The `date` column is the day id: any consistent grouping key, a `Date`, an
#' integer day index, or a character label. It is not coerced to a calendar date,
#' so labels such as `"mon"` or `1L` work as well as `"2026-06-01"`. Use the same
#' type across the day table, the feature panel, and the observed-times panel so
#' they join.
#' The output keeps the days in the order the day table gives them.
#' `closed_arc_ids` takes `NA`, an empty `character(0)`/`integer(0)`, or a vector
#' of arc ids on a closure day; omit the column entirely for a network that never
#' closes.
#'
#' @param dataset A routing list shaped like [simulate_shortest_path()]'s return
#'   value. See "The five pieces of `dataset`" for the tables and columns it must
#'   hold; a missing or malformed table stops with a message naming it.
#' @param which Which slice to prepare: `"training"` (default), `"holdout"`, or
#'   `"tomorrow"`. `"tomorrow"` carries no costs.
#' @param aggregate How to combine several observed times on the same (date, arc):
#'   `"mean"` (default), `"median"`, `"min"`, or `"last"`. Recorded in the
#'   coverage report.
#'
#' @return A list with `x` (the numeric feature matrix, one row per arc per day),
#'   `cost` (realised travel times, `NA` where unobserved, `NULL`-free), `scenario`
#'   (the delivery-day id per row), `element_id` (the `arc_id` per row),
#'   `instances` (a named list, one `list(from, to, n_nodes, origin, destination)`
#'   per day), and `coverage` (a `data.frame` of the per-day join report with an
#'   `unplaceable` attribute). Pass the first five straight into [dfl_fit()] /
#'   [decide()] / [regret()].
#'
#' @examples
#' routing <- simulate_shortest_path(n_days = 12, n_arcs = 20, n_nodes = 8, seed = 1)
#' prepared <- prepare_instances(routing, which = "training")
#' dim(prepared$x)
#' prepared$instances[[1]]
#' head(prepared$coverage)
#'
#' # Bring a custom network: build the five tables by hand, no simulator.
#' # A tiny graph 1 -> {2, 3} -> 4, origin 1, destination 4, days as a plain
#' # integer index (any consistent day id works, not just calendar dates).
#' arcs <- data.frame(
#'   arc_id = c("a1", "a2", "a3", "a4"),
#'   from_node = c(1, 2, 1, 3),
#'   to_node = c(2, 4, 3, 4)
#' )
#' nodes <- data.frame(node_id = 1:4)
#' days <- data.frame(date = 1:5, origin = 1, destination = 4)
#' days$closed_arc_ids <- replicate(5, character(0), simplify = FALSE)
#' set.seed(1)
#' features <- do.call(rbind, lapply(1:5, function(day) data.frame(
#'   date = day, arc_id = arcs$arc_id,
#'   forecast_rain = round(runif(4), 2), forecast_flow = round(runif(4), 2)
#' )))
#' observed <- do.call(rbind, lapply(1:5, function(day) data.frame(
#'   date = day, arc_id = arcs$arc_id, travel_time = round(runif(4, 5, 15), 1)
#' )))
#' network <- list(
#'   arcs = arcs, nodes = nodes,
#'   training_days = days, arc_day_features = features, observed_times = observed
#' )
#' own <- prepare_instances(network, which = "training")
#' own$scenario
#' \donttest{
#' fit <- dfl_fit(
#'   own$x, own$cost, own$scenario,
#'   problem = shortest_path_problem(),
#'   instances = own$instances, element_id = own$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L)
#' )
#' fit
#' }
#'
#' @seealso [shortest_path_problem()], [aid_routing], [dfl_fit()], [regret()]
#' @family dflasso data helpers
#' @export
prepare_instances <- function(dataset,
                              which = c("training", "holdout", "tomorrow"),
                              aggregate = c("mean", "median", "min", "last")) {
  which <- match.arg(which)
  aggregate <- match.arg(aggregate)
  validate_routing_dataset(dataset)
  slice <- routing_slice(dataset, which)
  validate_routing_slice(slice, which)

  origin <- as.integer(slice$days$origin)
  destination <- as.integer(slice$days$destination)
  n_nodes <- nrow(dataset$nodes)
  realized <- aggregate_realized_times(slice$realized_times, aggregate)

  per_day <- lapply(seq_len(nrow(slice$days)), function(day_index) {
    build_day_rows(
      slice$days[day_index, , drop = FALSE], dataset$arcs, slice$panel,
      realized, origin[[day_index]], destination[[day_index]], n_nodes
    )
  })

  rows <- do.call(rbind, lapply(per_day, `[[`, "rows"))
  instances <- stats::setNames(
    lapply(per_day, `[[`, "instance"),
    as.character(slice$days$date)
  )
  feature_names <- setdiff(names(slice$panel), c("date", "arc_id"))
  coverage <- build_coverage(per_day, slice$days, realized, aggregate, rows)

  list(
    x = as.matrix(rows[, feature_names, drop = FALSE]),
    cost = rows$.cost,
    scenario = as.character(rows$.scenario),
    element_id = as.character(rows$.element_id),
    instances = instances,
    coverage = coverage
  )
}

routing_slice <- function(dataset, which) {
  fields <- switch(
    which,
    training = c("training_days", "arc_day_features", "observed_times"),
    holdout = c(
      "holdout_days", "arc_day_features_holdout", "observed_times_holdout"
    ),
    tomorrow = c("tomorrow_days", "arc_day_features_tomorrow", NA)
  )
  missing <- fields[!is.na(fields) & !vapply(fields, function(field) {
    !is.null(dataset[[field]])
  }, logical(1L))]
  if (length(missing) > 0L) {
    prepare_error(sprintf(
      paste0(
        "dataset has no '%s' - it is not a simulate_shortest_path()-style ",
        "routing list for which = \"%s\"."
      ),
      missing[[1L]], which
    ), "dflasso_error_usage")
  }
  list(
    days = dataset[[fields[[1L]]]],
    panel = dataset[[fields[[2L]]]],
    realized_times = if (is.na(fields[[3L]])) NULL else dataset[[fields[[3L]]]]
  )
}

validate_routing_dataset <- function(dataset) {
  if (!is.list(dataset) || is.data.frame(dataset)) {
    prepare_error(
      paste0(
        "dataset must be a routing list shaped like simulate_shortest_path() ",
        "returns, with arcs, nodes, and the day tables."
      ),
      "dflasso_error_usage"
    )
  }
  require_table(dataset$arcs, "arcs",
                c("arc_id", "from_node", "to_node"),
                "one row per directed arc")
  require_table(dataset$nodes, "nodes", "node_id", "one row per node")
}

validate_routing_slice <- function(slice, which) {
  day_field <- switch(
    which, training = "training_days", holdout = "holdout_days",
    tomorrow = "tomorrow_days"
  )
  panel_field <- switch(
    which, training = "arc_day_features", holdout = "arc_day_features_holdout",
    tomorrow = "arc_day_features_tomorrow"
  )
  require_table(slice$days, day_field,
                c("date", "origin", "destination"),
                "one row per day, with a closed_arc_ids list-column")
  require_table(slice$panel, panel_field,
                c("date", "arc_id"),
                "one row per (date, arc) with the feature columns")
}

require_table <- function(table, name, columns, shape) {
  if (is.null(table) || !is.data.frame(table) || nrow(table) == 0L) {
    prepare_error(sprintf(
      "dataset$%s is missing or empty; it should be a data frame with %s.",
      name, shape
    ), "dflasso_error_usage")
  }
  absent <- setdiff(columns, names(table))
  if (length(absent) > 0L) {
    prepare_error(sprintf(
      paste0(
        "dataset$%s is missing column(s) %s; it should be a data frame with ",
        "%s."
      ),
      name, paste(sprintf("'%s'", absent), collapse = ", "), shape
    ), "dflasso_error_usage")
  }
  invisible(table)
}

aggregate_realized_times <- function(realized_times, aggregate) {
  if (is.null(realized_times) || nrow(realized_times) == 0L) {
    return(NULL)
  }
  reducer <- switch(
    aggregate,
    mean = function(values) mean(values),
    median = function(values) stats::median(values),
    min = function(values) min(values),
    last = function(values) values[[length(values)]]
  )
  key <- paste(as.character(realized_times$date),
               as.character(realized_times$arc_id), sep = "\r")
  travel_time <- vapply(
    split(realized_times$travel_time, key), reducer, numeric(1L)
  )
  parts <- strsplit(names(travel_time), "\r", fixed = TRUE)
  data.frame(
    date = vapply(parts, `[[`, character(1L), 1L),
    arc_id = vapply(parts, `[[`, character(1L), 2L),
    travel_time = unname(travel_time),
    stringsAsFactors = FALSE
  )
}

build_day_rows <- function(day, arcs, panel, realized, origin, destination,
                           n_nodes) {
  closed <- if (is.null(day$closed_arc_ids)) {
    character(0)
  } else {
    as.character(day$closed_arc_ids[[1L]])
  }
  open <- !as.character(arcs$arc_id) %in% closed
  day_arcs <- arcs[open, , drop = FALSE]
  day_key <- as.character(day$date)

  features <- panel[as.character(panel$date) == day_key, , drop = FALSE]
  feature_rows <- features[
    match(as.character(day_arcs$arc_id), as.character(features$arc_id)), ,
    drop = FALSE
  ]
  feature_rows$.cost <- realized_cost(realized, day_key, day_arcs$arc_id)
  feature_rows$.scenario <- day_key
  feature_rows$.element_id <- as.character(day_arcs$arc_id)

  list(
    rows = feature_rows,
    instance = list(
      from = as.integer(day_arcs$from_node),
      to = as.integer(day_arcs$to_node),
      n_nodes = n_nodes,
      origin = origin,
      destination = destination
    ),
    open_arc_ids = day_arcs$arc_id,
    n_observed = sum(!is.na(feature_rows$.cost))
  )
}

realized_cost <- function(realized, day_key, arc_ids) {
  if (is.null(realized)) {
    return(rep(NA_real_, length(arc_ids)))
  }
  on_day <- realized[as.character(realized$date) == day_key, , drop = FALSE]
  on_day$travel_time[
    match(as.character(arc_ids), as.character(on_day$arc_id))
  ]
}

build_coverage <- function(per_day, days, realized, aggregate, rows) {
  per_scenario <- lapply(seq_len(nrow(days)), function(day_index) {
    day <- per_day[[day_index]]
    instance <- day$instance
    n_elements <- nrow(day$rows)
    support <- reachable_arcs(instance$from, instance$to, instance$n_nodes,
                              instance$origin)
    observed <- !is.na(day$rows$.cost)
    n_solve_set_missing <- sum(!observed[support])
    list(
      scenario = as.character(days$date[[day_index]]),
      n_elements = n_elements,
      n_cost_observed = day$n_observed,
      n_cost_missing = n_elements - day$n_observed,
      n_solve_set = length(support),
      n_solve_set_missing = n_solve_set_missing,
      proxy_eligible = length(support) > 0L && n_solve_set_missing == 0L
    )
  })

  report <- coverage_frame(per_scenario)
  attr(report, "unplaceable") <- unplaceable_rows(per_day, days, realized)
  attr(report, "aggregate") <- aggregate
  report
}

coverage_frame <- function(per_scenario) {
  n_solve_set_missing <- vapply(per_scenario, `[[`, integer(1L),
                                "n_solve_set_missing")
  proxy_eligible <- vapply(per_scenario, `[[`, logical(1L), "proxy_eligible")
  n_solve_set <- vapply(per_scenario, `[[`, integer(1L), "n_solve_set")
  n_elements <- vapply(per_scenario, `[[`, integer(1L), "n_elements")
  n_cost_observed <- vapply(per_scenario, `[[`, integer(1L), "n_cost_observed")
  data.frame(
    scenario = vapply(per_scenario, `[[`, character(1L), "scenario"),
    n_elements = n_elements,
    n_cost_observed = n_cost_observed,
    n_cost_missing = vapply(per_scenario, `[[`, integer(1L), "n_cost_missing"),
    coverage_fraction = ifelse(
      n_elements > 0L, n_cost_observed / n_elements, 0
    ),
    n_solve_set = n_solve_set,
    n_solve_set_missing = n_solve_set_missing,
    proxy_eligible = proxy_eligible,
    set_aside_reason = ifelse(
      proxy_eligible, NA_character_,
      sprintf("%d of %d solve-set elements unobserved", n_solve_set_missing,
              n_solve_set)
    ),
    stringsAsFactors = FALSE
  )
}

unplaceable_rows <- function(per_day, days, realized) {
  if (is.null(realized)) {
    return(realized[0L, , drop = FALSE])
  }
  placeable <- do.call(rbind, lapply(seq_len(nrow(days)), function(day_index) {
    data.frame(
      date = as.character(days$date[[day_index]]),
      arc_id = as.character(per_day[[day_index]]$open_arc_ids),
      stringsAsFactors = FALSE
    )
  }))
  key <- function(date, arc_id) {
    paste(as.character(date), as.character(arc_id), sep = "\r")
  }
  placed <- key(realized$date, realized$arc_id) %in%
    key(placeable$date, placeable$arc_id)
  realized[!placed, , drop = FALSE]
}

prepare_error <- function(message, class = "dflasso_error_value") {
  stop(structure(
    class = c(class, "dflasso_error", "error", "condition"),
    list(message = message, call = NULL)
  ))
}

utils::globalVariables(c(".cost", ".scenario", ".element_id"))
