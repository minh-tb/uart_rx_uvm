//***************************************************************************************************************
// UART Slave Agent
//***************************************************************************************************************
`ifndef UART_SLAVE_AGENT_SV
`define UART_SLAVE_AGENT_SV

import uart_tlm_pkg::*;

class uart_slave_agent extends uvm_agent;
  `uvm_component_utils(uart_slave_agent)

  uart_slave_monitor monitor;
  uvm_analysis_port #(uart_tlm) ap;

  function new(string name = "uart_slave_agent", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = uart_slave_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    monitor.ap.connect(ap);
  endfunction

endclass

`endif
