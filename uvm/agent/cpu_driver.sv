// uvm/agent/cpu_driver.sv — loads imem via backdoor signals, drives rst_n

`ifndef CPU_DRIVER_SV
`define CPU_DRIVER_SV

class cpu_driver extends uvm_driver #(cpu_prog_item);
    `uvm_component_utils(cpu_driver)

    virtual cpu_if vif;

    // Broadcasts each loaded item to the scoreboard so it can reset
    // its reference model with the same program
    uvm_analysis_port #(cpu_prog_item) prog_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        prog_ap = new("prog_ap", this);
        if (!uvm_config_db #(virtual cpu_if)::get(this, "", "vif", vif))
            `uvm_fatal("CFG", "cpu_if not found in config DB")
    endfunction

    task run_phase(uvm_phase phase);
        // Idle defaults
        vif.drv_cb.rst_n      <= 0;
        vif.drv_cb.imem_wr_en <= 0;
        @(vif.drv_cb);

        forever begin
            cpu_prog_item item;
            seq_item_port.get_next_item(item);
            drive(item);
            seq_item_port.item_done();
        end
    endtask

    task drive(cpu_prog_item item);
        // 1. Assert reset
        vif.drv_cb.rst_n <= 0;
        repeat (2) @(vif.drv_cb);

        // 2. Backdoor-write program into imem word by word.
        //    tb_top propagates imem_wr_* signals to dut.u_imem.mem.
        for (int i = 0; i < int'(item.prog_len); i++) begin
            vif.drv_cb.imem_wr_addr <= 12'(i);
            vif.drv_cb.imem_wr_data <= item.imem[i];
            vif.drv_cb.imem_wr_en   <= 1;
            @(vif.drv_cb);
        end
        vif.drv_cb.imem_wr_en <= 0;

        // 3. Tell scoreboard which program we just loaded
        prog_ap.write(item);

        // 4. Deassert reset
        repeat (2) @(vif.drv_cb);
        vif.drv_cb.rst_n <= 1;

        // 5. Let CPU run
        repeat (item.run_cycles) @(vif.drv_cb);
    endtask

endclass : cpu_driver

`endif // CPU_DRIVER_SV
