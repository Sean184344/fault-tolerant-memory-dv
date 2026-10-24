# Verification Plan

## Objective
Verify functional correctness and fault-handling behavior of the ECC-protected memory using self-checking simulation.

## Verification methods
- Directed SystemVerilog unit tests
- Randomized payload testing
- Directed memory read/write transactions
- Cocotb randomized memory traffic
- Single-bit and double-bit fault injection
- Comparison against an independent Python ECC reference model

## Main scenarios
1. Clean ECC encoding and decoding.
2. Single-bit error correction.
3. Double-bit error detection.
4. Memory read/write behavior.
5. Read-time error correction.
6. Background scrubber repair.
7. Recovery after rewriting a corrupted location.
8. Randomized memory transactions.
9. RTL/reference-model agreement.

## Known gaps
Scrubber status, counter semantics, reset corner cases, and interactions between requests and background scrubbing need further testing. This is simulation-based verification, not a formal proof.
