import numpy as np
from typing import Callable


def U(a: float, b: float) -> Callable[[np.random.Generator], float]:
    """Uniform gap sampler."""
    return lambda rng: float(rng.uniform(a, b))


def LN(mu: float, sigma: float) -> Callable[[np.random.Generator], float]:
    """Lognormal gap sampler (always >0)."""
    return lambda rng: float(rng.lognormal(mu, sigma))


###


def sample_pd(
    seed=None,
    gap=U(0.2, 1.0),
    s_zero=True,
):
    rng = np.random.default_rng(seed)
    S = 0.0 if s_zero else gap(rng)

    # keep drawing until gT < gP + gR
    while True:
        gP, gR, gT = gap(rng), gap(rng), gap(rng)
        if gT < gP + gR:
            break

    P = S + gP
    R = P + gR
    T = R + gT
    return {"R": R, "S": S, "T": T, "P": P}


def build_pd_lists(pay):
    A = np.array([[pay["R"], pay["S"]], [pay["T"], pay["P"]]], float)
    B = A.T.copy()
    return A.tolist(), B.tolist()  # JSON-safe at the edge


# def orientations4(A, B):
#    A = np.array(A, float)
#    B = np.array(B, float)
#
#    variants = [
#        ("rot0",   A,                     B),
#        ("rot90",  B.T,                   A.T),                   # swap players
#        ("rot180", A[::-1, ::-1],         B[::-1, ::-1]),
#        ("rot270", B.T[::-1, ::-1],       A.T[::-1, ::-1]),       # swap players
#    ]
#
#    return [(name, a.tolist(), b.tolist()) for name, a, b in variants]


def label_pd(pay: dict[str, float]):
    """
    Create a labeled view of Prisoner's Dilemma payoffs.

    Input:
      pay = {"R": ..., "S": ..., "T": ..., "P": ...}

    Output:
      {("C","C"): {"role": "R", "payoff": (R, R)},
       ("C","D"): {"role": "S", "payoff": (S, T)},
       ("D","C"): {"role": "T", "payoff": (T, S)},
       ("D","D"): {"role": "P", "payoff": (P, P)}}
    """
    return {
        ("C", "C"): {"role": "R", "payoff": (pay["R"], pay["R"])},
        ("C", "D"): {"role": "S", "payoff": (pay["S"], pay["T"])},
        ("D", "C"): {"role": "T", "payoff": (pay["T"], pay["S"])},
        ("D", "D"): {"role": "P", "payoff": (pay["P"], pay["P"])},
    }
