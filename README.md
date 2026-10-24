# Fault-Tolerant Memory Subsystem: ECC, Scrubbing and Error Injection

A simulation-based Design Verification project for a memory subsystem protected by **Single Error Correction, Double Error Detection (SECDED) ECC**, with fault injection, automatic scrubbing, and SystemVerilog/Cocotb regression testing.

**Repository:** [fault-tolerant-memory-dv](https://github.com/Sean184344/fault-tolerant-memory-dv)

## Table of Contents

- [Overview](#overview)
- [Objectives](#objectives)
- [Architecture](#architecture)
- [ECC Design](#ecc-design)
- [Verification Environment](#verification-environment)
- [Verification Results](#verification-results)
- [Getting Started](#getting-started)
- [Repository Structure](#repository-structure)
- [Known Limitations and Future Work](#known-limitations-and-future-work)
- [Technical Skills Demonstrated](#technical-skills-demonstrated)

## Overview

Memory corruption can result from transient hardware faults, soft errors, and other bit-flip events. Error-correcting codes help preserve data integrity by detecting and, within their correction capability, repairing corrupted memory words.

This project implements a behavioral memory subsystem with a 32-bit data path protected by a 7-bit SECDED code. The memory supports normal read/write transactions, error detection and correction on reads, and background scrubbing to repair correctable errors in stored codewords.

The primary focus is **design verification rather than synthesis or physical implementation**. The verification environment combines directed SystemVerilog testbenches, randomized Cocotb testing, systematic fault injection, and an independent Python reference model.

### Key Features

- 32-bit payload with 7 ECC bits per word.
- SECDED encoding and decoding.
- 256-word behavioral memory with an 8-bit address.
- Detection and correction of single-bit errors.
- Detection of double-bit errors.
- Fault injection for systematic error testing.
- Background scrubbing of valid memory words.
- Independent Python reference model for checking RTL behavior.
- Automated regression script combining SystemVerilog and Cocotb tests.

## Objectives

The project is designed to exercise practical verification techniques used in RTL and Design Verification workflows:

1. Verify ECC encoder and decoder behavior against expected results.
2. Validate correct memory read/write operation.
3. Inject bit-flip faults and check error classification.
4. Verify that correctable errors do not corrupt the returned payload.
5. Check that background scrubbing repairs correctable errors in stored codewords.
6. Exercise the memory using randomized transaction sequences.
7. Compare RTL results with an independently implemented software reference model.
8. Automate the regression so that failures can be reproduced consistently.

## Architecture

The subsystem contains three primary RTL modules:

- **ECC encoder:** Generates the ECC bits for each 32-bit payload.
- **Memory subsystem:** Stores encoded words and manages memory transactions and background scrubbing.
- **ECC decoder:** Calculates the syndrome, classifies detected errors, and corrects single-bit errors.

Conceptual data flow:

```text
              Write Data (32 bits)
                       |
                       v
                +-------------+
                | ECC Encoder |
                +-------------+
                       |
                       v
              39-bit Codeword
                       |
                       v
                +-------------+
                |   Memory    |<---- Fault Injection
                | 256 x 39    |
                +-------------+
                       |
                       v
                +-------------+
                | ECC Decoder |
                +-------------+
                       |
             +---------+---------+
             |                   |
             v                   v
       Corrected Data       Error Status
          (32 bits)       Single / Double
```

The background scrubber scans valid memory words when normal requests do not take priority. Correctable codewords can be rewritten with their repaired values.

The diagram describes the intended functional data flow; it is not a timing diagram or a physical implementation schematic.

## ECC Design

### Codeword format

| Property | Configuration |
|---|---|
| Payload width | 32 bits |
| ECC width | 7 bits |
| Total codeword width | 39 bits |
| Memory depth | 256 words |
| Address width | 8 bits |
| Error-correction scheme | SECDED |

The implementation uses Hamming parity positions 1, 2, 4, 8, 16, and 32 across positions 1–38. The remaining positions in that range hold payload bits. Position 39 contains the overall parity bit.

### Error-handling behavior

| Fault condition | Expected behavior |
|---|---|
| No bit errors | Return the original payload without correction |
| One flipped bit | Detect and correct the error |
| Two flipped bits | Detect the double-bit error |
| Correctable error in stored memory | Allow the scrubber to repair the stored codeword |

SECDED provides single-bit correction and double-bit detection within the assumptions of the implemented code. This project does not claim correction of arbitrary multi-bit errors.

## Verification Environment

The project uses a layered, simulation-based verification approach.

### 1. SystemVerilog unit tests

The directed ECC testbench checks clean payloads, single-bit correction, double-bit detection, and randomized payload patterns.

The memory testbench checks basic transactions, error handling, correction, and scrubber repair behavior.

### 2. Cocotb verification

Cocotb drives the RTL through a Python-based testbench. The current regression includes two tests.

**Randomized memory test**

- Writes 256 initial words.
- Reads the words in shuffled order.
- Executes 1,000 randomized mixed operations.
- Injects a single-bit fault and checks correction.
- Checks background scrubber repair.
- Injects a double-bit fault and checks detection.

The randomized sequence uses a fixed seed (`20261023`) to make the generated sequence reproducible.

**Systematic ECC fault test**

- Uses the payload `0xDEADBEEF` at address 10.
- Tests all 39 single-bit fault positions.
- Tests all 741 unique two-bit fault combinations.
- Compares RTL error flags with the independent Python reference model.
- Checks payload correctness for single-bit correction cases.

### 3. Independent reference model

`tb/cocotb/ecc_reference.py` provides a Python implementation of the ECC encoding and decoding behavior. It is used as a reference for checking RTL results rather than relying solely on expected values generated by the DUT itself.

The reference model has also been self-checked against clean, single-bit-error, and double-bit-error cases.

### 4. Automated regression

The script `scripts/run_regression.sh` runs the SystemVerilog ECC tests, SystemVerilog memory tests, and Cocotb regression in sequence.

A failing command stops the script because it uses `set -euo pipefail`.

## Verification Results

The latest recorded regression completed successfully with the following results.

| Verification item | Result |
|---|---:|
| Clean ECC payload patterns | 104 |
| Single-bit ECC correction checks | 4,056 |
| Double-bit ECC detection checks | 77,064 |
| Randomized ECC payloads | 100 |
| Systematic single-bit fault cases | 39 |
| Systematic double-bit fault cases | 741 |
| Randomized memory operations | 1,000 |
| Cocotb tests | 2 passed, 0 failed |
| Memory scrubber repairs observed in directed test | 1 |

The SystemVerilog ECC testbench reported `ALL ECC TESTS PASSED`. The memory testbench reported `ALL MEMORY TESTS PASSED`, and the automated regression ended with `ALL REGRESSION TESTS PASSED`.

These figures describe executed test cases and operations. They are **not** a claim of formal proof, code coverage closure, or complete functional coverage.

## Getting Started

### Prerequisites

The current setup uses:

- Linux or WSL with Ubuntu.
- Icarus Verilog 12.0.
- Python and a virtual environment.
- Cocotb 2.1.0.
- GNU Make.

The current Cocotb setup uses Icarus Verilog as the simulator.

### 1. Clone the repository

```bash
git clone https://github.com/Sean184344/fault-tolerant-memory-dv.git
cd fault-tolerant-memory-dv
```

### 2. Set up the Python environment

If the virtual environment already exists:

```bash
source .venv/bin/activate
```

Otherwise, create it and install Cocotb:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install cocotb==2.1.0
```

Ensure Icarus Verilog and GNU Make are installed and available on your `PATH`.

### 3. Run the full regression

From the repository root:

```bash
chmod +x scripts/run_regression.sh
./scripts/run_regression.sh
```

A successful run ends with:

```text
========================================
ALL REGRESSION TESTS PASSED
========================================
```

The Icarus Verilog simulator may emit nonfatal warnings about constant selects in `always_*` processes. Check the final test results to determine whether the regression passed.

## Repository Structure

```text
fault-tolerant-memory-dv/
├── rtl/
│   ├── ecc/
│   │   ├── ecc_encoder.sv
│   │   └── ecc_decoder.sv
│   └── memory/
│       └── ecc_memory.sv
├── tb/
│   ├── unit/
│   │   ├── tb_ecc.sv
│   │   └── tb_memory.sv
│   └── cocotb/
│       ├── Makefile
│       ├── test_memory.py
│       └── ecc_reference.py
├── docs/
│   ├── verification_plan.md
│   └── test_matrix.md
├── scripts/
│   └── run_regression.sh
├── .gitignore
└── README.md
```

## Known Limitations and Future Work

This is an evolving verification project. The current passing regression establishes a useful baseline, but it does not establish that every corner case has been verified.

Planned improvements include:

- Review and correct the `scrub_busy` signal behavior.
- Review double-error counter semantics and counter-update conditions.
- Add reset-focused tests and additional scrubber/request concurrency scenarios.
- Expand memory-level fault-injection scenarios and assertions.
- Add functional coverage collection and coverage-oriented test closure.
- Extend the environment to a SystemVerilog UVM testbench with reusable agents, sequences, monitors, a scoreboard, and functional coverage.
- Evaluate a UVM-capable simulator before beginning the UVM migration.

The existing environment is **SystemVerilog plus Cocotb; it is not yet a UVM environment**. UVM is a planned extension, not a currently implemented feature.

## Technical Skills Demonstrated

- SystemVerilog RTL verification.
- ECC fundamentals and SECDED error classification.
- Directed and randomized testing.
- Fault injection and systematic fault enumeration.
- Python reference-model development.
- Cocotb-based verification.
- Memory transaction checking.
- Regression automation with shell scripting.
- Test planning and verification documentation.
- Reproducible simulation workflows using Linux/WSL.

---

**Project status:** Simulation-based DV baseline with passing directed and Cocotb regression tests. Further RTL hardening and a future UVM extension remain planned work.
