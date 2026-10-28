# uvm/Makefile — compile and simulate the UVM testbench
#
# Supported simulators:
#   make questa   (Siemens Questa FSE / Altera Starter, called from WSL)
#
# Select test with TEST=<name>  (default: cpu_smoke_test)
# Examples:
#   make questa TEST=cpu_hazard_test

TEST     ?= cpu_smoke_test
RTL_DIR  := ../rtl
UVM_ARGS  = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM

RTL_SRCS  = $(RTL_DIR)/alu.sv        \
            $(RTL_DIR)/regfile.sv     \
            $(RTL_DIR)/imm_gen.sv     \
            $(RTL_DIR)/control.sv     \
            $(RTL_DIR)/branch_unit.sv \
            $(RTL_DIR)/imem.sv        \
            $(RTL_DIR)/dmem.sv        \
            $(RTL_DIR)/cpu.sv

UVM_DIRS  = agent ref_model env seq tests tb
UVM_INCS  = $(wildcard $(addsuffix /*.sv,$(UVM_DIRS)))   # `included by cpu_pkg.sv
UVM_SRCS  = tb/cpu_if.sv cpu_pkg.sv tb/tb_top.sv

# ── Siemens Questa FSE (Altera Starter), invoked from WSL ─────────────
QUESTA_HOME ?= /mnt/c/altera_lite/25.1std/questa_fse
UVM_SRC := $(QUESTA_HOME)/verilog_src/uvm-1.2/src
VLIB = $(QUESTA_HOME)/win64/vlib.exe
VLOG = $(QUESTA_HOME)/win64/vlog.exe
VSIM = $(QUESTA_HOME)/win64/vsim.exe

questa: $(RTL_SRCS) $(UVM_SRCS) $(UVM_INCS)
	$(VLIB) work
	$(VLOG) -sv -mfcu -suppress 12110 \
	    +incdir+$(shell wslpath -m $(UVM_SRC)) \
	    $(foreach d,$(UVM_DIRS),+incdir+$(d)) \
	    $(shell wslpath -m $(UVM_SRC)/uvm_pkg.sv) \
	    $(foreach f,$(RTL_SRCS),$(shell wslpath -m $(f))) \
	    $(foreach f,$(UVM_SRCS),$(shell wslpath -m $(f)))
	$(VSIM) -c -uvmcontrol=all tb_top $(UVM_ARGS) -do "run -all; quit"

# ── Clean ─────────────────────────────────────────────────────────────
.PHONY: clean questa
clean:
	rm -rf simv simv.daidir csrc ucli.key work transcript *.log *.vcd *.wlf DVEfiles