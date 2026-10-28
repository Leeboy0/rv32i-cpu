// uvm/tests/cpu_smoke_test.sv — directed 5+3=8 smoke test

`ifndef CPU_SMOKE_TEST_SV
`define CPU_SMOKE_TEST_SV

class cpu_smoke_test extends cpu_base_test;
    `uvm_component_utils(cpu_smoke_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    task run_phase(uvm_phase phase);
        cpu_smoke_seq seq = cpu_smoke_seq::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agent.sequencer);
        phase.drop_objection(this);
    endtask
endclass

`endif // CPU_SMOKE_TEST_SV
