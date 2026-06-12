# Summary of a fitted decision-focused lasso

Turns a
[DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
fit into a one-screen report: how many features were kept for the
decision, which weak but decision-relevant features the method rescued,
what each feature is for, the filtering strength, and the
reproducibility fields. It reports no held-out regret, because that
needs test data; run
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
on a held-out split for that.

## Usage

``` r
# S3 method for class 'DecisionFocusedLasso'
summary(object, ...)

# S3 method for class 'summary.DecisionFocusedLasso'
print(x, ...)
```

## Arguments

- object:

  A
  [DecisionFocusedLasso](https://Mischa-Hermans.github.io/dflasso/reference/DecisionFocusedLasso-class.md)
  object.

- ...:

  Unused, present for method compatibility.

- x:

  A `summary.DecisionFocusedLasso` object.

## Value

An S3 `summary.DecisionFocusedLasso` object carrying the role table, the
rescued feature names, the kept count, coverage and reproducibility
fields, and the resolved settings. Its
[`print()`](https://rdrr.io/r/base/print.html) renders the one-screen
view.

## Details

Each feature is labelled by how it behaves. A feature the accuracy stage
(the ordinary or adaptive lasso) keeps is prediction-relevant. A feature
that stage would drop, yet the decision stage keeps because it tracks
decision regret, is decision-relevant. A feature both stages keep does
both; a feature neither keeps is left out.

## See also

[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
for the held-out comparison,
[`generics::tidy()`](https://generics.r-lib.org/reference/tidy.html) for
every feature and its role.

## Examples

``` r
sim <- simulate_capital_allocation(60, 6, 6, seed = 1)
fit <- dfl_fit(
  sim$x, sim$cost, sim$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = sim$element_id,
  control = dfl_control(seed = 1, n_splits = 5L)
)
summary(fit)
#> Summary of a decision-focused cost model (dflasso)
#> Objective: maximise value over 60 instances scored, 6 features.
#> 
#> FEATURES KEPT
#>   6 of 6 features were kept for the decision.
#>   4 of these are decision-driven rescues, weak at predicting cost on their own, but
#>   they move the decision, so the model kept them:
#>       feat_01, feat_02, feat_05, feat_06
#>   See tidy(fit) for every feature, its coefficient, and its role.
#> 
#> WHAT EACH FEATURE IS FOR  (across all features, by how they behave)
#>   decision-relevant   4    were kept for the decision (rescued by the decision step)
#>   prediction-relevant 2    were kept by the accuracy step (the usual reason)
#>   both                0    do both
#>   neither             0    not used by either model
#>   These roles come from one random reshuffle of the instances, so they can
#>   shift a little under a different seed. Judge a feature by its score in
#>   tidy(fit), not by the bare label.
#> 
#> DOES THE DECISION FOCUS PAY OFF?  (lower regret is better)
#>   Regret = how much worse a decision was than the best possible in
#>   hindsight, averaged over instances.
#>   This needs held-out data. Run regret(fit, x_test, cost_test,
#>   scenario_test) to compare against the prediction-focused model.
#>   See ?dflasso-validation.
#> 
#> HOW HARD FEATURES WERE FILTERED
#>   Filtering strength 0.011, chosen automatically by trying many settings and
#>   keeping the best; smaller keeps more features. (this setting is called
#>   lambda)
#> 
#> REPRODUCIBILITY
#>   Fit with seed 1; re-running with this seed gives bit-identical features,
#>   scores, and decisions. Pass seed = <int> to fix it up front and quote
#>   that number.
#>   Decision quality was averaged over 5 random reshuffles of the instances.
#> 
#> SETTINGS
#>   main  : features put on a common scale, 10-fold cross-validation, instances must have >= 2 elements.
#>   method: n_splits = 5 (rest at defaults).
```
