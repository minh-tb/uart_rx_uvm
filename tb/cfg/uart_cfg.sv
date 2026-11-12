//***************************************************************************************************************
// UART Configuration Class
//***************************************************************************************************************
`ifndef UART_CFG_SV
`define UART_CFG_SV

class uart_cfg extends uvm_object;
  `uvm_object_utils(uart_cfg)

  rand int num_packets;
  rand int baud_rate;
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  function new(string name = "uart_cfg");
    super.new(name);
    num_packets = 5;
    baud_rate = 115200;
  endfunction

  constraint cfg_c {
    soft num_packets inside {[2:10]};
  }

endclass

`endif
