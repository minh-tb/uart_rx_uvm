//***************************************************************************************************************
// Base Test & Demo Test
//***************************************************************************************************************
`ifndef UART_DEMO_TEST_SV
`define UART_DEMO_TEST_SV

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  uart_env env;

  function new(string name = "base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
  endfunction

endclass

class uart_demo_test extends base_test;
  `uvm_component_utils(uart_demo_test)

  function new(string name = "uart_demo_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    uart_demo_seq seq;
    phase.raise_objection(this, "Objection raised by uart_demo_test");

    seq = uart_demo_seq::type_id::create("seq");
    `uvm_info(get_type_name(), "Starting uart_demo_test sequence execution", UVM_LOW)

    // Wait a brief initial duration for system stability
    #100ns;

    seq.start(env.master_agt.sequencer);

    // Wait for the last packet to finish receiving through DUT
    #50us;

    `uvm_info(get_type_name(), "Finished uart_demo_test sequence execution", UVM_LOW)
    phase.drop_objection(this, "Objection dropped by uart_demo_test");
  endtask

endclass

`endif
