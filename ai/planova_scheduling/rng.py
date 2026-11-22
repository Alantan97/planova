"""A tiny random-number generator that is identical in Python and Dart.

The app's Dart GA (lib/services/planning/ga_planner.dart) has a line-for-line
copy, so the same seed gives the same plan in both languages. Python's and
Dart's built-in generators differ, which is why neither is used.

xorshift32 (Marsaglia, 2003): only shifts, XORs and 32-bit masks, so it also
behaves the same when Dart is compiled to JavaScript. Statistical quality is
modest but plenty for a GA's choices.
"""

from __future__ import annotations

MASK = 0xFFFFFFFF


class Rng:
    def __init__(self, seed: int):
        state = (seed ^ 0x9E3779B9) & MASK
        self.state = state or 1
        for _ in range(8):  # move away from similar seeds
            self.next_u32()

    def next_u32(self) -> int:
        x = self.state
        x ^= (x << 13) & MASK
        x ^= x >> 17
        x ^= (x << 5) & MASK
        self.state = x
        return x

    def random(self) -> float:
        """A float in [0, 1)."""
        return self.next_u32() / 4294967296.0

    def below(self, n: int) -> int:
        """An integer in [0, n)."""
        return self.next_u32() % n

    def choice(self, items):
        return items[self.below(len(items))]

    def shuffle(self, items: list) -> None:
        """Fisher-Yates, from the end."""
        for i in range(len(items) - 1, 0, -1):
            j = self.below(i + 1)
            items[i], items[j] = items[j], items[i]

    def sample_indices(self, n: int, k: int) -> list[int]:
        """k distinct indices from range(n), in draw order."""
        pool = list(range(n))
        for t in range(k):
            j = t + self.below(n - t)
            pool[t], pool[j] = pool[j], pool[t]
        return pool[:k]
