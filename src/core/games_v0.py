import nashpy as nash

A = [[3, 0], [5, 1]]
B = [[3, 5], [0, 1]]

g = nash.Game(A, B)
print(g)

row_strats = ["Cooperate", "Defect"]
col_strats = ["Cooperate", "Defect"]


def label(vec, labels):
    return {labels[i]: float(p) for i, p in enumerate(vec)}


print("Support enumeration equilibria:")
for x, y in g.support_enumeration():
    print("Row:", label(x, row_strats), "| Col:", label(y, col_strats))

print("\nLemke–Howson (label=0) equilibrium:")
x, y = g.lemke_howson(initial_dropped_label=0)
print("Row:", label(x, row_strats), "| Col:", label(y, col_strats))
