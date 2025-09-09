import nashpy as nash

A = [[3, 0], [5, 1]]
B = [[3, 5], [0, 1]]

row_strats = ["A", "B"]
col_strats = ["A", "B"]


def pure_strategy(vec, labels):
    for s, p in zip(labels, vec):
        if abs(p - 1.0) < 1e-12:
            return s
    return None


def show(vec, labels):
    active = [f"{s}:{p:.2f}" for s, p in zip(labels, vec) if p > 0]
    return ", ".join(active)


g = nash.Game(A, B)

results = {"game": g, "ne": []}

for x, y in g.support_enumeration():
    row = pure_strategy(x, row_strats)
    col = pure_strategy(y, col_strats)
    results["ne"].append(row + col)  # e.g. "BB"

print(results)
