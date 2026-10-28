// uvm/tests/cpu_base_test.sv — base test (builds env)

`ifndef CPU_BASE_TEST_SV
`define CPU_BASE_TEST_SV

class cpu_base_test extends uvm_test;
    `uvm_component_utils(cpu_base_test)
    cpu_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cpu_env::type_id::create("env", this);
    endfunction
endclass

`endif // CPU_BASE_TEST_SV
