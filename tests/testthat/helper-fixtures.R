small_control <- function(...) {
  dfl_control(n_splits = 3L, seed = 1L, progress = FALSE, ...)
}

quiet_fit <- function(...) {
  suppressMessages(suppressWarnings(dfl_fit(...)))
}

capital_fixture <- function(n_scenarios = 12, n_assets = 5, n_features = 6,
                            seed = 1) {
  simulate_capital_allocation(n_scenarios, n_assets, n_features, seed = seed)
}

knapsack_fixture <- function(n_scenarios = 10, n_items = 6, n_features = 5,
                             seed = 1, capacity = 50) {
  simulation <- simulate_knapsack(n_scenarios, n_items, n_features, seed = seed)
  simulation$instances <- make_instances(
    simulation$scenario,
    weights = simulation$weights,
    capacity = capacity
  )
  simulation
}

routing_fixture <- function(n_days = 14, n_arcs = 18, n_nodes = 8, seed = 1) {
  simulate_shortest_path(n_days, n_arcs, n_nodes, seed = seed)
}

capital_fit <- function(simulation = capital_fixture(), max_weight = 0.5) {
  quiet_fit(
    simulation$x, simulation$cost, simulation$scenario,
    problem = capital_allocation_problem(max_weight = max_weight),
    element_id = simulation$element_id,
    control = small_control()
  )
}

named_regret <- function(scenario, seed = 1) {
  ids <- as.character(unique(scenario))
  withr_seed <- function(value, code) {
    old <- if (exists(".Random.seed", envir = globalenv())) {
      get(".Random.seed", envir = globalenv())
    } else {
      NULL
    }
    set.seed(value)
    on.exit(
      if (!is.null(old)) assign(".Random.seed", old, envir = globalenv())
    )
    code
  }
  values <- withr_seed(seed, stats::runif(length(ids), 0, 5))
  stats::setNames(values, ids)
}
