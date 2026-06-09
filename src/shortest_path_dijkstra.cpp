#include <Rcpp.h>
#include <queue>

using namespace Rcpp;

// [[Rcpp::export]]
IntegerVector shortest_path_dijkstra(IntegerVector from,
                                     IntegerVector to,
                                     NumericVector cost,
                                     int n_nodes,
                                     int origin,
                                     int destination) {
  int n_arcs = from.size();
  if (to.size() != n_arcs || cost.size() != n_arcs) {
    stop("from, to and cost must have the same length");
  }
  if (origin < 1 || origin > n_nodes || destination < 1 ||
      destination > n_nodes) {
    stop("origin and destination must be node ids in 1..n_nodes");
  }
  for (int arc = 0; arc < n_arcs; ++arc) {
    if (cost[arc] < 0) {
      stop("arc costs must be nonnegative");
    }
  }

  std::vector<std::vector<int> > outgoing_arcs(n_nodes + 1);
  for (int arc = 0; arc < n_arcs; ++arc) {
    int tail = from[arc];
    if (tail < 1 || tail > n_nodes || to[arc] < 1 || to[arc] > n_nodes) {
      stop("from and to must be node ids in 1..n_nodes");
    }
    outgoing_arcs[tail].push_back(arc);
  }

  const double infinity = std::numeric_limits<double>::infinity();
  std::vector<double> distance(n_nodes + 1, infinity);
  std::vector<int> arc_into_node(n_nodes + 1, -1);
  std::vector<bool> settled(n_nodes + 1, false);

  typedef std::pair<double, int> distance_node;
  std::priority_queue<distance_node, std::vector<distance_node>,
                      std::greater<distance_node> >
      frontier;

  distance[origin] = 0.0;
  frontier.push(std::make_pair(0.0, origin));

  while (!frontier.empty()) {
    int node = frontier.top().second;
    frontier.pop();
    if (settled[node]) {
      continue;
    }
    settled[node] = true;
    if (node == destination) {
      break;
    }
    for (std::size_t index = 0; index < outgoing_arcs[node].size(); ++index) {
      int arc = outgoing_arcs[node][index];
      int head = to[arc];
      double candidate = distance[node] + cost[arc];
      if (candidate < distance[head]) {
        distance[head] = candidate;
        arc_into_node[head] = arc;
        frontier.push(std::make_pair(candidate, head));
      }
    }
  }

  IntegerVector incidence(n_arcs, 0);
  if (!settled[destination]) {
    incidence.attr("unreachable") = true;
    return incidence;
  }

  int node = destination;
  while (node != origin) {
    int arc = arc_into_node[node];
    incidence[arc] = 1;
    node = from[arc];
  }

  incidence.attr("unreachable") = false;
  return incidence;
}
