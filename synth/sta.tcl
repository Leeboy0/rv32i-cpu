# synth/sta.tcl
# OpenSTA driver script

set LIB     $::env(SKY130_LIB)
set TOP     regfile
set NETLIST build/${TOP}_netlist.v
set SDC     ${TOP}.sdc

read_liberty $LIB
read_verilog $NETLIST
link_design  $TOP
read_sdc     $SDC

puts "\n========== SETUP CHECK =========="
check_setup

puts "\n========== WORST SETUP PATH =========="
report_checks -path_delay max -fields {slew cap input_pins fanout} \
              -format full_clock_expanded

puts "\n========== WORST HOLD PATH =========="
report_checks -path_delay min -fields {slew cap input_pins fanout} \
              -format full_clock_expanded

puts "\n========== TIMING SUMMARY =========="
report_wns
report_tns
puts "\nNote: min achievable period = current_period - WNS"
puts "Note: cell area is reported by Yosys (see build/yosys.log)"