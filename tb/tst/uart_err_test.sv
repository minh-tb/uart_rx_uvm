//***************************************************************************************************************
// UART Error Injection Test
//***************************************************************************************************************
`ifndef UART_ERR_TEST_SV
`define UART_ERR_TEST_SV

class uart_err_test extends base_test;
  `uvm_component_utils(uart_err_test)

  virtual uart_if vif;

  function new(string name = "uart_err_test", uvm_component parent = null);
    super.new(name, parent);
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
    uart_demo_seq seq;
    bit glitch_failed = 1'b0;

    phase.raise_objection(this, "Objection raised by uart_err_test");

    seq = uart_demo_seq::type_id::create("seq");
    `uvm_info(get_type_name(), "Starting uart_err_test sequence execution", UVM_LOW)

    #100ns;
    seq.start(env.master_agt.sequencer);
    #50us;

    // Row 2.5 of UART_VP: False Start-Bit Glitch Rejection (< 43 clk cycles)
    `uvm_info(get_type_name(), "Injecting false start-bit glitch on rx_data (10 clk cycles < 43 mid-bit threshold)", UVM_LOW)
    @(posedge vif.clk);
    vif.rx_data <= 1'b0;
    repeat (10) @(posedge vif.clk);
    vif.rx_data <= 1'b1;

    // Observe o_valid for 100 clk cycles (> full start-bit window); DUT must abort back to s_IDLE with o_valid=0
    repeat (100) begin
      @(posedge vif.clk);
      if (vif.o_valid !== 1'b0) begin
        glitch_failed = 1'b1;
        `uvm_error(get_type_name(), "Unexpected o_valid assertion after false start-bit glitch!")
      end
    end

    if (!glitch_failed) begin
      `uvm_info(get_type_name(), "False start-bit glitch rejected cleanly: o_valid remained stable LOW (0)", UVM_LOW)
    end

    #10us;
    `uvm_info(get_type_name(), "Finished uart_err_test sequence execution", UVM_LOW)
    phase.drop_objection(this, "Objection dropped by uart_err_test");
  endtask

endclass

`endif
