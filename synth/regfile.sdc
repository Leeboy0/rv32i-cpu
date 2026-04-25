# synth/regfile.sdc
# Timing constraints for the RV32I register file
# Target: 5.0 ns period (200 MHz)

set CLK_PERIOD 5.0
set IO_BUDGET  [expr {$CLK_PERIOD * 0.1}] ;

# Primary clock
create_clock -name clk -period $CLK_PERIOD [get_ports clk]

# Input delays — model upstream logic taking IO_BUDGET of the period
set_input_delay -clock clk -max $IO_BUDGET \
    [remove_from_collection [all_inputs] [get_ports clk]]

# Output delays — model downstream logic needing IO_BUDGET of the period
set_output_delay -clock clk -max $IO_BUDGET [all_outputs]