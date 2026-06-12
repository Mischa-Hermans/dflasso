# dflasso: a decision-focused lasso for predict-then-optimise

dflasso predicts costs with a lasso that keeps the features which track
decision regret, not prediction accuracy. It then solves the
optimisation problem on new data and reports whether that decision focus
lowered regret against an ordinary prediction-focused fit.

The inputs are one row per decision element (an arc, item, or asset) per
scenario, with the element's features and realised cost and a scenario
id grouping elements into instances, plus a way to turn predicted costs
into a decision, either a built-in solver or a supplied `solve`
function. dflasso scores each feature by how strongly it tracks decision
regret, eases the penalty on the high scorers, and refits.

## A short example

Fit, decide, and measure regret on `capital_allocation_demo`:

    library(dflasso)
    train <- subset(capital_allocation_demo, split == "train")
    test  <- subset(capital_allocation_demo, split == "test")

    train_data <- dfl_data(train, features = starts_with("feat_"),
                           cost = realized_return, scenario = scenario,
                           element_id = asset_id)
    fit <- dfl_fit(train_data$x, train_data$cost, train_data$scenario,
                   problem = capital_allocation_problem(max_weight = 0.5),
                   element_id = train_data$element_id,
                   control = dfl_control(seed = 1))

    decisions(decide(fit, train_data$x, train_data$scenario,
                     element_id_new = train_data$element_id))[[1]]

    test_data <- dfl_data(test, features = starts_with("feat_"),
                          cost = realized_return, scenario = scenario)
    regret(fit, test_data$x, test_data$cost, test_data$scenario)

## Example datasets

The package ships two datasets.
[capital_allocation_demo](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md)
is a single table, one row per asset per period.
[aid_routing](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md)
is a routing problem given as several tables (the arcs, nodes, and daily
travel times of a road network), which
[`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md)
turns into the element rows the model takes.

## Main functions

- [`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md):

  Fit the model. Pass a `problem` to solve, or a `regret` vector to skip
  the solver.

- [`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md):

  New instances in, decisions out.

- [`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md):

  Held-out decision quality against the prediction-focused baseline.

- [`proxy_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  and
  [`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md):

  Rank features by how strongly they track regret.
  [`proxy_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  reads the scores from a fitted model;
  [`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md)
  computes them straight from a supplied regret column, with no model
  and no solver.

## Topic pages

- `?dflasso-faq`:

  Common questions about the method and its use.

- `?dflasso-glossary`:

  Definitions of the terms.

- `?dflasso-solvers`:

  Templates for wrapping a custom optimiser.

- `?dflasso-troubleshooting`:

  When something goes wrong.

- `?dflasso-validation`:

  Deciding whether to trust and deploy a fit.

## See also

Useful links:

- <https://github.com/Mischa-Hermans/dflasso>

- <https://Mischa-Hermans.github.io/dflasso/>

- Report bugs at <https://github.com/Mischa-Hermans/dflasso/issues>

## Author

**Maintainer**: Mischa Hermans <mischa.hermans@maastrichtuniversity.nl>
