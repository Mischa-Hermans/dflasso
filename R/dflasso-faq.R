#' Frequently asked questions
#'
#' @description
#' Common questions and short answers. For definitions see
#' `?dflasso-glossary`; for trusting a fit see `?dflasso-validation`; for fixes
#' when something breaks see `?dflasso-troubleshooting`.
#'
#' @section What problems fit dflasso?:
#' The decision is made before the true costs are known, those costs are
#' estimated from features, and the objective is a sum of cost times decision
#' over the elements: a route's total time, a basket's total value, a
#' portfolio's total return. Costs are real numbers on a scale. A sort, a
#' knapsack, a shortest path, an assignment, or a linear program is in scope.
#'
#' One shape is out of scope: an objective that is not linear in the predicted
#' cost (a variance term, a product of decisions) breaks the regret check, though
#' `decide()` will still run whatever `solve` returns.
#'
#' @section Why not target prediction error?:
#' The decision is what gets deployed. Prediction error and decision regret can
#' diverge, so a lower RMSE need not mean lower regret. Held-out [regret()]
#' scores the decision itself; `predict()` is a diagnostic only.
#'
#' @section Is a solver needed?:
#' To produce decisions, yes. `decide()` turns predicted costs into a decision by
#' solving, so it needs a solver, either a built-in ([knapsack_problem()],
#' [shortest_path_problem()], [capital_allocation_problem()]) or a custom
#' [optimization_problem()].
#'
#' The solver is optional for the feature ranking alone, when regret from a
#' separate backtest is already available. See the supplied-regret path below.
#'
#' @section What is the supplied-regret path?:
#' This path suits a model already backtested elsewhere, with per-instance regret
#' available. A solver's only job at fit time is to compute regret; once it is
#' supplied, there is nothing to solve. Pass `regret` to [dfl_fit()] for a
#' proxy-weighted model, or use [dfl_score()] for the ranking alone. Both read
#' one data frame the way [dfl_data()] does.
#'
#' The supplied regret must be out-of-sample regret from the model being
#' diagnosed. Scoring features against dflasso's own output is circular, and
#' in-sample regret reuses the training data. dflasso cannot check where regret
#' came from, so unsuitable regret gives confident but meaningless scores with no
#' warning. A reminder prints on every such call.
#'
#' A supplied-regret fit has no solver, so `decide()` on it errors and reports
#' how to attach a solver: `decide(fit, ..., problem = a_problem)`, with no
#' re-fit.
#'
#' @section Are the scores validated?:
#' This depends on the path. On the solver path the ranking can be tested:
#' [regret()] re-solves held-out instances on real costs and reports the
#' comparison. On the supplied-regret path there are no held-out decisions to
#' check against, so the [dfl_score()] ranking is a correlational signal whose
#' direction is unconfirmed. The usual confound is collinearity: a feature can
#' score high because it co-moves with a decisive feature, and the proxy cannot
#' separate the two.
#'
#' @section How many scenarios are needed?:
#' Only fully covered instances are scored, so more scenarios than the raw count
#' suggests. An
#' instance counts toward the decision-quality step only if every element the
#' solver could inspect has an observed cost. If fully covered instances drop
#' below about 30, dflasso warns that the scores will be noisier and the fit
#' still proceeds. The fix is more fully covered instances.
#'
#' @section Are true costs needed for every element?:
#' No. `decide()` never reads costs; future decisions compute from features
#' alone. [dfl_fit()] uses every row whose cost is not `NA` to learn the cost
#' model and drops the rest, without imputing. Separately, the decision-quality
#' step needs a handful of instances that are complete over their solved
#' elements. Missing costs are normal for sparsely observed data, where most days
#' are set aside for that step and counted automatically. Every observed cost
#' still trains the model.
#'
#' @section Parallel and reproducibility:
#' Set `dfl_control(seed = <integer>)`. A fixed seed makes a fit reproducible
#' across re-runs, and identical whether the run is sequential or parallel. The only random step is
#' how instances are resampled to score features. Turn on parallelism with
#' `dfl_control(workers = parallel::detectCores() - 1)`; it helps when instances
#' are many or `solve` is slow. `decide()`
#' and `predict()` draw no randomness.
#'
#' To reproduce an earlier fit, feed its seed back with
#' `dfl_control(seed = seed(fit))`.
#'
#' @section Why was a feature kept or dropped?:
#' A feature that predicts cost strongly is kept by the
#' ordinary lasso anyway. A feature that is a weak predictor but tracks decision
#' regret gets its penalty eased and can be rescued where a prediction-focused
#' fit would drop it. A feature that is neither is dropped. See `tidy(fit)` for
#' each feature's `proxy_score`, `penalty_factor`, and `role`.
#'
#' @name dflasso-faq
#' @seealso [dflasso-glossary], [dflasso-validation], [dflasso-troubleshooting],
#'   [dfl_fit()], [regret()]
#' @keywords internal
NULL
