# Builds the two example datasets, capital_allocation_demo and aid_routing,
# from fixed-seed simulator calls so they reproduce exactly.
# Run from the package root: Rscript data-raw/make_datasets.R

library(dflasso)

capital_allocation_seed <- 20260601L
aid_routing_seed <- 7L

allocation <- simulate_capital_allocation(
  n_scenarios = 225, n_assets = 6, n_features = 6,
  seed = capital_allocation_seed
)
capital_allocation_demo <- allocation$data

scenario_levels <- levels(capital_allocation_demo$scenario)
test_levels <- scenario_levels[151:225]
capital_allocation_demo$split <- ifelse(
  capital_allocation_demo$scenario %in% test_levels, "test", "train"
)
attr(capital_allocation_demo, "decision_relevant_features") <- NULL

aid_routing <- simulate_shortest_path(
  n_days = 250, n_arcs = 30, n_nodes = 12,
  seed = aid_routing_seed
)

usethis::use_data(capital_allocation_demo, aid_routing,
                  overwrite = TRUE, compress = "xz")
