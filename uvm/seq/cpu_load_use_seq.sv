// uvm/seq/cpu_load_use_seq.sv — Load-use hazard: LW immediately followed by dependent ADD

`ifndef CPU_LOAD_USE_SEQ_SV
`define CPU_LOAD_USE_SEQ_SV

class cpu_load_use_seq extends uvm_sequence #(cpu_prog_item);
    `uvm_object_utils(cpu_load_use_seq)
    function new(string name = "cpu_load_use_seq"); super.new(name); endfunction

    task body();
        cpu_prog_item item = cpu_prog_item::type_id::create("item");
        start_item(item);
        item.imem[0]   = 32'h02A00093; // addi x1, x0, 42
        item.imem[1]   = 32'h00102023; // sw   x1, 0(x0)    store 42 → dmem[0]
        item.imem[2]   = 32'h00002103; // lw   x2, 0(x0)    load  42 → x2
        item.imem[3]   = 32'h00210133; // add  x2, x2, x2   ← load-use hazard; expects 84
        item.imem[4]   = 32'h0000006F; // jal  x0, 0
        item.prog_len  = 5;
        item.run_cycles = 40;
        finish_item(item);
    endtask
endclass

`endif // CPU_LOAD_USE_SEQ_SV
