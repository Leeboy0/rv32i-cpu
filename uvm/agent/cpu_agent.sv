// uvm/agent/cpu_agent.sv — UVM agent: sequencer + driver + monitor

`ifndef CPU_AGENT_SV
`define CPU_AGENT_SV

class cpu_agent extends uvm_agent;
    `uvm_component_utils(cpu_agent)

    uvm_sequencer #(cpu_prog_item) sequencer;
    cpu_driver                     driver;
    cpu_monitor                    monitor;

    // Forwarded from monitor — connect to scoreboard and coverage
    uvm_analysis_port #(cpu_reg_trans) trans_ap;
    // Forwarded from driver — connect to scoreboard
    uvm_analysis_port #(cpu_prog_item) prog_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer = uvm_sequencer #(cpu_prog_item)::type_id::create("sequencer", this);
        driver    = cpu_driver::type_id::create("driver",    this);
        monitor   = cpu_monitor::type_id::create("monitor",  this);
        trans_ap  = new("trans_ap", this);
        prog_ap   = new("prog_ap",  this);
    endfunction

    function void connect_phase(uvm_phase phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
        monitor.ap.connect(trans_ap);
        driver.prog_ap.connect(prog_ap);
    endfunction

endclass : cpu_agent

`endif // CPU_AGENT_SV
