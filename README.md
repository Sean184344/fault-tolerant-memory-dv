# Fault-Tolerant Memory Subsystem — Design Verification

A simulation-based verification project for a 32-bit SECDED ECC-protected memory with background scrubbing and fault injection.

## Architecture

- Data width: 32 bits
- Codeword width: 39 bits
- Memory depth: 256 words
- Address width: 8 bits
- Error protection: SECDED
- Background scrubber scans valid words when no request is active.

## Verification

- SystemVerilog ECC and memory unit tests
- Randomized payload and memory tests
- Single-bit correction and double-bit detection
- Background scrubber repair tests
- Cocotb randomized regression
- Independent Python ECC reference model
- Exhaustive single-bit and double-bit fault injection for a selected codeword

## Run the tests

Activate the Python environment and run:

```bash
source .venv/bin/activate
./scripts/run_regression.sh
```

## Current status

Core RTL and simulation-based tests are implemented. Scrubber status and counter semantics require refinement. This version is not yet a UVM project; a SystemVerilog UVM environment is planned as a future extension.
