planted_score_frame <- function() {
  set.seed(1)
  scenario <- rep(sprintf("s%02d", 1:12), each = 3)
  scenario_regret <- stats::runif(12, 0, 8)
  tracking <- scenario_regret[match(scenario, sprintf("s%02d", 1:12))]
  data.frame(
    feat_signal = tracking + stats::rnorm(36, sd = 0.05),
    feat_noise_a = stats::rnorm(36),
    feat_noise_b = stats::rnorm(36),
    scenario = scenario,
    regret = tracking,
    stringsAsFactors = FALSE
  )
}

test_that("dfl_score ranks the planted feature top and returns the columns", {
  scored <- suppressMessages(dfl_score(
    planted_score_frame(),
    features = starts_with("feat_"), scenario = scenario, regret = regret
  ))
  expect_s3_class(scored, "dfl_score")
  expect_named(scored, c("rank", "term", "proxy_score", "role", "reading"))
  expect_equal(scored$term[[1]], "feat_signal")
  expect_equal(scored$rank, seq_len(nrow(scored)))
})

test_that("dfl_score role is an ordered factor with two levels", {
  scored <- suppressMessages(dfl_score(
    planted_score_frame(),
    features = starts_with("feat_"), scenario = scenario, regret = regret
  ))
  expect_s3_class(scored$role, "factor")
  expect_true(is.ordered(scored$role))
  expect_equal(levels(scored$role), c("decision-relevant", "neither"))
})

test_that("dfl_score is sorted by descending score", {
  scored <- suppressMessages(dfl_score(
    planted_score_frame(),
    features = starts_with("feat_"), scenario = scenario, regret = regret
  ))
  expect_equal(scored$proxy_score, sort(scored$proxy_score, decreasing = TRUE))
})

test_that("the data-frame and named-vector forms agree", {
  frame <- planted_score_frame()
  from_frame <- suppressMessages(dfl_score(
    frame, features = starts_with("feat_"), scenario = scenario, regret = regret
  ))
  features <- as.matrix(frame[, c("feat_signal", "feat_noise_a", "feat_noise_b")])
  regret_named <- tapply(frame$regret, frame$scenario, unique)
  from_vector <- suppressMessages(dfl_score(
    features, scenario = frame$scenario, regret = regret_named
  ))
  expect_equal(from_frame$proxy_score, from_vector$proxy_score)
})

test_that("a bare positional regret vector is rejected, I() opts out", {
  frame <- planted_score_frame()
  features <- as.matrix(frame[, c("feat_signal", "feat_noise_a", "feat_noise_b")])
  regret_named <- tapply(frame$regret, frame$scenario, unique)
  expect_error(
    suppressMessages(dfl_score(features, scenario = frame$scenario,
                               regret = unname(regret_named))),
    class = "dflasso_error_alignment"
  )
  opted_out <- suppressMessages(dfl_score(
    features, scenario = frame$scenario, regret = I(unname(regret_named))
  ))
  expect_s3_class(opted_out, "dfl_score")
})

test_that("dfl_score errors on a regret that varies within a scenario", {
  frame <- planted_score_frame()
  frame$regret[1] <- frame$regret[1] + 99
  expect_error(
    suppressMessages(dfl_score(
      frame, features = starts_with("feat_"), scenario = scenario,
      regret = regret
    )),
    class = "dflasso_error_value"
  )
})

test_that("dfl_score errors on constant regret, like dfl_fit", {
  frame <- planted_score_frame()
  frame$regret <- 5
  expect_error(
    suppressMessages(dfl_score(
      frame, features = starts_with("feat_"), scenario = scenario,
      regret = regret
    )),
    class = "dflasso_error_value"
  )
})

test_that("dfl_score warns then clamps a few negative regret values", {
  frame <- planted_score_frame()
  one_scenario <- frame$scenario == "s01"
  frame$regret[one_scenario] <- -0.3
  expect_warning(
    scored <- suppressMessages(dfl_score(
      frame, features = starts_with("feat_"), scenario = scenario,
      regret = regret
    )),
    class = "dflasso_warning_value"
  )
  expect_s3_class(scored, "dfl_score")
})

test_that("dfl_score errors when most regret is negative", {
  frame <- planted_score_frame()
  ids <- unique(frame$scenario)
  negative_ids <- ids[seq_len(round(length(ids) * 0.5))]
  frame$regret[frame$scenario %in% negative_ids] <-
    -abs(frame$regret[frame$scenario %in% negative_ids]) - 1
  expect_error(
    suppressWarnings(suppressMessages(dfl_score(
      frame, features = starts_with("feat_"), scenario = scenario,
      regret = regret
    ))),
    class = "dflasso_error_value"
  )
})

test_that("dfl_score and dfl_fit guard supplied regret the same way", {
  frame <- planted_score_frame()
  frame$cost <- frame$regret + stats::rnorm(nrow(frame), sd = 0.1)
  flat <- frame
  flat$regret <- 5
  features <- as.matrix(frame[, c("feat_signal", "feat_noise_a", "feat_noise_b")])
  regret_named <- tapply(flat$regret, flat$scenario, unique)
  expect_error(
    suppressMessages(dfl_score(
      features, scenario = flat$scenario, regret = regret_named
    )),
    class = "dflasso_error_value"
  )
  expect_error(
    suppressMessages(dfl_fit(
      features, cost = flat$cost, scenario = flat$scenario,
      regret = regret_named, control = small_control()
    )),
    class = "dflasso_error_value"
  )
})

test_that("dfl_score prints the ranking and the heuristic footer", {
  scored <- suppressMessages(dfl_score(
    planted_score_frame(),
    features = starts_with("feat_"), scenario = scenario, regret = regret
  ))
  rendered <- paste(dflasso:::format_dfl_score(scored), collapse = "\n")
  expect_match(rendered, "Heuristic, not a validated result", fixed = TRUE)
  expect_match(rendered, "decide() needs a solver", fixed = TRUE)
})
