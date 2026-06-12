# Frequently asked questions

Common questions and short answers. For definitions see
`?dflasso-glossary`; for trusting a fit see `?dflasso-validation`; for
fixes when something breaks see `?dflasso-troubleshooting`.

## What problems fit dflasso?

The decision is made before the true costs are known, those costs are
estimated from features, and the objective is a sum of cost times
decision over the elements: a route's total time, a basket's total
value, a portfolio's total return. Costs are real numbers on a scale. A
sort, a knapsack, a shortest path, an assignment, or a linear program is
in scope.

One shape is out of scope: an objective that is not linear in the
predicted cost (a variance term, a product of decisions) breaks the
regret check, though
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
will still run whatever `solve` returns.

## Why not target prediction error?

The decision is what gets deployed. Prediction error and decision regret
can diverge, so a lower RMSE need not mean lower regret. Held-out
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
scores the decision itself;
[`predict()`](https://rdrr.io/r/stats/predict.html) is a diagnostic
only.

## Is a solver needed?

To produce decisions, yes.
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
turns predicted costs into a decision by solving, so it needs a solver,
either a built-in
([`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md))
or a custom
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md).

The solver is optional for the feature ranking alone, when regret from a
separate backtest is already available. See the supplied-regret path
below.

## What is the supplied-regret path?

This path suits a model already backtested elsewhere, with per-instance
regret available. A solver's only job at fit time is to compute regret;
once it is supplied, there is nothing to solve. Pass `regret` to
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
for a proxy-weighted model, or use
[`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md)
for the ranking alone. Both read one data frame the way
[`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md)
does.

The supplied regret must be out-of-sample regret from the model being
diagnosed. Scoring features against dflasso's own output is circular,
and in-sample regret reuses the training data. dflasso cannot check
where regret came from, so unsuitable regret gives confident but
meaningless scores with no warning. A reminder prints on every such
call.

A supplied-regret fit has no solver, so
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
on it errors and reports how to attach a solver:
`decide(fit, ..., problem = a_problem)`, with no re-fit.

## Are the scores validated?

This depends on the path. On the solver path the ranking can be tested:
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
re-solves held-out instances on real costs and reports the comparison.
On the supplied-regret path there are no held-out decisions to check
against, so the
[`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md)
ranking is a correlational signal whose direction is unconfirmed. The
usual confound is collinearity: a feature can score high because it
co-moves with a decisive feature, and the proxy cannot separate the two.

## How many scenarios are needed?

Only fully covered instances are scored, so more scenarios than the raw
count suggests. An instance counts toward the decision-quality step only
if every element the solver could inspect has an observed cost. If fully
covered instances drop below about 30, dflasso warns that the scores
will be noisier and the fit still proceeds. The fix is more fully
covered instances.

## Are true costs needed for every element?

No.
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
never reads costs; future decisions compute from features alone.
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
uses every row whose cost is not `NA` to learn the cost model and drops
the rest, without imputing. Separately, the decision-quality step needs
a handful of instances that are complete over their solved elements.
Missing costs are normal for sparsely observed data, where most days are
set aside for that step and counted automatically. Every observed cost
still trains the model.

## Parallel and reproducibility

Set `dfl_control(seed = <integer>)`. A fixed seed makes a fit
reproducible across re-runs, and identical whether the run is sequential
or parallel. The only random step is how instances are resampled to
score features. Turn on parallelism with
`dfl_control(workers = parallel::detectCores() - 1)`; it helps when
instances are many or `solve` is slow.
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
and [`predict()`](https://rdrr.io/r/stats/predict.html) draw no
randomness.

To reproduce an earlier fit, feed its seed back with
`dfl_control(seed = seed(fit))`.

## Why was a feature kept or dropped?

A feature that predicts cost strongly is kept by the ordinary lasso
anyway. A feature that is a weak predictor but tracks decision regret
gets its penalty eased and can be rescued where a prediction-focused fit
would drop it. A feature that is neither is dropped. See `tidy(fit)` for
each feature's `proxy_score`, `penalty_factor`, and `role`.

## See also

[dflasso-glossary](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-glossary.md),
[dflasso-validation](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-validation.md),
[dflasso-troubleshooting](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-troubleshooting.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
