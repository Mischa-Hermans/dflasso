# Deciding whether to trust and deploy a dflasso model

A checklist for deciding whether a fitted model is worth acting on. It
is five steps run at the console, each calling a verb that already
exists, and adds no new function or option. Run them on a held-out test
set the model never saw, prepared the same way as training.

One caveat first. On the solver path
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
re-solves held-out instances on real costs, so the comparison is
measured rather than inferred. On the supplied-regret path the
[`dfl_score()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_score.md)
ranking is a correlational signal: with no held-out decisions there is
nothing to back-test it against, so a high score marks an association
with decision failure and stops short of proving cause or guaranteeing
anything. The steps below are for the solver path.

## With only one dataset

Split it by whole instances, never by single rows. An instance must sit
entirely in train or entirely in test, or the complete-coverage scoring
rule breaks. Choose a subset of `unique(scenario)` for test, for example
`test_ids <- sample(unique(scenario), 0.25 * length(unique(scenario)))`,
fit on the rows whose `scenario` is not in `test_ids`, then call
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
on the rows whose `scenario` is. A later time window works the same way:
hold out whole days, not rows within them.

## Step 1, held-out regret

Held-out regret against the prediction-focused baseline.

    result <- regret(model, x_test, cost_test, scenario_test,
                    instances_test, element_id_test = ids_test,
                    baseline = "adaptive")
    result

The print reads "cut regret by X%" when the decision-focused line sits
below the prediction-focused one, or "RAISED regret ... it lost here"
when it does not. A loss is a valid stopping point. Whether a thin gap
means anything is left to Steps 2 and 5; this step on its own cannot
separate a small gap from noise.

## Step 2, the per-instance spread

What sits behind the average.

    plot(result)

A broad gain shows as the decision-focused cloud sitting left of the
prediction-focused one across the bulk of instances, with its mean
diamond to the left. Less reassuring: the two clouds overlapping
heavily, or the decision-focused side carrying a few very high-regret
instances behind a better average. A few bad instances can outweigh a
better mean, and this plot is where they surface.

## Step 3, the rescued features

Whether the rescued features are plausible. The scores measure
association and carry no causal claim.

    plot(model, type = "roles")
    subset(tidy(model), role == "decision-relevant")

A plausible result has rescued features a domain expert would recognise,
with `proxy_score` clearly off the floor. Weaker signs: rescues that are
noise columns with no explanation, or every score barely above the
floor. Read the y-axis as labelled. Tracking when the decision goes
wrong reports an association with decision failure and says nothing
about cause.

The confound to name here is collinearity. A feature can score high only
because it is correlated with a genuinely decisive feature; the proxy
sees the shared movement and cannot separate the two. A high score then
marks a lead to investigate, and does not show that the feature itself
drives the decision.

## Step 4, stability across seeds

One different seed.

    m2 <- dfl_fit(x, cost, scenario, problem = problem,
                  control = dfl_control(seed = 99))
    cor(proxy_score(model), proxy_score(m2), use = "complete.obs")
    regret(m2, x_test, cost_test, scenario_test, instances_test,
           element_id_test = ids_test, baseline = "adaptive")

Two kinds of stability differ here. A role-label flip across seeds is
tolerable: a feature near a threshold changes bucket, which is expected,
so judge it by the `proxy_score` ranking rather than the bare label. The
regret sign flipping matters more: if "cut regret" becomes "RAISED
regret" on another seed, the gain does not hold up across seeds. Pass
the same `instances_test` and `element_id_test` as Step 1, because the
`NULL` auto-build errors on problems that need per-instance data. Two
seeds is a rough check and falls well short of a formal estimator.

## Step 5, how many instances were scored

The counts behind the comparison.

    result$n_proxy_eligible   # fully covered held-out instances scored
    result$n_instances        # total held-out instances
    result$n_partial_coverage # set aside for missing costs

The "Measured on N of M" line reports the count of fully covered
held-out instances; a larger N gives a steadier estimate. A handful
means the figure rests on little; widen the held-out window or
reconstruct fuller per-element costs. Even a comfortable N is one noisy
draw.

## What "meaningfully lower" means

There is no p-value, confidence interval, or standard error on the
regret gap, by design. What is on screen is the only available measure.
A reduction reads as meaningful when it is large relative to the
per-instance spread from `plot(result)` (Step 2) and it holds its sign
across a couple of seeds (Step 4). A hair-thin gap that sits inside the
spread carries little weight, however large the percentage reads. There
is no fixed threshold to clear; the spread and the second seed are what
there is to judge it by.

One held-out set's regret percentage is itself one noisy sample. A 19%
gap on one set of about 24 instances gives a rough indication and should
not be read as an exact figure. Quote the direction and rough size
rather than the precise percent. Where possible, corroborate on a second
disjoint split or a later time window; agreement in direction across two
splits carries more weight than the exact number on one.

## What to have in hand before acting

Four things point the same way before a fit is worth acting on: held-out
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)
lower relative to the spread; the result keeping its sign across a
couple of seeds; rescued features that make sense to an expert; and a
count of scored instances that is not tiny. A training-data number, a
single seed, or a hair-thin gap inside the spread is too little to act
on.

Several outcomes point the other way. A held-out regret that did not
drop is a correct result the package is built to give; the
prediction-focused model stands, with the comparison learned. Where the
in-fit preview looked good but held-out did not, the held-out number is
the one that counts. Where a single seed looked good but the regret sign
flipped, the gain did not hold up. A gain on a handful of instances, or
on one split, is a lead to confirm rather than a settled result.

## Why regret, and why held-out

Regret measures the decision that gets deployed. How accurately the
model predicts costs is a separate thing, and a model can predict a
little worse on average yet decide better.
[`predict()`](https://rdrr.io/r/stats/predict.html) is a diagnostic: a
better RMSE is not a reason to adopt and a slightly worse one is not a
reason to reject. The in-fit preview from
[`glance()`](https://generics.r-lib.org/reference/glance.html) or
[`summary()`](https://rdrr.io/r/base/summary.html) is computed over
training resamples and can disagree with held-out
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md);
where they differ, the held-out figure is the one measured on data the
model never saw.

## See also

[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md),
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md),
[dflasso-troubleshooting](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-troubleshooting.md),
[dflasso-faq](https://Mischa-Hermans.github.io/dflasso/reference/dflasso-faq.md)

## Examples

``` r
# \donttest{
train <- simulate_capital_allocation(60, 6, 6, seed = 1)
test  <- simulate_capital_allocation(30, 6, 6, seed = 2)
model <- dfl_fit(
  train$x, train$cost, train$scenario,
  problem = capital_allocation_problem(max_weight = 0.5),
  element_id = train$element_id,
  control = dfl_control(seed = 1, n_splits = 5L))

result <- regret(model, test$x, test$cost, test$scenario,
                baseline = "adaptive")
result                      # Step 1: the comparison
#> Decision quality vs the prediction-focused approach (dflasso regret)
#>   Lower regret is better. Regret = how much worse a decision was than the
#>   best possible in hindsight, averaged over instances.
#> 
#>   Decision-focused model : 0.22 average regret
#>   Prediction-focused model: 0.26 average regret
#> 
#>   The decision focus cut regret by 15.2% on this held-out data.
#> 
#>   Measured on 30 of 30 instances (100%); 0 set aside for missing costs, 0 had no feasible decision. Both approaches were compared on the same instances.
result$n_proxy_eligible      # Step 5: how many instances scored
#> [1] 30
# }
```
