//***************************************************************************************************************
// UART Scoreboard
//***************************************************************************************************************
`ifndef SB_SV
`define SB_SV

`uvm_analysis_imp_decl(_expected)
`uvm_analysis_imp_decl(_actual)

class sb extends uvm_scoreboard;
  `uvm_component_utils(sb)

  uvm_analysis_imp_expected #(uart_tlm, sb) exp_imp;
  uvm_analysis_imp_actual   #(uart_tlm, sb) act_imp;

  uart_tlm exp_queue[$];
  int match_count = 0;
  int mismatch_count = 0;

  function new(string name = "sb", uvm_component parent = null);
    super.new(name, parent);
    exp_imp = new("exp_imp", this);
    act_imp = new("act_imp", this);
  endfunction

  virtual function void write_expected(uart_tlm pkt);
    uart_tlm exp_pkt;
    $cast(exp_pkt, pkt.clone());
    exp_queue.push_back(exp_pkt);
    `uvm_info(get_type_name(), $sformatf("Scoreboard stored expected byte: 0x%02h (Queue size: %0d)", pkt.data, exp_queue.size()), UVM_LOW)
  endfunction

  virtual function void write_actual(uart_tlm pkt);
    uart_tlm exp_pkt;
    `uvm_info(get_type_name(), $sformatf("Scoreboard received actual byte: 0x%02h", pkt.data), UVM_LOW)

    if (exp_queue.size() > 0) begin
      exp_pkt = exp_queue.pop_front();
      if (exp_pkt.data === pkt.data) begin
        match_count++;
        `uvm_info(get_type_name(), $sformatf("MATCH! Expected: 0x%02h == Actual: 0x%02h [Matches: %0d]", exp_pkt.data, pkt.data, match_count), UVM_LOW)
      end else begin
        mismatch_count++;
        `uvm_error(get_type_name(), $sformatf("MISMATCH! Expected: 0x%02h != Actual: 0x%02h [Mismatches: %0d]", exp_pkt.data, pkt.data, mismatch_count))
      end
    end else begin
      mismatch_count++;
      `uvm_error(get_type_name(), $sformatf("UNEXPECTED packet received from monitor: 0x%02h with empty expected queue!", pkt.data))
    end
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (exp_queue.size() > 0) begin
      `uvm_error(get_type_name(), $sformatf("%0d expected packet(s) were never received by monitor!", exp_queue.size()))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(), "--------------------------------------------------", UVM_LOW)
    `uvm_info(get_type_name(), "             SCOREBOARD REPORT SUMMARY            ", UVM_LOW)
    `uvm_info(get_type_name(), "--------------------------------------------------", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total Packets Matched   : %0d", match_count), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("  Total Packets Mismatched: %0d", mismatch_count), UVM_LOW)
    `uvm_info(get_type_name(), "--------------------------------------------------", UVM_LOW)
    if (mismatch_count == 0 && match_count > 0) begin
      `uvm_info(get_type_name(), "  >>> OVERALL RESULT: PASSED <<<", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), "  >>> OVERALL RESULT: FAILED <<<")
    end
  endfunction

endclass

`endif
