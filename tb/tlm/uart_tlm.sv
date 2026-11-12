//***************************************************************************************************************
// UART Transaction Class
//***************************************************************************************************************
`ifndef UART_TLM_SV
`define UART_TLM_SV

class uart_tlm extends uvm_sequence_item;
  `uvm_object_utils(uart_tlm)

  rand bit [7:0] data;
  bit [7:0]      in_rx_data;
  bit            o_valid;
  bit [7:0]      o_data;

  function new(string name = "uart_tlm");
    super.new(name);
  endfunction

  function void post_randomize();
    in_rx_data = data;
  endfunction

  function void do_copy(uvm_object rhs);
    uart_tlm rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs)) return;
    this.data       = rhs_.data;
    this.in_rx_data = rhs_.in_rx_data;
    this.o_valid    = rhs_.o_valid;
    this.o_data     = rhs_.o_data;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    uart_tlm rhs_;
    do_compare = super.do_compare(rhs, comparer);
    if (!$cast(rhs_, rhs)) return 0;
    do_compare &= (this.data == rhs_.data);
  endfunction

  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("data", data, 8, UVM_HEX);
    printer.print_field("o_valid", o_valid, 1, UVM_BIN);
    printer.print_field("o_data", o_data, 8, UVM_HEX);
  endfunction

  function string convert2string();
    return $sformatf("data=0x%02h o_data=0x%02h o_valid=%0b", data, o_data, o_valid);
  endfunction

endclass

typedef uart_tlm uart_packet;

`endif
