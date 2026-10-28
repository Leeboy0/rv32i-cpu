// uvm/tests/cpu_hazard_test.sv — load-use + forwarding stress test

`ifndef CPU_HAZARD_TEST_SV
`define CPU_HAZARD_TEST_SV

class cpu_hazard_test extends cpu_base_test;
    `uvm_component_utils(cpu_hazard_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        cpu_smoke_seq    smoke = cpu_smoke_seq::type_id::create("smoke");
        cpu_load_use_seq lu    = cpu_load_use_seq::type_id::create("lu");
        cpu_fwd_seq      fwd   = cpu_fwd_seq::type_id::create("fwd");
        phase.raise_objection(this);
        smoke.start(env.agent.sequencer);
        lu.start(env.agent.sequencer);
        fwd.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

`endif // CPU_HAZARD_TEST_SV
