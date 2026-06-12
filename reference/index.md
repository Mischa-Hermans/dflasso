# Package index

## Fitting the model

Fit the decision-focused cost model and set its options.

- [`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
  : Fit a decision-focused lasso
- [`dfl_control()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_control.md)
  : Options for a dflasso fit

## Making and judging decisions

Turn a fit into decisions on new data and score how good they were.

- [`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md)
  : Make decisions on new data
- [`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
  [`print(`*`<dfl_regret>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
  : Realised regret of the decision focus against the baseline
- [`predict(`*`<DecisionFocusedLasso>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/predict-coef.md)
  [`coef(`*`<DecisionFocusedLasso>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/predict-coef.md)
  : Predicted costs and coefficients from a fitted model

## Ranking from supplied regret

Rank features from out-of-sample decision quality supplied directly.

- [`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md)
  [`print(`*`<dfl_score>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md)
  : Rank features by how strongly they track regret
- [`regret_from_objectives()`](https://Mischa-Hermans.github.io/dflasso/reference/regret_from_objectives.md)
  [`regret_from_decisions()`](https://Mischa-Hermans.github.io/dflasso/reference/regret_from_objectives.md)
  : Build a regret vector from objective values or decisions

## Optimisation problems and solvers

Built-in problems, the custom-solver contract, and the solve calls
behind a decision.

- [`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md)
  : Wrap a custom solver as a dflasso problem

- [`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md)
  : Shortest path through a graph

- [`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md)
  : Pick a subset under one budget

- [`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md)
  : Split capital across choices

- [`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)
  [`solve_support()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md)
  : Solve a decision from predicted costs

- [`prepare_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/prepare_instances.md)
  :

  Turn a routing dataset into rows for
  [`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)

## Preparing data

Slice features, costs and scenarios from a data frame.

- [`dfl_data()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_data.md)
  :

  Shape one data frame into the inputs for
  [`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)

- [`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md)
  : Build the per-scenario instances list

## Simulators and demo datasets

Paired simulators and the demo data the examples run on.

- [`simulate_shortest_path()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_shortest_path.md)
  : Simulate a shortest-path routing problem
- [`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md)
  : Simulate a knapsack problem
- [`simulate_capital_allocation()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_capital_allocation.md)
  : Simulate a capital-allocation problem
- [`aid_routing`](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md)
  : Aid routing, a single-source shortest-path dataset
- [`capital_allocation_demo`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_demo.md)
  : Capital allocation, a budget-split dataset
- [`dflasso_tuned_thresholds`](https://Mischa-Hermans.github.io/dflasso/reference/dflasso_tuned_thresholds.md)
  : Tuned eligibility thresholds

## Inspecting a fit

Read what a fit selected, summarise it, plot it, and pull out single
quantities.

- [`summary(`*`<DecisionFocusedLasso>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/summary.DecisionFocusedLasso.md)
  [`print(`*`<summary.DecisionFocusedLasso>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/summary.DecisionFocusedLasso.md)
  : Summary of a fitted decision-focused lasso
- [`tidy(`*`<DecisionFocusedLasso>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-broom.md)
  [`glance(`*`<DecisionFocusedLasso>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-broom.md)
  [`augment(`*`<DecisionFocusedLasso>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-broom.md)
  : Broom methods for a fitted decision-focused lasso
- [`autoplot(`*`<DecisionFocusedLasso>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/plot.DecisionFocusedLasso.md)
  [`plot(`*`<DecisionFocusedLasso>`*`,`*`<missing>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/plot.DecisionFocusedLasso.md)
  : Plot a fitted decision-focused lasso
- [`proxy_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`adaptive_weight()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`penalty_factor()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`selected_features()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`coverage()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`splits()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`seed()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`lambda_min()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`lambda_1se()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  [`problem()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  : Accessors for a fitted decision-focused lasso
- [`sense()`](https://Mischa-Hermans.github.io/dflasso/reference/sense.md)
  [`is_minimization()`](https://Mischa-Hermans.github.io/dflasso/reference/sense.md)
  : Objective sense of a problem

## Working with a decision set

Read the decisions, objectives and feasibility that decide() returns.

- [`decisions()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md)
  [`selected_elements()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md)
  [`objectives()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md)
  [`is_feasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md)
  [`element_sequence()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-accessors.md)
  : Read decisions out of a decision set
- [`feasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md)
  [`infeasible()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md)
  [`infeasible_reasons()`](https://Mischa-Hermans.github.io/dflasso/reference/decision-set-feasibility.md)
  : Subset a decision set by feasibility
- [`as_tibble(`*`<DecisionSet>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/as_tibble.DecisionSet.md)
  : Tidy a decision set into a long table

## Plotting regret

Compare per-instance regret of the two models.

- [`autoplot(`*`<dfl_regret>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/plot.dfl_regret.md)
  [`plot(`*`<dfl_regret>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/plot.dfl_regret.md)
  [`plot(`*`<dfl_regret>`*`,`*`<missing>`*`)`](https://Mischa-Hermans.github.io/dflasso/reference/plot.dfl_regret.md)
  : Plot the held-out regret against the baseline

## Concepts and help

The package overview, a glossary, the solver gallery, and the pages to
read when something looks off.

- [`dflasso`](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-package.md)
  [`dflasso-package`](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-package.md)
  : dflasso: a decision-focused lasso for predict-then-optimise
- [`dflasso-glossary`](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-glossary.md)
  : Glossary of dflasso terms
- [`dflasso-faq`](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-faq.md)
  : Frequently asked questions
- [`dflasso-solvers`](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-solvers.md)
  : Wrap a custom optimiser with optimization_problem(solve = ...)
- [`dflasso-troubleshooting`](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-troubleshooting.md)
  : Troubleshooting: when something goes wrong
- [`dflasso-validation`](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-validation.md)
  : Reading a dflasso result on held-out data
