SIM = icarus
TOPLEVEL_LANG = verilog

TOPLEVEL = ecc_memory
COCOTB_TEST_MODULES = test_memory

VERILOG_SOURCES = \
    $(PWD)/rtl/ecc/ecc_encoder.sv \
    $(PWD)/rtl/ecc/ecc_decoder.sv \
    $(PWD)/rtl/memory/ecc_memory.sv


export PYTHONPATH := $(PWD)/tb/cocotb:$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim
