// uvm/agent/cpu_monitor.sv — diffs the regfile mirror each cycle
//
//  Design note: the monitor compares regs[] to a local snapshot.
//  Any register that changed since the last cycle is reported as a
//  cpu_reg_trans.  This detects WB-stage retirements without any
//  DUT modification.

`ifndef CPU_MONITOR_SV
`define CPU_MONITOR_SV

class cpu_monitor extends uvm_monitor;
    `uvm_component_utils(cpu_monitor)

    virtual cpu_if       vif;
    uvm_analysis_port #(cpu_reg_trans) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db #(virtual cpu_if)::get(this, "", "vif", vif))
            `uvm_fatal("CFG", "cpu_if not found in config DB")
    endfunction

    task run_phase(uvm_phase phase);
        logic [31:0] prev_regs [0:31] = '{default: '0};
        int unsigned cyc = 0;

        forever begin
            @(vif.mon_cb);

            if (!vif.mon_cb.rst_n) begin
                // Reset: clear local snapshot
                foreach (prev_regs[i]) prev_regs[i] = '0;
                cyc = 0;
                continue;
            end
            cyc++;

            // Diff: report every non-x0 register that changed
            for (int i = 1; i < 32; i++) begin
                if (vif.mon_cb.regs[i] !== prev_regs[i]) begin
                    cpu_reg_trans t = cpu_reg_trans::type_id::create("t");
                    t.rd     = 5'(i);
                    t.rd_val = vif.mon_cb.regs[i];
                    t.cycle  = cyc;
                    ap.write(t);
                    `uvm_info("MON", t.convert2string(), UVM_HIGH)
                end
            end
            prev_regs = vif.mon_cb.regs;
        end
    endtask

endclass : cpu_monitor

`endif // CPU_MONITOR_SV
