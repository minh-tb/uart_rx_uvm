//***************************************************************************************************************
// UART Master Agent
//***************************************************************************************************************
`ifndef UART_AGENT_SV
`define UART_AGENT_SV

import uart_tlm_pkg::*;

class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)

  uart_driver driver;
  uvm_sequencer #(uart_tlm) sequencer;
  uvm_analysis_port #(uart_tlm) ap;

  function new(string name = "uart_agent", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver = uart_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer#(uart_tlm)::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
      driver.ap.connect(ap);
    end
  endfunction

endclass

`endif
