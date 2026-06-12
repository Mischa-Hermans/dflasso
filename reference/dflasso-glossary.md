# Glossary of dflasso terms

The words this package uses, with short definitions. Most appear in the
help for
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`decide()`](https://Mischa-Hermans.github.io/dflasso/reference/decide.md),
and
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md);
this page gathers them in one place.

## Terms

- regret:

  How much worse a decision turned out than the best possible choice in
  hindsight. It is the objective of the decision made on predicted costs
  minus the objective of the best decision under the true costs, clamped
  at zero. Reported by
  [`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md).

- predict-then-optimise:

  The setting dflasso targets. Uncertain costs are predicted from
  features, then fed to an optimiser that picks a decision, all before
  the truth arrives. The decision is what gets acted on.

- decision-relevant feature:

  A feature whose movements line up with decision regret: when it
  shifts, the chosen decision shifts. Such a feature can be a weak
  predictor of cost yet still change which option wins. A
  prediction-relevant feature predicts cost well but need not move any
  decision.

- rescue:

  A decision-relevant but weak predictor that the decision step retains
  by lowering its penalty factor. Rescues are named in `summary(fit)`
  and shown in the top-left of `plot(fit)`.

- proxy score:

  A number between 0 and 1 measuring how strongly a feature tracks
  regret, also called the decision-relevance score. It is the absolute
  correlation between the feature (aggregated to instance level) and
  per-instance regret, averaged over resampled splits. As a correlation,
  it records association rather than cause. A higher score lowers that
  feature's penalty factor. Read it with
  [`proxy_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
  or in the `proxy_score` column of `tidy(fit)`.

- scenario:

  The input column or vector that groups element rows into instances.
  Each distinct value is one instance. It is passed as `scenario`;
  printed views and counts such as `n_instances` call the same thing an
  instance.

- instance:

  One optimisation problem a decision is committed to: one
  delivery-day's graph with its origin and destination, one knapsack
  realisation, one rebalancing. The rows of instance `k` are exactly
  `which(scenario == k)`. Instances may have different numbers of rows;
  only the learned coefficient vector is shared across them.

- element:

  One decision atom: a road arc, a knapsack item, an asset, a
  linear-program variable, an assignment cell. It is one row of the
  feature matrix and has one cost, predicted from its own features by a
  single shared coefficient vector.

- coverage:

  Whether an instance has observed costs over the elements its solver
  inspects. The decision-quality step must solve each instance twice,
  once on predicted costs and once on real ones, so it needs that
  instance complete over its solved elements. Learning the cost model is
  separate and tolerates gaps. The coverage report records, per
  instance, how many elements were solved and how many were observed.

- eligibility:

  An instance is eligible for the decision-quality step when it is fully
  covered: every solved element has an observed cost. Eligible instances
  are scored; the rest are set aside and counted as partial coverage.
  The fit stores `n_proxy_eligible` and `n_partial_coverage`, and
  [`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
  applies the same rule to held-out instances so both approaches are
  compared on identical instances.

- sense:

  The direction of the objective, `"min"` or `"max"`. A shortest path
  minimises cost; a knapsack or allocation maximises value. Built-in
  problems fix it. On the supplied-regret path, `sense` is recorded and
  echoed, and it sets the direction the negative-regret check reads; it
  does not transform regret that is supplied already formed.

- penalty factor:

  The per-feature weight the final lasso applies, one entry per feature.
  A larger factor penalises a feature harder, so it is dropped sooner; a
  smaller factor retains it. The decision step lowers the penalty factor
  on decision-relevant features. See the `penalty_factor` column of
  `tidy(fit)`.

- adaptive weight:

  The prediction-only penalty weight, `1 / abs(beta_ridge)^gamma`, taken
  from a ridge pre-fit. It is the baseline an adaptive lasso would use,
  before any decision signal. Comparing it with the final penalty factor
  shows what the decision step changed.

## See also

[dflasso-faq](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-faq.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md),
[`proxy_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl-accessors.md)
