#' Simulate a capital-allocation problem
#'
#' Builds an example predict-then-optimize dataset for the capital-allocation
#' problem. Each scenario is one
#' realisation of uncertain asset returns; the optimiser splits a budget across
#' assets. The point of the construction is that some features predict returns
#' well while others barely predict returns yet decide which assets win the
#' allocation, so the decision focus has something to recover.
#'
#' The true return of asset `i` in scenario `s` is
#' `mu + sum_pred beta_pred z_sj + sum_dec beta_dec d_sj + noise`. The
#' prediction-heavy features `z_sj` are scenario-level, shared by every asset,
#' and predict the return strongly. The decision-relevant features `d_sj` are
#' scenario-level draws entering with a small coefficient, so a prediction-tuned
#' lasso under-selects them while the decision-relevance proxy reads their
#' scenario-level signal. The remaining features are noise.
#'
#' @param n_scenarios Number of scenarios, each one optimisation instance.
#' @param n_assets Number of assets per scenario.
#' @param n_features Number of feature columns. The first two are the
#'   decision-relevant features, the next few predict the return, and the rest
#'   are noise. Must be at least three.
#' @param seed Single integer, or `NULL` to draw one at random. The same seed
#'   gives the same data.
#'
#' @return A list with `data` (a data frame: `feat_01` .. `feat_<n_features>`,
#'   `realized_return`, a `scenario` factor with levels `scenario_01` .., and
#'   `asset_id`), plus `x` (the feature matrix), `cost` (the realized returns),
#'   `scenario`, and `element_id` (the asset ids). The
#'   `decision_relevant_features` attribute on `data` records the decision
#'   feature names.
#'
#' @examples
#' sim <- simulate_capital_allocation(8, 6, 6, seed = 1)
#' head(sim$data)
#' attr(sim$data, "decision_relevant_features")
#'
#' @seealso [simulate_knapsack()], [simulate_shortest_path()],
#'   [capital_allocation_problem()]
#' @family dflasso data helpers
#' @export
simulate_capital_allocation <- function(n_scenarios, n_assets, n_features,
                                        seed = NULL) {
  generated <- with_seed(seed, {
    roles <- feature_roles(n_features)
    scenario_signal <- draw_independent_signal(n_scenarios, n_features)
    generate_element_table(
      scenario_signal, roles,
      n_scenarios, n_assets,
      noise_sd = 0.30
    )
  })

  data <- data.frame(
    generated$features,
    realized_return = generated$cost,
    scenario = scenario_factor(generated$scenario_index, n_scenarios),
    asset_id = generated$element_id,
    stringsAsFactors = FALSE
  )
  attr(data, "decision_relevant_features") <- generated$decision_relevant_names

  list(
    data = data,
    x = generated$x,
    cost = generated$cost,
    scenario = data$scenario,
    element_id = data$asset_id
  )
}

#' Simulate a knapsack problem
#'
#' Builds an example predict-then-optimize dataset for the 0/1 knapsack. Each
#' scenario is one realisation of
#' uncertain item values; the optimiser picks items to maximise value under a
#' single capacity. Item weights are fixed random integers across scenarios.
#'
#' The true value of item `i` in scenario `s` follows the same equation as
#' [simulate_capital_allocation()]: prediction-heavy scenario-level features
#' move every item's value together, the two decision-relevant features are
#' scenario-level draws with a small coefficient, and the rest are noise.
#'
#' @inheritParams simulate_capital_allocation
#' @param n_items Number of items per scenario.
#'
#' @return A list with `data` (a data frame: `feat_01` .. `feat_<n_features>`,
#'   `realized_value`, `scenario`, `item_id`, and `weight`), plus `x`, `cost`
#'   (the realized values), `scenario`, `weights` (the per-item weights),
#'   `capacity` (a default budget of half the total item weight, a binding
#'   limit), and `item_id`. Pass the weights and the capacity through
#'   [make_instances()].
#'
#' @examples
#' sim <- simulate_knapsack(6, 8, 5, seed = 1)
#' head(sim$data)
#' instances <- make_instances(
#'   sim$scenario, weights = sim$weights, capacity = sim$capacity
#' )
#'
#' @seealso [simulate_capital_allocation()], [simulate_shortest_path()],
#'   [knapsack_problem()]
#' @family dflasso data helpers
#' @export
simulate_knapsack <- function(n_scenarios, n_items, n_features, seed = NULL) {
  generated <- with_seed(seed, {
    roles <- feature_roles(n_features)
    scenario_signal <- draw_independent_signal(n_scenarios, n_features)
    table <- generate_element_table(
      scenario_signal, roles,
      n_scenarios, n_items,
      noise_sd = 0.30, intercept = 5
    )
    table$item_weight <- rep(sample.int(15L, n_items, replace = TRUE) + 5L,
                             times = n_scenarios)
    table
  })

  data <- data.frame(
    generated$features,
    realized_value = generated$cost,
    scenario = scenario_factor(generated$scenario_index, n_scenarios),
    item_id = generated$element_id,
    weight = generated$item_weight,
    stringsAsFactors = FALSE
  )
  attr(data, "decision_relevant_features") <- generated$decision_relevant_names
  capacity <- knapsack_capacity(generated$item_weight[seq_len(n_items)])

  list(
    data = data,
    x = generated$x,
    cost = generated$cost,
    scenario = data$scenario,
    weights = data$weight,
    capacity = capacity,
    item_id = data$item_id
  )
}

knapsack_capacity <- function(item_weights) {
  as.integer(ceiling(0.5 * sum(item_weights)))
}

#' Simulate a shortest-path routing problem
#'
#' Builds an example single-origin single-destination routing dataset like the
#' `aid_routing` data. Each day is one instance over a connected layered
#' graph; some days close arcs so the route must change. Features are observed
#' per arc per day (the `arc_day_features` panel) because a router sees that
#' day's forecast on each arc before driving. Network-wide `congestion` raises
#' every arc's travel time together and predicts it strongly without changing
#' the route. The two decision-relevant features, `flood_depth` and
#' `mud_depth`, are built per arc per day as `weather_day load_arc` with
#' opposite regional signs, so a wet day tilts north routes against south
#' routes (changing which route is fastest) while each feature carries only a
#' small marginal effect on travel time. The prediction-tuned baseline therefore
#' drops them. Because the day's weather drives both the route tilt and the
#' feature's per-day mean over the graph, the days where ignoring the feature is
#' costly are the days its mean is large, which the decision-relevance proxy
#' detects.
#'
#' The data is built to exercise the package's edge cases: a fixed subset of
#' days has full coverage of its solved arcs, a couple of observed rows fall on
#' closed arcs, and one decide-time day (`2026-08-14`) closes every arc out of
#' the origin, leaving the destination unreachable.
#'
#' @param n_days Number of training days, one instance each.
#' @param n_arcs Approximate number of arcs in the graph. The layered
#'   construction may add a few to keep the graph connected.
#' @param n_nodes Number of nodes. Origin is pinned to node 1, destination to
#'   node 5.
#' @param seed Single integer, or `NULL` to draw one at random. The same seed
#'   gives the same data.
#'
#' @return A list with `arcs` (arc_id, from_node, to_node, `surface`,
#'   `base_time`, the static loadings `flood_load`/`mud_load`, and
#'   `region_sign`), `nodes`, `training_days` (date, origin, destination,
#'   `closed_arc_ids` list-column), `arc_day_features` (date, arc_id, and the
#'   per-arc-per-day feature columns `congestion`, `rainfall`, `flood_depth`,
#'   `mud_depth`, and `noise_01`..`noise_24`), `observed_times` (date, arc_id,
#'   travel_time, ragged with `NA`),
#'   the matching `holdout_days`, `arc_day_features_holdout`,
#'   `observed_times_holdout`, and `tomorrow_days` (decide-time days including the
#'   infeasible `2026-08-14`) with `arc_day_features_tomorrow`.
#'
#' @examples
#' routing <- simulate_shortest_path(n_days = 12, n_arcs = 20, n_nodes = 8, seed = 1)
#' names(routing)
#' head(routing$arc_day_features)
#'
#' @seealso [simulate_capital_allocation()], [simulate_knapsack()],
#'   [shortest_path_problem()]
#' @family dflasso data helpers
#' @export
simulate_shortest_path <- function(n_days, n_arcs, n_nodes, seed = NULL) {
  with_seed(seed, {
    origin <- 1L
    destination <- 5L
    graph <- build_layered_graph(n_nodes, n_arcs, origin, destination)
    arcs <- arc_feature_table(graph)

    base_dates <- as.Date("2026-06-01") + seq_len(n_days) - 1L
    closures <- draw_daily_closures(n_days, arcs, graph)
    training_days <- day_table(base_dates, origin, destination, closures)
    training_panel <- arc_day_panel(training_days, arcs)
    observed_times <- realized_arc_times(
      training_days, arcs, graph, origin, destination,
      coverage_fraction = 0.20, n_forced = forced_coverage_count(n_days),
      panel = training_panel
    )

    holdout_dates <- max(base_dates) + seq_len(holdout_count(n_days))
    holdout_closures <- draw_daily_closures(
      length(holdout_dates), arcs, graph
    )
    holdout_days <- day_table(
      holdout_dates, origin, destination, holdout_closures
    )
    holdout_panel <- arc_day_panel(holdout_days, arcs)
    observed_times_holdout <- realized_arc_times(
      holdout_days, arcs, graph, origin, destination,
      coverage_fraction = 0.25,
      n_forced = forced_coverage_count(length(holdout_dates)),
      panel = holdout_panel
    )

    tomorrow_days <- decide_day_table(arcs, graph, origin, destination)
    tomorrow_panel <- arc_day_panel(tomorrow_days, arcs)

    arc_features <- c("congestion", "rainfall", "flood_depth", "mud_depth",
                      arc_day_noise_names())
    list(
      arcs = arcs,
      nodes = graph$nodes,
      training_days = training_days,
      arc_day_features = training_panel[, c("date", "arc_id", arc_features)],
      observed_times = observed_times,
      holdout_days = holdout_days,
      arc_day_features_holdout =
        holdout_panel[, c("date", "arc_id", arc_features)],
      observed_times_holdout = observed_times_holdout,
      tomorrow_days = tomorrow_days,
      arc_day_features_tomorrow =
        tomorrow_panel[, c("date", "arc_id", arc_features)]
    )
  })
}

feature_roles <- function(n_features) {
  if (n_features < 3L) {
    sim_error(paste0(
      "n_features must be at least 3 to plant decision and prediction ",
      "features."
    ))
  }
  n_decision <- 2L
  n_prediction <- max(1L, min(n_features - n_decision - 1L,
                              ceiling(n_features / 3)))
  decision <- seq_len(n_decision)
  prediction <- n_decision + seq_len(n_prediction)
  noise <- setdiff(seq_len(n_features), c(decision, prediction))
  list(decision = decision, prediction = prediction, noise = noise)
}

draw_independent_signal <- function(n_scenarios, n_features) {
  matrix(
    stats::runif(n_scenarios * n_features, min = -1, max = 1),
    nrow = n_scenarios,
    ncol = n_features
  )
}

generate_element_table <- function(scenario_signal, roles,
                                    n_scenarios, n_elements,
                                    noise_sd, intercept = 0) {
  beta_prediction <- 2.0
  beta_decision <- 0.30

  scenario_index <- rep(seq_len(n_scenarios), each = n_elements)
  element_index <- rep(seq_len(n_elements), times = n_scenarios)
  n_rows <- n_scenarios * n_elements

  features <- scenario_signal[scenario_index, , drop = FALSE]
  colnames(features) <- feature_names(ncol(scenario_signal))

  prediction_contribution <- as.numeric(
    features[, roles$prediction, drop = FALSE] %*%
      rep(beta_prediction, length(roles$prediction))
  )
  decision_contribution <- as.numeric(
    features[, roles$decision, drop = FALSE] %*%
      rep(beta_decision, length(roles$decision))
  )
  cost <- intercept + prediction_contribution + decision_contribution +
    stats::rnorm(n_rows, sd = noise_sd)

  list(
    features = as.data.frame(features),
    x = features,
    cost = cost,
    scenario_index = scenario_index,
    element_id = element_index,
    decision_relevant_names =
      feature_names(ncol(scenario_signal))[roles$decision]
  )
}

feature_names <- function(n_features) {
  sprintf("feat_%02d", seq_len(n_features))
}

scenario_factor <- function(scenario_index, n_scenarios) {
  levels <- sprintf("scenario_%02d", seq_len(n_scenarios))
  factor(levels[scenario_index], levels = levels)
}

build_layered_graph <- function(n_nodes, n_arcs, origin, destination) {
  layers <- assign_node_layers(n_nodes, origin, destination)
  from_node <- integer(0)
  to_node <- integer(0)

  for (tail in seq_len(n_nodes)) {
    candidates <- which(layers == layers[tail] + 1L)
    if (length(candidates) == 0L) {
      next
    }
    n_links <- min(length(candidates), 1L + stats::rbinom(1L, 2L, 0.5))
    heads <- candidates[seq_len(n_links)]
    from_node <- c(from_node, rep(tail, length(heads)))
    to_node <- c(to_node, heads)
  }

  guaranteed <- guaranteed_paths(layers, origin, destination)
  from_node <- c(from_node, guaranteed$from)
  to_node <- c(to_node, guaranteed$to)
  edges <- unique(data.frame(from_node = from_node, to_node = to_node))
  edges <- edges[order(edges$from_node, edges$to_node), , drop = FALSE]

  extra_needed <- max(0L, n_arcs - nrow(edges))
  if (extra_needed > 0L) {
    edges <- add_forward_arcs(edges, layers, extra_needed)
  }

  nodes <- data.frame(
    node_id = seq_len(n_nodes),
    layer = layers,
    region = ifelse(layers <= stats::median(layers), "north", "south"),
    stringsAsFactors = FALSE
  )
  rownames(edges) <- NULL
  list(from = edges$from_node, to = edges$to_node, nodes = nodes,
       layers = layers)
}

assign_node_layers <- function(n_nodes, origin, destination) {
  layers <- integer(n_nodes)
  n_layers <- max(3L, floor(n_nodes / 2))
  middle_nodes <- setdiff(seq_len(n_nodes), c(origin, destination))
  layers[origin] <- 1L
  layers[destination] <- n_layers
  layers[middle_nodes] <- sample(
    rep_len(2:(n_layers - 1L), length(middle_nodes))
  )
  layers
}

guaranteed_paths <- function(layers, origin, destination) {
  ordered_by_layer <- order(layers)
  spine <- ordered_by_layer[!duplicated(layers[ordered_by_layer])]
  spine <- ensure_endpoints(spine, layers, origin, destination)
  from <- spine[-length(spine)]
  to <- spine[-1L]

  alternate <- which(layers == layers[spine[2L]])
  alternate <- setdiff(alternate, spine)
  if (length(alternate) > 0L) {
    detour <- alternate[[1L]]
    from <- c(from, origin, detour)
    to <- c(to, detour, spine[[3L]])
  }
  list(from = as.integer(from), to = as.integer(to))
}

ensure_endpoints <- function(spine, layers, origin, destination) {
  spine <- spine[spine != origin & spine != destination]
  c(origin, spine, destination)
}

add_forward_arcs <- function(edges, layers, extra_needed) {
  forward_pairs <- expand.grid(
    from_node = seq_along(layers),
    to_node = seq_along(layers)
  )
  forward_pairs <- forward_pairs[
    layers[forward_pairs$to_node] == layers[forward_pairs$from_node] + 1L,
    ,
    drop = FALSE
  ]
  key <- function(frame) paste(frame$from_node, frame$to_node, sep = "->")
  available <- forward_pairs[
    !key(forward_pairs) %in% key(edges), , drop = FALSE
  ]
  if (nrow(available) == 0L) {
    return(edges)
  }
  take <- available[seq_len(min(extra_needed, nrow(available))), , drop = FALSE]
  rbind(edges, take)
}

arc_feature_table <- function(graph) {
  n_arcs <- length(graph$from)
  tail_region <- graph$nodes$region[graph$from]
  region_sign <- ifelse(tail_region == "north", 1, -1)

  flood_load <- normalise_unit(stats::runif(n_arcs, 0, 3))
  mud_load <- normalise_unit(stats::runif(n_arcs, 0, 5))
  base_time <- round(8 + stats::runif(n_arcs, 0, 0.4), 2)
  surface <- factor(
    sample(c("paved", "gravel", "dirt"), n_arcs, replace = TRUE),
    levels = c("paved", "gravel", "dirt")
  )

  data.frame(
    arc_id = sprintf("arc_%03d", seq_len(n_arcs)),
    from_node = graph$from,
    to_node = graph$to,
    surface = surface,
    base_time = base_time,
    flood_load = flood_load,
    mud_load = mud_load,
    region_sign = region_sign,
    stringsAsFactors = FALSE
  )
}

normalise_unit <- function(values) {
  span <- range(values)
  if (diff(span) == 0) {
    return(rep(0.5, length(values)))
  }
  (values - span[1L]) / diff(span)
}

draw_daily_closures <- function(n_days, arcs, graph) {
  closable <- closable_arc_ids(arcs, graph)
  lapply(seq_len(n_days), function(day) {
    if (length(closable) == 0L || stats::runif(1L) < 0.4) {
      return(character(0))
    }
    sample(closable, size = 1L)
  })
}

closable_arc_ids <- function(arcs, graph) {
  redundant <- vapply(seq_along(graph$from), function(arc_index) {
    still_reachable_without(arc_index, graph)
  }, logical(1L))
  arcs$arc_id[redundant]
}

still_reachable_without <- function(arc_index, graph) {
  keep <- seq_along(graph$from) != arc_index
  destination_reachable(
    graph$from[keep], graph$to[keep], length(graph$layers), 1L, 5L
  )
}

destination_reachable <- function(from, to, n_nodes, origin, destination) {
  if (length(from) == 0L) {
    return(FALSE)
  }
  incidence <- shortest_path_dijkstra(
    from, to, rep(1, length(from)), n_nodes, origin, destination
  )
  !isTRUE(attr(incidence, "unreachable"))
}

day_table <- function(dates, origin, destination, closures) {
  frame <- data.frame(
    date = dates,
    origin = origin,
    destination = destination,
    stringsAsFactors = FALSE
  )
  frame$closed_arc_ids <- closures
  frame
}

arc_day_noise_names <- function() {
  sprintf("noise_%02d", seq_len(24L))
}

arc_day_panel <- function(day_table, arcs) {
  beta_congestion <- 4.0
  beta_rainfall <- 0.30
  beta_decision <- 0.8
  noise_sd <- 0.20
  n_arcs <- nrow(arcs)
  n_days <- nrow(day_table)
  noise_names <- arc_day_noise_names()

  congestion <- stats::runif(n_days, -1, 1)
  weather_flood <- stats::runif(n_days, -1, 1)
  weather_mud <- stats::runif(n_days, -1, 1)
  rainfall_day <- stats::runif(n_days, -1, 1)

  panels <- lapply(seq_len(n_days), function(day_index) {
    flood_signal <- weather_flood[day_index] * arcs$region_sign *
      arcs$flood_load + stats::rnorm(n_arcs, sd = 0.05)
    mud_signal <- weather_mud[day_index] * (-arcs$region_sign) *
      arcs$mud_load + stats::rnorm(n_arcs, sd = 0.05)
    rainfall <- rainfall_day[day_index] + stats::rnorm(n_arcs, sd = 0.10)
    congestion_arc <- rep(congestion[day_index], n_arcs)

    true_time <- arcs$base_time +
      beta_congestion * congestion_arc +
      beta_rainfall * rainfall +
      beta_decision * (flood_signal + mud_signal) +
      stats::rnorm(n_arcs, sd = noise_sd)
    true_time <- pmax(true_time, 0.5)

    noise <- matrix(
      round(stats::runif(n_arcs * length(noise_names), -1, 1), 4),
      nrow = n_arcs, dimnames = list(NULL, noise_names)
    )
    data.frame(
      date = day_table$date[day_index],
      arc_id = arcs$arc_id,
      congestion = round(congestion_arc, 4),
      rainfall = round(rainfall, 4),
      flood_depth = round(flood_signal, 4),
      mud_depth = round(mud_signal, 4),
      noise,
      true_time = true_time,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, panels)
}

realized_arc_times <- function(day_table, arcs, graph, origin, destination,
                               coverage_fraction, n_forced, panel) {
  by_day <- split(panel, panel$date)
  rows <- lapply(seq_len(nrow(day_table)), function(day_index) {
    day_panel <- by_day[[as.character(day_table$date[day_index])]]
    travel_time <- day_panel$true_time[match(arcs$arc_id, day_panel$arc_id)]

    forced <- day_index <= n_forced
    arc_rows <- choose_observed_arcs(
      arcs, graph, day_table[day_index, ], origin, destination,
      coverage_fraction, forced
    )
    if (length(arc_rows) == 0L) {
      return(NULL)
    }
    data.frame(
      date = day_table$date[day_index],
      arc_id = arcs$arc_id[arc_rows],
      travel_time = round(travel_time[arc_rows], 2),
      stringsAsFactors = FALSE
    )
  })

  observed <- do.call(rbind, rows)
  add_unplaceable_rows(observed, day_table, arcs)
}

choose_observed_arcs <- function(arcs, graph, day_row, origin, destination,
                                 coverage_fraction, forced) {
  closed <- day_row$closed_arc_ids[[1L]]
  open_arc_index <- which(!arcs$arc_id %in% closed)
  if (forced) {
    return(reachable_set_arcs(graph, closed, arcs, origin))
  }
  n_observed <- max(1L, round(length(open_arc_index) * coverage_fraction))
  sort(sample(open_arc_index, size = min(n_observed, length(open_arc_index))))
}

reachable_set_arcs <- function(graph, closed, arcs, origin) {
  open_keep <- !arcs$arc_id %in% closed
  reachable <- reachable_arcs(
    graph$from[open_keep], graph$to[open_keep], length(graph$layers), origin
  )
  which(open_keep)[reachable]
}

add_unplaceable_rows <- function(observed, day_table, arcs) {
  closing_days <- which(lengths(day_table$closed_arc_ids) > 0L)
  if (length(closing_days) == 0L) {
    return(observed)
  }
  unplaceable_days <- utils::head(closing_days, 2L)
  unplaceable <- do.call(rbind, lapply(unplaceable_days, function(day_index) {
    data.frame(
      date = day_table$date[day_index],
      arc_id = day_table$closed_arc_ids[[day_index]][[1L]],
      travel_time = round(stats::runif(1L, 6, 12), 2),
      stringsAsFactors = FALSE
    )
  }))
  rbind(observed, unplaceable)
}

decide_day_table <- function(arcs, graph, origin, destination) {
  detour_arc <- flood_detour_arc(arcs, graph, origin, destination)
  cut_set <- origin_cut_set(graph, origin)
  cut_ids <- arcs$arc_id[cut_set]

  frame <- data.frame(
    date = as.Date(c("2026-08-12", "2026-08-13", "2026-08-14")),
    origin = origin,
    destination = destination,
    stringsAsFactors = FALSE
  )
  frame$closed_arc_ids <- list(detour_arc, character(0), cut_ids)
  frame
}

flood_detour_arc <- function(arcs, graph, origin, destination) {
  costs <- rep(1, length(graph$from))
  incidence <- shortest_path_dijkstra(
    graph$from, graph$to, costs, length(graph$layers), origin, destination
  )
  on_route <- which(as.logical(incidence))
  closable <- on_route[vapply(on_route, function(arc_index) {
    still_reachable_without(arc_index, graph)
  }, logical(1L))]
  if (length(closable) == 0L) {
    return(character(0))
  }
  arcs$arc_id[closable[which.max(arcs$flood_load[closable])]]
}

origin_cut_set <- function(graph, origin) {
  which(graph$from == origin)
}

forced_coverage_count <- function(n_days) {
  max(1L, min(n_days, round(n_days * 0.45)))
}

holdout_count <- function(n_days) {
  max(2L, round(n_days / 2))
}

with_seed <- function(seed, expression) {
  if (is.null(seed)) {
    return(expression)
  }
  if (exists(".Random.seed", envir = globalenv())) {
    previous <- get(".Random.seed", envir = globalenv())
    on.exit(assign(".Random.seed", previous, envir = globalenv()), add = TRUE)
  }
  set.seed(as.integer(seed))
  expression
}

sim_error <- function(message, class = "dflasso_error_value") {
  stop(structure(
    class = c(class, "dflasso_error", "error", "condition"),
    list(message = message, call = NULL)
  ))
}
