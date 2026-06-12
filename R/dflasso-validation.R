#' Reading a dflasso result on held-out data
#'
#' @description
#' A guide to reading a fitted model's results on a held-out test set the model
#' never saw, prepared the same way as training. It covers five things to look
#' at, each with a call that already exists.
#'
#' The five sections below are for the solver path, where [regret()] re-solves
#' held-out instances on real costs. On the supplied-regret path there are no
#' held-out decisions to score against, so the [dfl_score()] ranking is an
#' association that cannot be back-tested; read it as a lead, not a result.
#'
#' @section With only one dataset:
#' Split it by whole instances, never by single rows. An instance must sit
#' entirely in train or entirely in test, or the complete-coverage scoring rule
#' breaks. Choose a subset of `unique(scenario)` for test, for example `test_ids
#' <- sample(unique(scenario), 0.25 * length(unique(scenario)))`, fit on the rows
#' whose `scenario` is not in `test_ids`, then call [regret()] on the rows whose
#' `scenario` is. A later time window works the same way: hold out whole days,
#' not rows within them.
#'
#' @section Step 1, held-out regret:
#' Held-out regret against the prediction-focused baseline.
#'
#' ```r
#' result <- regret(model, x_test, cost_test, scenario_test,
#'                 instances_test, element_id_test = ids_test,
#'                 baseline = "adaptive")
#' result
#' ```
#'
#' The print reads "cut regret by X%" when the decision-focused line sits below
#' the prediction-focused one, or "RAISED regret ... it lost here" when it does
#' not. A loss is a valid stopping point. Whether a thin gap means anything is
#' left to Steps 2 and 5; this step on its own cannot separate a small gap from
#' noise.
#'
#' @section Step 2, the per-instance spread:
#' What sits behind the average.
#'
#' ```r
#' plot(result)
#' ```
#'
#' A broad gain shows as the decision-focused cloud sitting left of the
#' prediction-focused one across the bulk of instances, with its mean diamond to
#' the left. Less reassuring: the two clouds overlapping heavily, or the
#' decision-focused side carrying a few very high-regret instances behind a better
#' average. A few bad instances can outweigh a better mean, and this plot is where
#' they surface.
#'
#' @section Step 3, the rescued features:
#' Which features were rescued, and how strong their scores are. The scores
#' measure association.
#'
#' ```r
#' plot(model, type = "roles")
#' subset(tidy(model), role == "decision-relevant")
#' ```
#'
#' A strong result has rescued features with `proxy_score` clearly off the
#' floor. A weaker one has rescues that are noise columns, or every score barely
#' above the floor. Read the y-axis as labelled; the score tracks how a feature
#' moves with decision regret.
#'
#' Collinearity is worth keeping in mind. A feature can score high because it is
#' correlated with a genuinely decisive feature; the proxy sees the shared
#' movement and cannot separate the two, so a high score marks a lead to check
#' rather than a settled one.
#'
#' @section Step 4, stability across seeds:
#' One different seed.
#'
#' ```r
#' m2 <- dfl_fit(x, cost, scenario, problem = problem,
#'               control = dfl_control(seed = 99))
#' cor(proxy_score(model), proxy_score(m2), use = "complete.obs")
#' regret(m2, x_test, cost_test, scenario_test, instances_test,
#'        element_id_test = ids_test, baseline = "adaptive")
#' ```
#'
#' Two kinds of stability differ here. A role-label flip across seeds is
#' tolerable: a feature near a threshold changes bucket, which is expected, so
#' judge it by the `proxy_score` ranking rather than the bare label. The regret
#' sign flipping matters more: if "cut regret" becomes "RAISED regret" on another
#' seed, the gain does not hold up across seeds. Pass the same `instances_test`
#' and `element_id_test` as Step 1, because the `NULL` auto-build errors on
#' problems that need per-instance data. Two seeds is a rough check and falls well
#' short of a formal estimator.
#'
#' @section Step 5, how many instances were scored:
#' The counts behind the comparison.
#'
#' ```r
#' result$n_proxy_eligible   # fully covered held-out instances scored
#' result$n_instances        # total held-out instances
#' result$n_partial_coverage # set aside for missing costs
#' ```
#'
#' The "Measured on N of M" line reports the count of fully covered held-out
#' instances; a larger N gives a steadier estimate. A handful means the figure
#' rests on little; widen the held-out window or reconstruct fuller per-element
#' costs. Even a comfortable N is one noisy draw.
#'
#' @section What "meaningfully lower" means:
#' There is no p-value, confidence interval, or standard error on the regret gap,
#' by design. What is on screen is the only available measure. A reduction reads
#' as meaningful when it is large relative to the per-instance spread from
#' `plot(result)` (Step 2) and it holds its sign across a couple of seeds (Step
#' 4). A hair-thin gap that sits inside the spread carries little weight, however
#' large the percentage reads. There is no fixed threshold to clear; the spread
#' and the second seed are what there is to judge it by.
#'
#' One held-out set's regret percentage is itself one noisy sample. A 19% gap on
#' one set of about 24 instances gives a rough indication and should not be read
#' as an exact figure. Quote the direction and rough size rather than the precise
#' percent. Where possible, corroborate on a second disjoint split or a later time
#' window; agreement in direction across two splits carries more weight than the
#' exact number on one.
#'
#' @section Reading the four checks together:
#' A consistent result reads the same across them: held-out [regret()] lower
#' relative to the spread, the sign holding across a couple of seeds, rescued
#' features with scores off the floor, and a count of scored instances that is
#' not tiny. A training-data number, a single seed, or a hair-thin gap inside the
#' spread is a thin basis to read much into.
#'
#' Some results read the other way, and each is a normal output. A held-out
#' regret that did not drop is one the package is built to report; the
#' prediction-focused model is the one that scored better here. Where the in-fit
#' preview looked good but held-out did not, the held-out number is the measured
#' one. Where a single seed looked good but the regret sign flipped, the result
#' did not hold across seeds. A gain on a handful of instances, or on one split,
#' is a lead to confirm on more.
#'
#' @section Why regret, and why held-out:
#' Regret measures the decision that gets deployed. How accurately the model
#' predicts costs is a separate thing, and a model can predict a little worse on
#' average yet decide better. `predict()` is a
#' diagnostic: a better RMSE is not a reason to adopt and a slightly worse one is
#' not a reason to reject. The in-fit preview from `glance()` or `summary()` is
#' computed over training resamples and can disagree with held-out [regret()];
#' where they differ, the held-out figure is the one measured on data the model
#' never saw.
#'
#' @examples
#' \donttest{
#' train <- simulate_capital_allocation(60, 6, 6, seed = 1)
#' test  <- simulate_capital_allocation(30, 6, 6, seed = 2)
#' model <- dfl_fit(
#'   train$x, train$cost, train$scenario,
#'   problem = capital_allocation_problem(max_weight = 0.5),
#'   element_id = train$element_id,
#'   control = dfl_control(seed = 1, n_splits = 5L))
#'
#' result <- regret(model, test$x, test$cost, test$scenario,
#'                 baseline = "adaptive")
#' result                      # Step 1: the comparison
#' result$n_proxy_eligible      # Step 5: how many instances scored
#' }
#'
#' @name dflasso-validation
#' @seealso [regret()], [dfl_fit()], [dflasso-troubleshooting], [dflasso-faq]
#' @keywords internal
NULL
