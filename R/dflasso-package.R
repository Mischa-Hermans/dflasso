#' dflasso: a decision-focused lasso for predict-then-optimise
#'
#' @description
#' dflasso predicts costs with a lasso that keeps the features which track
#' decision regret, not prediction accuracy. It then solves the optimisation
#' problem on new data and reports whether that decision focus lowered regret
#' against an ordinary prediction-focused fit.
#'
#' The inputs are one row per decision element (an arc, item, or asset) per
#' scenario, with the element's features and realised cost and a scenario id
#' grouping elements into instances, plus a way to turn predicted costs into a
#' decision, either a built-in solver or a supplied `solve` function. dflasso
#' scores each feature by how strongly it tracks decision regret, eases the
#' penalty on the high scorers, and refits.
#'
#' @section A short example:
#' Fit, decide, and measure regret on `capital_allocation_demo`:
#'
#' ```r
#' library(dflasso)
#' train <- subset(capital_allocation_demo, split == "train")
#' test  <- subset(capital_allocation_demo, split == "test")
#'
#' train_data <- dfl_data(train, features = starts_with("feat_"),
#'                        cost = realized_return, scenario = scenario,
#'                        element_id = asset_id)
#' fit <- dfl_fit(train_data$x, train_data$cost, train_data$scenario,
#'                problem = capital_allocation_problem(max_weight = 0.5),
#'                element_id = train_data$element_id,
#'                control = dfl_control(seed = 1))
#'
#' decisions(decide(fit, train_data$x, train_data$scenario,
#'                  element_id_new = train_data$element_id))[[1]]
#'
#' test_data <- dfl_data(test, features = starts_with("feat_"),
#'                       cost = realized_return, scenario = scenario)
#' regret(fit, test_data$x, test_data$cost, test_data$scenario)
#' ```
#'
#' @section Example datasets:
#' The package ships two datasets. [capital_allocation_demo] is a single
#' table, one row per asset per period. [aid_routing] is a routing problem
#' given as several tables (the arcs, nodes, and daily travel times of a road
#' network), which [prepare_instances()] turns into the element rows the model
#' takes.
#'
#' @section Main functions:
#' \describe{
#'   \item{[dfl_fit()]}{Fit the model. Pass a `problem` to solve, or a `regret`
#'     vector to skip the solver.}
#'   \item{[decide()]}{New instances in, decisions out.}
#'   \item{[regret()]}{Held-out decision quality against the prediction-focused
#'     baseline.}
#'   \item{[proxy_score()] and [dfl_score()]}{Rank features by how strongly they
#'     track regret. `proxy_score()` reads the scores from a fitted model;
#'     `dfl_score()` computes them straight from a supplied regret column,
#'     with no model and no solver.}
#' }
#'
#' @section Topic pages:
#' \describe{
#'   \item{`?dflasso-faq`}{Common questions about the method and its use.}
#'   \item{`?dflasso-glossary`}{Definitions of the terms.}
#'   \item{`?dflasso-solvers`}{Templates for wrapping a custom optimiser.}
#'   \item{`?dflasso-troubleshooting`}{When something goes wrong.}
#'   \item{`?dflasso-validation`}{Deciding whether to trust and deploy a fit.}
#' }
#'
#' @keywords internal
#' @importFrom ggplot2 autoplot
#' @importFrom graphics plot
#' @importFrom rlang .data
#' @importFrom generics tidy glance augment
"_PACKAGE"

utils::globalVariables(c(
  "feat_01", "realized_return", "realized_value", "travel_time",
  "scenario", "asset_id", "item_id", "weight", "arc_id",
  "from_node", "to_node", "culvert_depth", "river_gauge",
  "culvert_load", "river_load", "base_time", "congestion",
  "surface", "rainfall", "date", "origin", "destination",
  "closed_arc_ids", "node_id", "region",
  "element_id", "decision", "chosen", "predicted_cost", "contribution",
  "feasible", "step", "term", "proxy_score", "role", "reading", "message",
  "selected_elements", "element_sequence", "predicted_objective",
  "element_ids", "split",
  "estimate", "adaptive_weight", "penalty_factor", "prediction_relevance",
  "easing", "log_lambda", "model", "regret", "n_selected", "source"
))
