//***************************************************************************************************************
// UART Environment
//***************************************************************************************************************
`ifndef UART_ENV_SV
`define UART_ENV_SV

class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_agent       master_agt;
  uart_slave_agent slave_agt;
  sb               scoreboard;

  function new(string name = "uart_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    master_agt = uart_agent::type_id::create("master_agt", this);
    slave_agt  = uart_slave_agent::type_id::create("slave_agt", this);
    scoreboard = sb::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    master_agt.ap.connect(scoreboard.exp_imp);
    slave_agt.ap.connect(scoreboard.act_imp);
  endfunction

endclass

`endif
