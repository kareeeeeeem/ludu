# Rules and points contract

This is a documented Ludo variant, not a claim that all regional rule sets are identical.

- Two players use red/yellow opposite seats. Four use red/green/yellow/blue.
- Each player has four tokens. `-1` means base, `0..50` traverses 51 of the 52 shared circuit squares, `51..56` is the six-cell private lane, and `57` is the central home. A token turns from progress 50 into its own lane; the square just before its start remains part of the circuit for other colors.
- A six is required to enter at progress zero. Entry consumes the roll.
- Shared square = `(colorIndex * 13 + progress) % 52`.
- Safe shared squares are `0, 8, 13, 21, 26, 34, 39, 47`.
- Landing on opponents on an unsafe square returns all tokens on that square to base.
- Friendly stacks do not form blockades. Tokens can pass through one another.
- A six, capture, or reaching home grants another roll. Bonuses do not stack into multiple queued turns.
- On the third consecutive six, the latest roll is discarded and the turn passes. Previous moves remain.
- An unusable roll passes the turn, including an unusable six.
- Home requires an exact roll. Finished pieces never move.
- The first player with all four tokens home wins. The server generates dice with `crypto.randomInt`.
- Each roll-and-move turn has 30 seconds total. Extra rolls reset the clock.
- Timeouts pass the turn. Three missed turns without an intervening valid roll or move eliminate the player.
- Explicit forfeit removes the player immediately. With one active player remaining, that player wins.
- Disconnecting does not immediately forfeit. The same timeout rules apply, and reconnecting restores the persisted state.
- Waiting rooms expire after 30 minutes. Hosting requires all seats filled to start.

## Free points

- Registration: +100.
- Daily claim: +100 once every rolling 24 hours.
- Competitive victory: +25, issued once in the same MongoDB transaction as the result and statistics.
- Loss: no points deducted. Entry: free. Practice: no points or competitive stats.
- Admin corrections: signed integers, cannot make balances negative, require a reason and unique request ID.
- Points have no monetary value, cannot be purchased, transferred, withdrawn or redeemed.

Rankings use wins (then rating for all-time ties). Seven- and thirty-day boards count wins in rolling UTC time windows. Rating is an Elo-style update against average pairwise expected outcomes, with K=24. All-time win rate is wins divided by completed competitive games. Forfeits count as losses in competitive games.
