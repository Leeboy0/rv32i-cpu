# synth/Makefile
# Synthesis + STA flow for individual RTL modules
# Usage: make synth | make sta | make all | make clean

SHELL := /bin/bash

TOP       := regfile
RTL_DIR   := ../rtl
BUILD_DIR := build

SV_SRC    := $(RTL_DIR)/$(TOP).sv
V_SRC     := $(BUILD_DIR)/$(TOP).v
NETLIST   := $(BUILD_DIR)/$(TOP)_netlist.v
LIB       := $(SKY130_LIB)

.PHONY: all synth sta clean check

all: sta

check:
ifndef SKY130_LIB
	$(error SKY130_LIB is not set — check ~/.bashrc)
endif

# Step 1: SystemVerilog -> Verilog-2005
$(V_SRC): $(SV_SRC) | $(BUILD_DIR)
	@echo "=== sv2v: $(SV_SRC) -> $@ ==="
	sv2v $< -w $@

# Step 2: Yosys synthesis to Sky130 standard cells
$(NETLIST): $(V_SRC) | check
	@echo "=== Yosys: synthesizing $(TOP) ==="
	yosys -l $(BUILD_DIR)/yosys.log -p "\
		read_verilog $(V_SRC); \
		hierarchy -check -top $(TOP); \
		synth -top $(TOP) -flatten; \
		dfflibmap -liberty $(LIB); \
		abc -liberty $(LIB); \
		clean -purge; \
		stat -liberty $(LIB); \
		write_verilog -noattr $@"

synth: $(NETLIST)

# Step 3: OpenSTA timing analysis
sta: $(NETLIST) $(TOP).sdc sta.tcl | check
	@echo "=== OpenSTA: timing analysis ==="
	sta -no_init -no_splash -exit sta.tcl 2>&1 | tee $(BUILD_DIR)/sta.log

$(BUILD_DIR):
	@mkdir -p $@

clean:
	rm -rf $(BUILD_DIR)