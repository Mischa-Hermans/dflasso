make_frame <- function() {
  data.frame(
    feat_a = c(1, 2, 3, 4),
    feat_b = c(5, 6, 7, 8),
    surface = factor(c("paved", "dirt", "paved", "dirt")),
    realized = c(10, 20, 30, 40),
    day = rep(c("d1", "d2"), each = 2),
    arc = c("a1", "a2", "a1", "a2"),
    stringsAsFactors = FALSE
  )
}

test_that("dfl_data slices every piece from the same rows via tidyselect", {
  frame <- make_frame()
  prepared <- dfl_data(
    frame,
    features = starts_with("feat_"), cost = realized,
    scenario = day, element_id = arc
  )
  expect_equal(colnames(prepared$x), c("feat_a", "feat_b"))
  expect_equal(prepared$cost, c(10, 20, 30, 40))
  expect_equal(prepared$scenario, frame$day)
  expect_equal(prepared$element_id, frame$arc)
  expect_equal(prepared$sense, "min")
})

test_that("dfl_data dummy-expands factor feature columns", {
  prepared <- dfl_data(
    make_frame(),
    features = c("feat_a", "surface"), cost = realized, scenario = day
  )
  expect_true(is.numeric(prepared$x))
  expect_true(all(c("surfacepaved", "surfacedirt") %in% colnames(prepared$x)))
})

test_that("dfl_data leaves cost NULL when not named", {
  prepared <- dfl_data(make_frame(), features = "feat_a", scenario = day)
  expect_null(prepared$cost)
})

test_that("positional dfl_data(df, feats, cost, scenario) still works", {
  prepared <- dfl_data(make_frame(), "feat_a", realized, day)
  expect_equal(prepared$cost, c(10, 20, 30, 40))
})

test_that("dfl_data errors on a missing column and on empty data", {
  expect_error(
    dfl_data(make_frame(), features = "feat_a", cost = nope, scenario = day),
    class = "dflasso_error_value"
  )
  expect_error(
    dfl_data(make_frame()[0, ], features = "feat_a", scenario = day),
    "no rows"
  )
  expect_error(
    dfl_data(make_frame(), features = starts_with("zzz"), scenario = day),
    "no columns"
  )
})

test_that("dfl_data rejects a high-cardinality text feature naming column and count", {
  n_rows <- 120L
  frame <- data.frame(
    feat_a = rnorm(n_rows),
    record_id = sprintf("rec_%04d", seq_len(n_rows)),
    realized = rnorm(n_rows),
    day = rep(c("d1", "d2"), each = n_rows / 2L),
    stringsAsFactors = FALSE
  )
  error <- tryCatch(
    dfl_data(
      frame,
      features = c("feat_a", "record_id"),
      cost = realized, scenario = day
    ),
    error = function(condition) condition
  )
  expect_s3_class(error, "dflasso_error_value")
  expect_match(conditionMessage(error), "record_id")
  expect_match(conditionMessage(error), "120 distinct")
})

test_that("make_instances slices length-nrow args and recycles scalars", {
  scenario <- rep(c("a", "b"), each = 3)
  instances <- make_instances(scenario, weights = 1:6, capacity = 50)
  expect_named(instances, c("a", "b"))
  expect_equal(instances$a$weights, 1:3)
  expect_equal(instances$b$weights, 4:6)
  expect_equal(instances$a$capacity, 50)
  expect_equal(instances$b$capacity, 50)
})

test_that("make_instances places one value per scenario from a list", {
  scenario <- rep(c("a", "b"), each = 2)
  instances <- make_instances(scenario, size = list(3, 5))
  expect_equal(instances$a$size, 3)
  expect_equal(instances$b$size, 5)
})

test_that("make_instances errors on the slice/place ambiguity", {
  scenario <- c("a", "b", "c")
  expect_error(
    make_instances(scenario, value = c(1, 2, 3)),
    class = "dflasso_error_alignment"
  )
  expect_equal(make_instances(scenario, value = I(c(1, 2, 3)))$a$value, 1)
  expect_equal(make_instances(scenario, value = list(1, 2, 3))$b$value, 2)
})

test_that("make_instances errors when a length matches nothing", {
  scenario <- rep(c("a", "b"), each = 2)
  expect_error(
    make_instances(scenario, value = c(1, 2, 3)),
    class = "dflasso_error_alignment"
  )
})

test_that("make_instances demands named arguments", {
  expect_error(make_instances(c("a", "b"), 1:2), "must be named")
})
