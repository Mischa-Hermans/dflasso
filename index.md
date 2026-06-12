# dflasso

Feature selection for predict-then-optimise problems that keeps the
features that change the decision.

## What it does

In a predict-then-optimise problem the decision is made before the true
costs are known. Costs are estimated from features, then optimised over.
Take splitting a budget across assets, where the weights are set before
the returns are known: a feature can shift where the money goes while
barely improving the return forecast. The same idea fits any
predict-then-optimise problem, such as shortest path, knapsack,
allocation, or assignment, with a custom solver for anything else.

The feature that predicts cost best and the feature that changes the
chosen decision are often different ones, and dflasso keeps the second
kind. An ordinary lasso ranks features by how well they predict cost.
dflasso ranks them by how much they change the decision, eases the
penalty on the ones that move the decision most, and refits. It then
solves the problem on held-out data and compares its regret with a
prediction-focused model’s.

The default plot places every feature by how well it predicts cost
(horizontal axis) and how much it changes the decision (vertical axis).
Features top-left are weak predictors that still move the allocation; an
ordinary lasso drops these, and the plot marks the ones dflasso keeps as
rescued. Strong predictors that leave the decision unchanged sit
bottom-right.

![Features plotted by how well they predict cost (horizontal) and how
much they change the decision (vertical); two weak predictors sit at the
upper left and are kept, two strong predictors sit at the lower right,
and two further features sit at the lower left and are left
out.](reference/figures/README-hero-1.png)

## How it works

Show the steps

1.  Fit a lasso cost model on the training instances.
2.  Score each feature by how strongly its values track the
    out-of-sample regret.
3.  Ease the penalty on the features that move the decision most.
4.  Refit the cost model under the eased penalties.
5.  Solve each held-out instance with the new predicted costs.
6.  Score regret against a prediction-focused baseline on the same
    instances.

## Installation

dflasso is not on CRAN. Install the development version from GitHub:

``` r

pak::pak("Mischa-Hermans/dflasso")
```

Or, with remotes:

``` r

remotes::install_github("Mischa-Hermans/dflasso")
```

The Docker image includes dflasso and its dependencies; no R setup is
needed:

``` bash
docker pull mischahermans/dflasso:0.1.0
docker run --rm -it mischahermans/dflasso:0.1.0 R
```

Installing from source compiles C++, so build tools are needed: Rtools
on Windows, the Xcode command-line tools on macOS, build-essential on
Linux. Check it with
[`pkgbuild::check_build_tools()`](https://pkgbuild.r-lib.org/reference/has_build_tools.html).

## Quick start

`capital_allocation_demo` splits a budget across assets. It is a single
data frame with one row per asset, so the example runs without
reshaping.

``` r

problem <- capital_allocation_problem(max_weight = 0.5)

train <- dfl_data(subset(capital_allocation_demo, split == "train"),
                  features = starts_with("feat_"),
                  cost = realized_return, scenario = scenario,
                  element_id = asset_id)

fit <- dfl_fit(train$x, train$cost, train$scenario, problem = problem,
               element_id = train$element_id,
               control = dfl_control(seed = 1))

fit
#> <DecisionFocusedLasso: solver, sense=max, 6 features, 4 kept, 150 instances scored>
```

Each row is one element (here, one asset); the `scenario` column groups
rows into an instance, which is one optimisation problem. See
`?dflasso-glossary`. To use other data, supply one row per element, a
scenario column grouping rows into instances, and a realised-cost
column; see
[`?dfl_data`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md)
for the shape. For the problem, pick a constructor
([`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md))
or wrap a solver with
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md).

## Outputs

The calls below continue from the `fit` built in Quick start.

`summary(fit)` reports the kept features, the eased penalties, and what
is known about held-out regret.

``` r

summary(fit)
#> Summary of a decision-focused cost model (dflasso)
#> Objective: maximise value over 150 instances scored, 6 features.
#> 
#> FEATURES KEPT
#>   4 of 6 features were kept for the decision.
#>   2 of these are decision-driven rescues, weak at predicting cost on their own, but
#>   they move the decision, so the model kept them:
#>       feat_01, feat_02
#>   See tidy(fit) for every feature, its coefficient, and its role.
#> 
#> WHAT EACH FEATURE IS FOR  (across all features, by how they behave)
#>   decision-relevant   2    were kept for the decision (rescued by the decision step)
#>   prediction-relevant 2    were kept by the accuracy step (the usual reason)
#>   both                0    do both
#>   neither             2    not used by either model
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
#>   Filtering strength 0.083, chosen automatically by trying many settings and
#>   keeping the best; smaller keeps more features. (this setting is called
#>   lambda)
#> 
#> REPRODUCIBILITY
#>   Fit with seed 1; re-running with this seed gives bit-identical features,
#>   scores, and decisions. Pass seed = <int> to fix it up front and quote
#>   that number.
#>   Decision quality was averaged over 15 random reshuffles of the instances.
#> 
#> SETTINGS
#>   main  : features put on a common scale, 10-fold cross-validation, instances must have >= 2 elements.
#>   method: all at defaults.
```

The penalty plot shows, for each feature whose filtering the decision
focus eased, how far it was eased. A longer line means the penalty was
eased more. Easing a feature’s penalty does not guarantee the refit
keeps it.

``` r

plot(fit, type = "penalty")
```

![For each feature whose filtering was eased, a line from its usual
filtering strength to the eased, decision-focused strength; all move
leftward, meaning easier to
keep.](reference/figures/README-penalty-1.png)

The coefficient path traces each feature’s effect as the model keeps
more of them, with the chosen model marked.

``` r

plot(fit, type = "path")
```

![Coefficient paths for every feature against model size; the kept
features are highlighted and a dashed line marks the chosen
model.](reference/figures/README-path-1.png)

[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
turns features into weights on new data, and never reads costs. The
training frame stands in for new data here, to keep the example short.

``` r

out <- decide(fit, train$x, train$scenario,
              element_id_new = train$element_id)
out
#> Decisions for 150 instances (dflasso)
#>   150 reached a decision; 0 had no feasible decision.
#>   Objective sense: maximise value.
#> 
#>   A look at two:
#>     scenario_01  -> 2 of 6 chosen: 5, 6   (predicted total value -1.4)
#>     scenario_02  -> 2 of 6 chosen: 1, 2   (predicted total value 1.9)
#> 
#>   -> decisions(x) for the full action per instance (named by the element ids);
#>      as_tibble(x) for one tidy row per (instance, element), join-ready.
decisions(out)[["scenario_01"]]
#>   1   2   3   4   5   6 
#> 0.0 0.0 0.0 0.0 0.5 0.5
```

[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
scores both models on the held-out test split, the instances the fit did
not train on.

``` r

test <- dfl_data(subset(capital_allocation_demo, split == "test"),
                 features = starts_with("feat_"),
                 cost = realized_return, scenario = scenario,
                 element_id = asset_id)

score <- regret(fit, test$x, test$cost, test$scenario,
                element_id_test = test$element_id)
score
#> Decision quality vs the prediction-focused approach (dflasso regret)
#>   Lower regret is better. Regret = how much worse a decision was than the
#>   best possible in hindsight, averaged over instances.
#> 
#>   Decision-focused model : 0.22 average regret
#>   Prediction-focused model: 0.30 average regret
#> 
#>   The decision focus cut regret by 25.4% on this held-out data.
#> 
#>   Measured on 75 of 75 instances (100%); 0 set aside for missing costs, 0 had no feasible decision. Both approaches were compared on the same instances.
```

The demo is simulated, with two features that move the allocation while
predicting return poorly. On other data the decision focus may help
less, or not at all. The held-out
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
is how to tell.

The boxes show how the per-instance regret is spread around each
average.

``` r

plot(score)
```

![Per-instance regret of the decision-focused and prediction-focused
models on the same held-out scenarios, with each average marked; the
decision-focused model's average sits further left, at lower
regret.](reference/figures/README-regret-plot-1.png)

## Learn more

- [Reference and articles](https://Mischa-Hermans.github.io/dflasso/):
  the pkgdown site.
- [`vignette("humanitarian-routing", package = "dflasso")`](https://Mischa-Hermans.github.io/dflasso/articles/humanitarian-routing.md):
  the full worked example, on humanitarian routing.

## Getting help

- [GitHub Issues](https://github.com/Mischa-Hermans/dflasso/issues): bug
  reports and feature requests.
- A small [reprex](https://reprex.tidyverse.org/) makes a report quicker
  to act on.

------------------------------------------------------------------------

Developed by **Mischa Hermans**, Maastricht University.
