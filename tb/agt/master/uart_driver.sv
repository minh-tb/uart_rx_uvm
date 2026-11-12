//***************************************************************************************************************
// UART Driver
//***************************************************************************************************************
`ifndef UART_DRIVER_SV
`define UART_DRIVER_SV

import uart_tlm_pkg::*;

class uart_driver extends uvm_driver #(uart_tlm);
  `uvm_component_utils(uart_driver)

  virtual uart_if vif;
  uvm_analysis_port #(uart_tlm) ap;
  bit [7:0] rx_data;

  covergroup rx_data_cov;
    option.per_instance = 1;
    cp_rx_data: coverpoint rx_data {
      bins low  = {[8'h00:8'h3F]};
      bins mid1 = {[8'h40:8'h7F]};
      bins mid2 = {[8'h80:8'hBF]};
      bins high = {[8'hC0:8'hFF]};
    }
  endgroup

  function new(string name = "uart_driver", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
    rx_data_cov = new();
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
    vif.rx_data <= 1'b1; // Idle state is high
    @(negedge vif.rst);   // Wait for reset release
    repeat (20) @(posedge vif.clk);

    forever begin
      seq_item_port.get_next_item(req);
      rx_data = req.data;
      rx_data_cov.sample();
      ap.write(req);
      send_data(req);
      seq_item_port.item_done();
    end
  endtask

  task send_data(uart_tlm pkt);
    bit [9:0] tx_data;
    // Frame format: Start bit (0), 8 data bits (LSB first), Stop bit (1)
    tx_data = {1'b1, pkt.data, 1'b0};

    `uvm_info(get_type_name(), $sformatf("Driving serial packet: data=0x%02h (%08b) frame=%10b", pkt.data, pkt.data, tx_data), UVM_LOW)

    for (int i = 0; i < 10; i++) begin
      @(posedge vif.uart_clk);
      vif.rx_data <= tx_data[i];
    end

    // Hold stop bit then return to idle
    @(posedge vif.uart_clk);
    vif.rx_data <= 1'b1;

    // Small inter-frame idle delay
    repeat (2) @(posedge vif.uart_clk);
  endtask

endclass

`endif
