//***************************************************************************************************************
// UART Slave Monitor
//***************************************************************************************************************
`ifndef UART_SLAVE_MONITOR_SV
`define UART_SLAVE_MONITOR_SV

import uart_tlm_pkg::*;

class uart_slave_monitor extends uvm_monitor;
  `uvm_component_utils(uart_slave_monitor)

  virtual uart_if vif;
  uvm_analysis_port #(uart_tlm) ap;

  function new(string name = "uart_slave_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "UART_VIF", vif)) begin
      if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", vif)) begin
        `uvm_fatal(get_type_name(), "Could not get virtual interface UART_VIF from config_db")
      end
    end
  endfunction

  task run_phase(uvm_phase phase);
    uart_tlm pkt;
    forever begin
      @(posedge vif.clk);
      if (vif.o_valid === 1'b1) begin
        pkt = uart_tlm::type_id::create("pkt");
        pkt.data       = vif.o_data;
        pkt.o_data     = vif.o_data;
        pkt.in_rx_data = vif.o_data;
        pkt.o_valid    = 1'b1;
        `uvm_info(get_type_name(), $sformatf("Detected o_valid=1: Captured output byte o_data = 0x%02h (%08b)", pkt.data, pkt.data), UVM_LOW)
        ap.write(pkt);
      end
    end
  endtask

endclass

`endif
