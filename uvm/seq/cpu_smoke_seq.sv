// uvm/seq/cpu_smoke_seq.sv — Smoke test: 5 + 3 = 8 → x3

`ifndef CPU_SMOKE_SEQ_SV
`define CPU_SMOKE_SEQ_SV

class cpu_smoke_seq extends uvm_sequence #(cpu_prog_item);
    `uvm_object_utils(cpu_smoke_seq)
    function new(string name = "cpu_smoke_seq"); super.new(name); endfunction

    task body();
        cpu_prog_item item = cpu_prog_item::type_id::create("item");
        start_item(item);
        item.imem[0]   = 32'h00500093; // addi x1, x0, 5
        item.imem[1]   = 32'h00300113; // addi x2, x0, 3
        item.imem[2]   = 32'h002081B3; // add  x3, x1, x2
        item.imem[3]   = 32'h0000006F; // jal  x0, 0  (loop)
        item.prog_len  = 4;
        item.run_cycles = 30;
        finish_item(item);
    endtask
endclass

`endif // CPU_SMOKE_SEQ_SV
