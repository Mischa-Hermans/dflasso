# the summary render is stable

    Code
      summary(fit)
    Output
      Summary of a decision-focused cost model (dflasso)
      Objective: maximise value over 12 instances scored, 6 features.
      
      FEATURES KEPT
        6 of 6 features were kept for the decision.
        3 of these are decision-driven rescues, weak at predicting cost on their own, but
        they move the decision, so the model kept them:
            feat_01, feat_05, feat_06
        See tidy(fit) for every feature, its coefficient, and its role.
      
      WHAT EACH FEATURE IS FOR  (across all features, by how they behave)
        decision-relevant   3    were kept for the decision (rescued by the decision step)
        prediction-relevant 2    were kept by the accuracy step (the usual reason)
        both                1    do both
        neither             0    not used by either model
        These roles come from one random reshuffle of the instances, so they can
        shift a little under a different seed. Judge a feature by its score in
        tidy(fit), not by the bare label.
      
      DOES THE DECISION FOCUS PAY OFF?  (lower regret is better)
        Regret = how much worse a decision was than the best possible in
        hindsight, averaged over instances.
        This needs held-out data. Run regret(fit, x_test, cost_test,
        scenario_test) to compare against the prediction-focused model.
        See ?dflasso-validation.
      
      HOW HARD FEATURES WERE FILTERED
        Filtering strength 0.002, chosen automatically by trying many settings and
        keeping the best; smaller keeps more features. (this setting is called
        lambda)
      
      REPRODUCIBILITY
        Fit with seed 1; re-running with this seed gives bit-identical features,
        scores, and decisions. Pass seed = <int> to fix it up front and quote
        that number.
        Decision quality was averaged over 3 random reshuffles of the instances.
      
      SETTINGS
        main  : features put on a common scale, 10-fold cross-validation, instances must have >= 2 elements.
        method: n_splits = 3 (rest at defaults).

