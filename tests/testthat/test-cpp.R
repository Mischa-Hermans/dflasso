test_that("knapsack dynamic program solves the classic 220 instance", {
  selected <- dflasso:::knapsack_dynamic_program(
    c(60, 100, 120), c(10L, 20L, 30L), 50L
  )
  expect_identical(selected, c(0L, 1L, 1L))
  expect_equal(sum(c(60, 100, 120) * selected), 220)
})

test_that("knapsack handles zero capacity, single item and all-fit", {
  expect_identical(
    dflasso:::knapsack_dynamic_program(c(5, 3), c(1L, 2L), 0L),
    c(0L, 0L)
  )
  expect_identical(
    dflasso:::knapsack_dynamic_program(5, 2L, 3L),
    1L
  )
  expect_identical(
    dflasso:::knapsack_dynamic_program(5, 4L, 3L),
    0L
  )
  expect_identical(
    dflasso:::knapsack_dynamic_program(c(5, 3), c(1L, 2L), 10L),
    c(1L, 1L)
  )
})

test_that("knapsack rejects mismatched lengths and negative capacity", {
  expect_error(dflasso:::knapsack_dynamic_program(c(1, 2), 1L, 5L))
  expect_error(dflasso:::knapsack_dynamic_program(1, 1L, -1L))
})

test_that("Dijkstra returns the least-cost path as an arc indicator", {
  from <- c(1L, 1L, 2L, 3L)
  to <- c(2L, 3L, 4L, 4L)
  cost <- c(1, 4, 1, 1)
  incidence <- dflasso:::shortest_path_dijkstra(from, to, cost, 4L, 1L, 4L)
  expect_identical(as.integer(incidence), c(1L, 0L, 1L, 0L))
  expect_false(attr(incidence, "unreachable"))
})

test_that("Dijkstra flags an unreachable destination", {
  incidence <- dflasso:::shortest_path_dijkstra(
    c(1L, 1L), c(2L, 3L), c(1, 1), 4L, 1L, 4L
  )
  expect_true(attr(incidence, "unreachable"))
  expect_true(all(incidence == 0L))
})

test_that("Dijkstra rejects negative arc costs and out-of-range nodes", {
  expect_error(
    dflasso:::shortest_path_dijkstra(1L, 2L, -1, 2L, 1L, 2L)
  )
  expect_error(
    dflasso:::shortest_path_dijkstra(1L, 2L, 1, 2L, 1L, 5L)
  )
})

test_that("column_correlation_abs matches base abs(cor) to ~1e-8", {
  set.seed(1)
  features <- matrix(stats::rnorm(60), nrow = 20, ncol = 3)
  response <- stats::rnorm(20)
  scores <- dflasso:::column_correlation_abs(features, response)
  base <- abs(as.numeric(stats::cor(features, response)))
  expect_equal(scores, base, tolerance = 1e-8)
})

test_that("column_correlation_abs returns 0 for a zero-variance column", {
  set.seed(2)
  features <- matrix(stats::rnorm(40), nrow = 20, ncol = 2)
  features[, 2] <- 7
  response <- stats::rnorm(20)
  scores <- dflasso:::column_correlation_abs(features, response)
  expect_equal(scores[[2]], 0)
})

test_that("column_correlation_abs returns 0 for a constant response", {
  features <- matrix(stats::rnorm(20), nrow = 10, ncol = 2)
  scores <- dflasso:::column_correlation_abs(features, rep(3, 10))
  expect_equal(scores, c(0, 0))
})
