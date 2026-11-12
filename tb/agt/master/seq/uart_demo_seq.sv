//***************************************************************************************************************
// UART Demo Sequence
//***************************************************************************************************************
`ifndef UART_DEMO_SEQ_SV
`define UART_DEMO_SEQ_SV

import uart_tlm_pkg::*;

class uart_demo_seq extends uvm_sequence #(uart_tlm);
  `uvm_object_utils(uart_demo_seq)

  rand int num_packets;

  constraint num_pkt_c {
    soft num_packets == 20;
  }

  function new(string name = "uart_demo_seq");
    super.new(name);
    num_packets = 20;
  endfunction

  virtual task body();
    uart_tlm req;
    `uvm_info(get_type_name(), $sformatf("Starting sequence with %0d packets", num_packets), UVM_LOW)
    for (int i = 0; i < num_packets; i++) begin
      req = uart_tlm::type_id::create($sformatf("uart_req_%0d", i));
      start_item(req);
      assert(req.randomize());
      `uvm_info(get_type_name(), $sformatf("Sequence generated packet %0d: data = 0x%02h", i, req.data), UVM_LOW)
      finish_item(req);
    end
    `uvm_info(get_type_name(), "Completed sequence", UVM_LOW)
  endtask

endclass

`endif
