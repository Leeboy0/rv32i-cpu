// uvm/agent/cpu_prog_item.sv — stimulus: a program + run length

`ifndef CPU_PROG_ITEM_SV
`define CPU_PROG_ITEM_SV

class cpu_prog_item extends uvm_sequence_item;
    `uvm_object_utils(cpu_prog_item)

    // Program words to load into imem (index 0 = address 0x00000000)
    logic [31:0] imem [0:63];
    int unsigned prog_len;      // number of valid words
    int unsigned run_cycles;    // cycles to run after reset deasserts

    function new(string name = "cpu_prog_item");
        super.new(name);
        prog_len   = 0;
        run_cycles = 50;
    endfunction
endclass

`endif // CPU_PROG_ITEM_SV
