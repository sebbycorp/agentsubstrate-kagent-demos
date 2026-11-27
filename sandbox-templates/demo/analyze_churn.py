"""What drove churn last quarter? Standard library only, so it runs in a
sandbox that has no network access and no extra packages."""
import csv
import json
from collections import defaultdict

rows = list(csv.DictReader(open("churn.csv")))


def churn_rate(group):
    return round(100 * sum(r["churned"] == "yes" for r in group) / len(group), 1)


def by(key):
    groups = defaultdict(list)
    for r in rows:
        groups[key(r)].append(r)
    return {k: {"customers": len(g), "churn_pct": churn_rate(g)}
            for k, g in sorted(groups.items())}


report = {
    "customers": len(rows),
    "overall_churn_pct": churn_rate(rows),
    "by_plan": by(lambda r: r["plan"]),
    "by_onboarding": by(lambda r: "onboarded" if r["completed_onboarding"] == "yes" else "not onboarded"),
    "by_support_tickets": by(lambda r: "5+ tickets" if int(r["support_tickets"]) >= 5 else "0-4 tickets"),
    "mrr_lost_usd": sum(int(r["mrr_usd"]) for r in rows if r["churned"] == "yes"),
}
json.dump(report, open("report.json", "w"), indent=2)
print(json.dumps(report, indent=2))
