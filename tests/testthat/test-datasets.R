test_that("capital_allocation_demo loads with the documented columns", {
  expect_true(is.data.frame(capital_allocation_demo))
  expect_equal(nrow(capital_allocation_demo), 1350L)
  expect_true(all(c(
    "feat_01", "feat_06", "realized_return", "scenario", "asset_id", "split"
  ) %in% names(capital_allocation_demo)))
  expect_s3_class(capital_allocation_demo$scenario, "factor")
  expect_equal(nlevels(capital_allocation_demo$scenario), 225L)
  expect_setequal(unique(capital_allocation_demo$split), c("train", "test"))
})

test_that("aid_routing loads with the documented routing fields", {
  expect_type(aid_routing, "list")
  expect_true(all(c(
    "arcs", "nodes", "training_days", "arc_day_features", "observed_times",
    "holdout_days", "tomorrow_days"
  ) %in% names(aid_routing)))
  expect_true(all(c("arc_id", "from_node", "to_node") %in% names(aid_routing$arcs)))
  expect_true("node_id" %in% names(aid_routing$nodes))
})

test_that("prepare_instances on aid_routing returns the expected pieces", {
  prepared <- prepare_instances(aid_routing, which = "training")
  expect_named(prepared,
               c("x", "cost", "scenario", "element_id", "instances", "coverage"))
  expect_equal(nrow(prepared$x), length(prepared$cost))
  expect_equal(length(prepared$scenario), nrow(prepared$x))
  expect_named(prepared$instances[[1]],
               c("from", "to", "n_nodes", "origin", "destination"))
  expect_true(all(c("proxy_eligible", "n_solve_set") %in% names(prepared$coverage)))
  expect_false(is.null(attr(prepared$coverage, "unplaceable")))
})

test_that("prepare_instances tomorrow slice carries no costs", {
  prepared <- prepare_instances(aid_routing, which = "tomorrow")
  expect_true(all(is.na(prepared$cost)))
})

test_that("prepare_instances rejects a non-routing list", {
  expect_error(
    prepare_instances(list(arcs = data.frame()), which = "training"),
    class = "dflasso_error_usage"
  )
})

hand_network <- function(day_ids = 1:4) {
  arcs <- data.frame(
    arc_id = c("a1", "a2", "a3", "a4"),
    from_node = c(1, 2, 1, 3),
    to_node = c(2, 4, 3, 4),
    stringsAsFactors = FALSE
  )
  nodes <- data.frame(node_id = 1:4)
  days <- data.frame(date = day_ids, origin = 1, destination = 4,
                     stringsAsFactors = FALSE)
  days$closed_arc_ids <- replicate(length(day_ids), character(0),
                                   simplify = FALSE)
  features <- do.call(rbind, lapply(day_ids, function(day) data.frame(
    date = day, arc_id = arcs$arc_id,
    forecast_rain = stats::runif(4), forecast_flow = stats::runif(4),
    stringsAsFactors = FALSE
  )))
  observed <- do.call(rbind, lapply(day_ids, function(day) data.frame(
    date = day, arc_id = arcs$arc_id, travel_time = stats::runif(4, 5, 15),
    stringsAsFactors = FALSE
  )))
  list(arcs = arcs, nodes = nodes, training_days = days,
       arc_day_features = features, observed_times = observed)
}

test_that("prepare_instances accepts an integer day id (not a Date)", {
  set.seed(1)
  prepared <- prepare_instances(hand_network(1:4), which = "training")
  expect_equal(sort(unique(prepared$scenario)), c("1", "2", "3", "4"))
  expect_equal(nrow(prepared$x), 16L)
  expect_false(any(is.na(prepared$cost)))
})

test_that("prepare_instances accepts a character day label (not a Date)", {
  set.seed(1)
  prepared <- prepare_instances(
    hand_network(c("mon", "tue", "wed")), which = "training"
  )
  expect_equal(sort(unique(prepared$scenario)), c("mon", "tue", "wed"))
  expect_named(prepared$instances, c("mon", "tue", "wed"))
})

test_that("prepare_instances keeps the day order it was given", {
  set.seed(1)
  prepared <- prepare_instances(
    hand_network(c("wed", "mon", "tue")), which = "training"
  )
  expect_equal(names(prepared$instances), c("wed", "mon", "tue"))
})

test_that("prepare_instances errors clearly when a required table is missing", {
  network <- hand_network(1:4)
  network$nodes <- NULL
  expect_error(
    prepare_instances(network, which = "training"),
    regexp = "nodes",
    class = "dflasso_error_usage"
  )
})

test_that("prepare_instances names a malformed table's missing column", {
  network <- hand_network(1:4)
  network$arcs$to_node <- NULL
  expect_error(
    prepare_instances(network, which = "training"),
    regexp = "to_node",
    class = "dflasso_error_usage"
  )
})
