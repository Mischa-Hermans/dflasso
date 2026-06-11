#' Capital allocation, a budget-split dataset
#'
#' A simulated continuous-allocation problem, a portfolio or budget split. One
#' data frame, one row per (scenario, asset), in the shape [dfl_fit()] takes
#' directly, so it fits in a single `dfl_data` -> `dfl_fit` -> `decide` pass with
#' no instances list and no join. Each scenario is one rebalancing: the optimiser
#' splits a budget across assets to maximise predicted return.
#'
#' Two of the six features, `feat_01` and `feat_02`, are decision-relevant but
#' weak predictors of `realized_return`; the rest range from strong to noise.
#'
#' @format A data frame with 1,350 rows (225 scenarios x 6 assets) and 10
#'   columns:
#' \describe{
#'   \item{feat_01, feat_02}{numeric. The two decision-relevant features.}
#'   \item{feat_03, feat_04, feat_05, feat_06}{numeric. The remaining four
#'     features.}
#'   \item{realized_return}{numeric. The realised return per asset, the cost
#'     column; needed only to fit.}
#'   \item{scenario}{factor. Which rebalancing this asset belongs to, the
#'     instance id, with levels `scenario_01` .. `scenario_225`.}
#'   \item{asset_id}{integer. The per-asset label, carried onto decisions.}
#'   \item{split}{character. `"train"` for the first 150 scenarios, `"test"` for
#'     the held-out 75, so the demo fits on train and checks [regret()] on test.}
#' }
#'
#' @source Simulated by `simulate_capital_allocation(n_scenarios = 225,
#'   n_assets = 6, n_features = 6, seed = 20260601)`, then a `split` column added;
#'   see `data-raw/make_datasets.R`.
#'
#' @examples
#' problem <- capital_allocation_problem(max_weight = 0.5)
#' train <- subset(capital_allocation_demo, split == "train")
#' d <- dfl_data(
#'   train,
#'   features = starts_with("feat_"),
#'   cost = realized_return,
#'   scenario = scenario,
#'   element_id = asset_id
#' )
#' dim(d$x)
#'
#' @seealso [simulate_capital_allocation()], [capital_allocation_problem()],
#'   [dfl_data()], [aid_routing]
#' @family dflasso data helpers
#' @keywords datasets
"capital_allocation_demo"

#' Aid routing, a single-source shortest-path dataset
#'
#' A simulated single-source shortest-path (routing) problem on a small road
#' graph: one origin (node 1), one destination (node 5), per-arc features, and
#' realised travel times. One vehicle and one origin-to-destination path per day,
#' solved by Dijkstra, not a vehicle-routing or TSP instance.
#'
#' A list of graph tables, not element rows. [prepare_instances()] joins them
#' into the pieces [dfl_fit()], [decide()], and [regret()] consume, one row per
#' arc per day; each delivery-day is one instance over the day's graph (the arcs
#' minus that day's closures). `flood_depth` and `mud_depth` are decision-relevant
#' but weak: they predict travel time poorly yet flip which route is fastest on
#' wet days.
#'
#' @format A list with the fields [simulate_shortest_path()] returns:
#' \describe{
#'   \item{arcs}{data frame, one row per directed arc: `arc_id`, `from_node`,
#'     `to_node`, `surface`, `base_time`, and the static loadings `flood_load`,
#'     `mud_load`, `region_sign`.}
#'   \item{nodes}{data frame: `node_id`, `layer`, `region`. Origin is node 1,
#'     destination is node 5.}
#'   \item{training_days}{data frame, one row per delivery-day: `date` (the
#'     scenario id), `origin`, `destination`, and `closed_arc_ids` (a list-column
#'     of arc ids hard-closed that day).}
#'   \item{arc_day_features}{data frame, one row per (date, arc): the feature
#'     columns `congestion`, `rainfall`, `flood_depth`, `mud_depth`, and
#'     `noise_01` .. `noise_24`.}
#'   \item{observed_times}{data frame: `date`, `arc_id`, `travel_time`, a row
#'     only where a time was observed, about half the (date, arc) pairs. A couple
#'     of rows fall on closed arcs, so the coverage report has unplaceable rows.}
#'   \item{holdout_days, arc_day_features_holdout, observed_times_holdout}{the
#'     matching tables for the [regret()] held-out days, disjoint from training.}
#'   \item{tomorrow_days, arc_day_features_tomorrow}{the decide-time days (no
#'     costs), including `2026-08-14`, which closes a cut-set severing every
#'     origin-to-destination path.}
#' }
#'
#' @source Simulated by `simulate_shortest_path(n_days = 250, n_arcs = 30,
#'   n_nodes = 12, seed = 7)`; see `data-raw/make_datasets.R`.
#'
#' @examples
#' \donttest{
#' prep <- prepare_instances(aid_routing, which = "training")
#' fit <- dfl_fit(
#'   prep$x, prep$cost, prep$scenario,
#'   problem = shortest_path_problem(),
#'   instances = prep$instances, element_id = prep$element_id,
#'   control = dfl_control(seed = 1)
#' )
#' fit
#' }
#'
#' @seealso [prepare_instances()], [shortest_path_problem()],
#'   [simulate_shortest_path()], [dfl_fit()], [capital_allocation_demo]
#' @family dflasso data helpers
#' @keywords datasets
"aid_routing"
