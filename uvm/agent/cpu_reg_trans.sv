// uvm/agent/cpu_reg_trans.sv — observed register-write retirement event

`ifndef CPU_REG_TRANS_SV
`define CPU_REG_TRANS_SV

class cpu_reg_trans extends uvm_sequence_item;
    `uvm_object_utils(cpu_reg_trans)

    logic [4:0]  rd;       // register written (1..31)
    logic [31:0] rd_val;   // new value
    int unsigned cycle;    // for debug logging

    function new(string name = "cpu_reg_trans");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("cyc=%0d  x%0d = %08h", cycle, rd, rd_val);
    endfunction
endclass

`endif // CPU_REG_TRANS_SV
