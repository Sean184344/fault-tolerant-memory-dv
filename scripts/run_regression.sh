#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "========================================"
echo "1/3: SystemVerilog ECC unit tests"
echo "========================================"
iverilog -g2012 -s tb_ecc -o /tmp/ecc_memory_tb_ecc.vvp \
    rtl/ecc/ecc_encoder.sv \
    rtl/ecc/ecc_decoder.sv \
    tb/unit/tb_ecc.sv
vvp /tmp/ecc_memory_tb_ecc.vvp

echo "========================================"
echo "2/3: SystemVerilog memory tests"
echo "========================================"
iverilog -g2012 -s tb_memory -o /tmp/ecc_memory_tb_memory.vvp \
    rtl/ecc/ecc_encoder.sv \
    rtl/ecc/ecc_decoder.sv \
    rtl/memory/ecc_memory.sv \
    tb/unit/tb_memory.sv
vvp /tmp/ecc_memory_tb_memory.vvp

echo "========================================"
echo "3/3: Cocotb regression"
echo "========================================"
make -f tb/cocotb/Makefile

echo "========================================"
echo "ALL REGRESSION TESTS PASSED"
echo "========================================"
