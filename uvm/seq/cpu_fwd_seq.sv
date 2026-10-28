// uvm/seq/cpu_fwd_seq.sv — EX/MEM forwarding: back-to-back ALU → dependent ALU

`ifndef CPU_FWD_SEQ_SV
`define CPU_FWD_SEQ_SV

class cpu_fwd_seq extends uvm_sequence #(cpu_prog_item);
    `uvm_object_utils(cpu_fwd_seq)
    function new(string name = "cpu_fwd_seq"); super.new(name); endfunction

    task body();
        cpu_prog_item item = cpu_prog_item::type_id::create("item");
        start_item(item);
        item.imem[0]   = 32'h00A00093; // addi x1, x0, 10
        item.imem[1]   = 32'h00108113; // addi x2, x1,  1   ← MEM/WB forward (x1)
        item.imem[2]   = 32'h00208193; // addi x3, x1,  2   ← MEM/WB forward (x1)
        item.imem[3]   = 32'h002101B3; // add  x3, x2, x2   ← EX/MEM forward (x2)
        item.imem[4]   = 32'h0000006F; // jal  x0, 0
        item.prog_len  = 5;
        item.run_cycles = 40;
        finish_item(item);
    endtask
endclass

`endif // CPU_FWD_SEQ_SV
