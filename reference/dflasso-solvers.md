# Wrap a custom optimiser with optimization_problem(solve = ...)

When no built-in fits, a custom optimisation problem is wrapped with
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md).
One function, the `solve` argument, `function(costs, instance)`, turns a
vector of predicted costs into a decision, alongside the objective
`sense`. dflasso treats the result like any other problem. The sections
below give the general pattern, then worked solvers for the knapsack,
assignment, transportation, minimum spanning tree, and vehicle routing
shapes.

A model already written in lpSolve, igraph, ompr, ROI, CVXR, Gurobi, or
a Python module can be wrapped rather than rewritten.

## The pattern

dflasso does not optimise itself. During fitting it hands `solve` one
instance's predicted `costs` (a numeric vector, one entry per element
row of that instance, in the original row order) and asks for the
decision. The wrapped tool optimises with those `costs` as the linear
objective coefficients, and returns one number per element row in the
same order.

    problem <- optimization_problem(
      sense = "min",                 # or "max": the direction of cost' z
      solve = function(costs, instance) {
        # optimise with the chosen tool, objective = costs
        decision                     # finite numeric, length == length(costs)
      }
    )

## Requirements on solve

Order. `costs` arrives in the row order of `x`, `cost`, and `scenario`;
the tool's variable order must match, and the returned vector must be in
that same order. dflasso cannot check this, so a transposed grid or a
tool that reorders variables gives a silent wrong answer rather than an
error.

Linear in `costs`. The objective is a straight sum of cost times
decision. Constraints can be anything the tool supports, but an
objective that is not linear in `costs` makes the regret check
meaningless.

The return. A finite numeric vector (0/1, or weights, or flows), the
same length as `costs`, with no `NA`, `Inf`, or list.
[`dfl_fit()`](https://Mischa-Hermans.github.io/dflasso/reference/dfl_fit.md)
probes this once before any real work and errors with the offending
scenario.

Two further points apply to any external tool. Keep `solve`
deterministic: the same `costs` must give the same decision, so fix any
internal seed and pin threads. And do every step that does not depend on
`costs` once, storing the result as ordinary data in `instance` rather
than as a live handle (an `lprec` pointer, a Gurobi env, a reticulate
module). Live handles do not serialise and are not safe to share across
parallel workers; build the model fresh inside `solve` from that stored
data each call.

## When to declare solve_support

`solve_support` tells dflasso which element rows a feasible decision
could use for a given instance. That set drives the coverage rule: a
scenario counts towards the decision-quality step only when every row in
its support has an observed realised cost. The default assumes the
solver may use every row, so a single unobserved cost makes the whole
scenario partial coverage and drops it. On fully observed data, or when
the solver reads every row (a top-k sorts all costs, for instance), the
default can be left as is. Supply a support when the solver provably
ignores some rows and those rows are the ones that go unobserved:
declaring the narrower support keeps those scenarios eligible. See
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md)
for the argument.

## Knapsack (built-in)

Pick a subset under one capacity. This is a built-in,
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
so no solver is written; it is included to show the shape. Each instance
carries item weights and a capacity, built in one line by
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
and the predicted value is the cost vector.
[`simulate_knapsack()`](https://Mischa-Hermans.github.io/dflasso/reference/simulate_knapsack.md)
returns a default `capacity` (half the total item weight, a binding
budget), so
`make_instances(sim$scenario, weights = sim$weights, capacity = sim$capacity)`
runs straight through.
[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md)
is needed only to minimise a selection cost instead, where the built-in
(fixed to `max`) will not fit.

## Assignment or matching (one lpSolve call)

Assign rows of a cost grid to columns one-to-one. The elements are the
`n*n` cells; the decision is 0/1 over cells.
[`lpSolve::lp.assign`](https://rdrr.io/pkg/lpSolve/man/lp.assign.html)
solves it in one call. Order matters: build the cell rows row-major (row
1 cols 1..n, then row 2, and so on), rebuild the grid with
`byrow = TRUE`, and flatten the solution back with `as.numeric(t(...))`.
Both ends are row-major, so the returned 0/1 lines up cell for cell.
Dropping the [`t()`](https://rdrr.io/r/base/t.html) on a rectangular
problem silently returns the transposed decision. A rectangular grid
needs padding to square with a large dummy cost on the filler cells.

## Transportation (one lpSolve call)

Ship from supplies to demands at least predicted total cost. The
elements are the routes, one per source-by-sink cell.
[`lpSolve::lp.transport`](https://rdrr.io/pkg/lpSolve/man/lp.transport.html)
solves it. Fix a source-major row order (source 1 to every sink, then
source 2), build `x` and `cost` in it, rebuild the matrix
`byrow = TRUE`, and flatten with [`t()`](https://rdrr.io/r/base/t.html).
Decisions are continuous flows here, so values other than 0/1 are
expected. Guard `res$status != 0` so an infeasible week (supply below
demand) becomes a clean `feasible = FALSE` rather than silent all-zero
flows.

## Minimum spanning tree (one igraph call)

Connect every node at least predicted total cost. The elements are the
edges; the decision is 0/1 per edge.
[`igraph::mst`](https://r.igraph.org/reference/mst.html) solves it.
Recover the decision by integer edge index,
`seq_len(ecount(g)) %in% as.integer(E(mst(g)))`, rather than by
endpoint-name strings: two parallel edges on one span collide to the
same string and both get marked, giving a silent wrong answer. Parallel
edges are common in connectivity problems. Guard `components(g)$no > 1`,
because `mst` on a disconnected graph silently returns a forest rather
than erroring.

## Vehicle routing (write a solver)

dflasso has no VRP solver, and there is no one-liner. Multi-vehicle
routing with capacities or time windows is its own hard problem. Wrap a
VRP solver in `optimization_problem(sense = "min", solve = <a solver>)`,
returning a 0/1 arc indicator in element-row order, and keep it
deterministic so
[`regret()`](https://Mischa-Hermans.github.io/dflasso/reference/regret.md)'s
twice-solved oracle holds. The example
[aid_routing](https://Mischa-Hermans.github.io/dflasso/reference/aid_routing.md)
dataset is single-source shortest path, solved by the built-in
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md);
it is not a VRP instance.

## See also

[`optimization_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/optimization_problem.md),
[`make_instances()`](https://Mischa-Hermans.github.io/dflasso/reference/make_instances.md),
[`solve_decision()`](https://Mischa-Hermans.github.io/dflasso/reference/solve_decision.md),
[`knapsack_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/knapsack_problem.md),
[`shortest_path_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/shortest_path_problem.md),
[`capital_allocation_problem()`](https://Mischa-Hermans.github.io/dflasso/reference/capital_allocation_problem.md)

## Examples

``` r
# The quick examples below build the problem and solve one instance
# with solve_decision(), the cheapest way to confirm a wrapper is
# correct. The first, full example runs fit, decide and regret.

# The pattern: a tiny custom solver, no extra packages.
pick_cheapest_half <- function(costs, instance) {
  as.numeric(costs <= stats::median(costs))
}
problem <- optimization_problem(pick_cheapest_half, sense = "min")
solve_decision(problem, c(3, 1, 4, 2), instance = list())
#> [1] 0 1 0 1

# \donttest{
# End to end on a custom problem: pick the cheapest k of n items
# (no built-in fits a fixed-count min-cost pick). This shows the one
# thing the quick examples leave out: how per-instance data (here k)
# reaches the solver, through make_instances() and dfl_fit(instances=).

# 1. A solver. costs is one predicted cost per item row of the
#    instance, in row order; return a 0/1 of the same length.
pick_cheapest_k <- function(costs, instance) {
  chosen <- order(costs)[seq_len(instance$k)]
  decision <- numeric(length(costs))
  decision[chosen] <- 1
  decision
}
cheapest_k <- optimization_problem(
  pick_cheapest_k, sense = "min", name = "cheapest-k"
)

# 2. A dataset by hand: n_items rows in each of n_scenarios scenarios.
#    feat_signal drives the cost; feat_noise does not.
set.seed(1)
n_items <- 6L
n_scenarios <- 60L
rows <- n_items * n_scenarios
feat_signal <- stats::rnorm(rows)
feat_noise <- stats::rnorm(rows)
realized_cost <- 2 * feat_signal + stats::rnorm(rows, sd = 0.3)
scenario <- rep(sprintf("s%02d", seq_len(n_scenarios)), each = n_items)
item_id <- rep(sprintf("item_%d", seq_len(n_items)), times = n_scenarios)
features <- cbind(feat_signal = feat_signal, feat_noise = feat_noise)

# 3. Instances carry k = 3 to every scenario (the scalar is recycled).
instances <- make_instances(scenario, k = 3L)

# 4. Fit, summarise, decide, and measure regret.
fit <- dfl_fit(
  features, realized_cost, scenario,
  problem = cheapest_k, instances = instances,
  element_id = item_id, control = dfl_control(seed = 1, n_splits = 5L)
)
summary(fit)
#> Summary of a decision-focused cost model (dflasso)
#> Objective: minimise cost over 60 instances scored, 2 features.
#> 
#> FEATURES KEPT
#>   1 of 2 features were kept for the decision.
#>   None were decision-driven rescues on this fit.
#>   See tidy(fit) for every feature, its coefficient, and its role.
#> 
#> WHAT EACH FEATURE IS FOR  (across all features, by how they behave)
#>   decision-relevant   0    were kept for the decision (rescued by the decision step)
#>   prediction-relevant 1    were kept by the accuracy step (the usual reason)
#>   both                0    do both
#>   neither             1    not used by either model
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
#>   Filtering strength 0.134, chosen automatically by trying many settings and
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
picks <- decide(
  fit, features, scenario,
  instances_new = instances, element_id_new = item_id
)
picks
#> Decisions for 60 instances (dflasso)
#>   60 reached a decision; 0 had no feasible decision.
#>   Objective sense: minimise cost.
#> 
#>   A look at two:
#>     s01  -> 3 of 6 chosen: item_1, item_3, item_6   (predicted total cost -4.6)
#>     s02  -> 3 of 6 chosen: item_1, item_4, item_6   (predicted total cost 1.1)
#> 
#>   -> decisions(x) for the full action per instance (named by the element ids);
#>      as_tibble(x) for one tidy row per (instance, element), join-ready.
regret(
  fit, features, realized_cost, scenario,
  instances_test = instances
)
#> Decision quality vs the prediction-focused approach (dflasso regret)
#>   Lower regret is better. Regret = how much worse a decision was than the
#>   best possible in hindsight, averaged over instances.
#> 
#>   Decision-focused model : 0.08 average regret
#>   Prediction-focused model: 0.08 average regret
#> 
#>   The decision focus cut regret by 0.0% on this held-out data.
#> 
#>   Measured on 60 of 60 instances (100%); 0 set aside for missing costs, 0 had no feasible decision. Both approaches were compared on the same instances.
# }

# Assignment: a 2x2 cost grid, solved with lpSolve.
assignment <- optimization_problem(
  sense = "min",
  solve = function(costs, instance) {
    grid_size <- instance$n
    grid <- matrix(costs, grid_size, grid_size, byrow = TRUE)
    solution <- lpSolve::lp.assign(grid, direction = "min")$solution
    as.numeric(t(solution))              # row-major flatten
  },
  name = "assignment"
)
solve_decision(assignment, c(4, 2, 3, 5), instance = list(n = 2))
#> [1] 0 1 1 0

# Transportation: 2 plants x 3 markets, solved with lpSolve.
transport <- optimization_problem(
  sense = "min",
  solve = function(costs, instance) {
    grid <- matrix(costs, nrow = length(instance$supply), byrow = TRUE)
    res <- lpSolve::lp.transport(
      cost.mat = grid,
      row.signs = rep("<=", length(instance$supply)),
      row.rhs   = instance$supply,
      col.signs = rep(">=", length(instance$demand)),
      col.rhs   = instance$demand)
    if (res$status != 0) stop("infeasible transportation instance")
    as.vector(t(res$solution))           # back to source-major
  },
  name = "transportation"
)
solve_decision(transport, c(4, 6, 8, 5, 3, 7),
               instance = list(supply = c(30, 40),
                               demand = c(20, 20, 15)))
#> [1] 20  0  0  0 20 15

# Minimum spanning tree: a 4-node network, solved with igraph.
spanning <- optimization_problem(
  sense = "min",
  solve = function(costs, instance) {
    g <- igraph::graph_from_data_frame(
      data.frame(from = instance$from, to = instance$to, weight = costs),
      directed = FALSE)
    if (igraph::components(g)$no > 1)
      stop("candidate edges do not connect every node")
    in_tree <- as.integer(igraph::E(igraph::mst(g, weights = costs)))
    as.numeric(seq_len(igraph::ecount(g)) %in% in_tree)
  },
  name = "min-cost spanning tree"
)
solve_decision(spanning, c(4, 6, 2, 5, 3),
               instance = list(from = c("n1", "n1", "n2", "n2", "n3"),
                               to   = c("n2", "n3", "n3", "n4", "n4")))
#> [1] 1 1 1 0 0
```
