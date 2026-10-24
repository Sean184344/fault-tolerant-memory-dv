# Verification Test Matrix

| ID | Scenario | Method | Expected result |
|---|---|---|---|
| ECC-01 | Clean payload | SystemVerilog | Original data recovered |
| ECC-02 | Single-bit corruption | SystemVerilog | Corrected and flagged |
| ECC-03 | Double-bit corruption | SystemVerilog | Double error detected |
| ECC-04 | Random payloads | SystemVerilog | No unexpected mismatches |
| MEM-01 | Basic read/write | SystemVerilog | Data matches stored value |
| MEM-02 | Single-bit read correction | SystemVerilog | Original data returned |
| MEM-03 | Scrubber repair | SystemVerilog | Stored codeword repaired |
| MEM-04 | Double-bit detection | SystemVerilog | Double error reported |
| MEM-05 | Rewrite after corruption | SystemVerilog | New data returned |
| COC-01 | Randomized memory traffic | Cocotb | Reference data matches |
| COC-02 | Single-bit fault injection | Cocotb | RTL agrees with model |
| COC-03 | Double-bit fault injection | Cocotb | RTL agrees with model |
| COC-04 | Scrubber repair check | Cocotb | Correctable fault repaired |

Reset corner cases, counter semantics, concurrency, and comprehensive functional coverage remain follow-up work.
