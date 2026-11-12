//***************************************************************************************************************
// Clock and reset module
//***************************************************************************************************************
`timescale 1ns/1ps

interface uart_if (input logic clk, input logic rst);

  logic uart_clk;
  logic rx_data;
  wire  o_valid;
  wire [7:0] o_data;

  // Generate uart_clk to be used to send rx_data
	initial begin
    rx_data = 1;
		uart_clk = 1;
		forever begin
      // The BAUD rate is 115200
      // The clk 10Mhz
      // clk periods per bit is 88
      repeat (44) @(posedge clk);
			uart_clk = ~uart_clk;
		end
	end

  // SVA assertions for o_valid and o_data stability (Item 2 in UART_VP)
  property p_valid_one_clk;
    @(posedge clk) disable iff (rst) $rose(o_valid) |=> !o_valid;
  endproperty
  a_valid_one_clk: assert property(p_valid_one_clk);

  property p_valid_known;
    @(posedge clk) disable iff (rst) !$isunknown(o_valid);
  endproperty
  a_valid_known: assert property(p_valid_known);

  property p_data_known_on_valid;
    @(posedge clk) disable iff (rst) o_valid |-> !$isunknown(o_data);
  endproperty
  a_data_known_on_valid: assert property(p_data_known_on_valid);

  property p_data_stable_on_valid;
    @(posedge clk) disable iff (rst) o_valid |-> $stable(o_data);
  endproperty
  a_data_stable_on_valid: assert property(p_data_stable_on_valid);

endinterface
