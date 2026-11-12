# UART Receiver Verification Case Studies (Based on `UART_VP`)

This document presents practical verification case studies derived from executing the UART Receiver Verification Plan ([UART_VP.md](UART_VP.md) / [UART_VP.xlsx](UART_VP.xlsx)) against the Verilog RTL ([dut/receiver.v](dut/receiver.v)) using the UVM-1.1d testbench in `labs/uart_rx/tb` on QuestaSim 2021.2_1.

---

## System Under Verification & Plan Derivation

### 1. DUT Architecture & Timing Profile
- **Module**: [`receiver`](dut/receiver.v#L9-L143) (`10 MHz` nominal clock / `115200` baud, `CLKS_PER_BIT = 87`, no parity, 1 start bit `0`, 8 data bits LSB-first, 1 stop bit `1`).
- **FSM States**: `s_IDLE` (`3'b000`) -> `s_RX_START_BIT` (`3'b001`, mid-bit verify at `r_Clock_Count == 43`) -> `s_RX_DATA_BITS` (`3'b010`, 8 bits sampled every 87 clocks) -> `s_RX_STOP_BIT` (`3'b011`) -> `s_CLEANUP` (`3'b100`, `o_Rx_DV` / `o_valid` asserted for 1 clock cycle).
- **Clocking & Baud Observation**: In simulation (`timescale 1ns/1ps`), [`clk_rst_if`](inf/clk_rst_if.sv#L32-L34) toggles `clk` every `#5` (`10 ns` sim period), while [`uart_if`](inf/uart_if.sv#L21-L22) toggles `uart_clk` every `44` `clk` posedges (`88 clk` cycles per bit). This creates an intentional ~`1.15%` (`1 clock/bit`) baud-rate mismatch between the serial transmitter (`uart_driver`) and the DUT (`CLKS_PER_BIT = 87`), exercising realistic clock-tolerance margin across a 10-bit frame (~`898` `clk` cycles / `8980 ns` end-to-end).

### 2. Derivation from the Reference `mux_tb` Architecture
Because no standalone `mux_tb` plan spreadsheet existed on disk, `UART_VP` was reasoned directly from the verification pillars present in [`labs/mux_tb`](../mux_tb):
- **Scoreboard FIFO Comparison** (`mux_in_sb.sv` -> [`sb.sv`](tb/chk/sb.sv))
- **End-of-Test Drain Verification** (`check_phase` -> [`sb.sv`](tb/chk/sb.sv#L52-L57))
- **Functional Coverage** (`mux_in_cov.sv` -> `rx_data_cov` in [`uart_driver.sv`](tb/agt/master/uart_driver.sv#L16-L24))
- **Concurrent SVA Protocol/Timing Checks** (`mux.sv` assertions `a1..a3` -> [`uart_if.sv`](inf/uart_if.sv#L27-L45))
- **Negative / Error Testing** (`mux_cfg.inject_error` -> [`uart_err_test.sv`](tb/tst/uart_err_test.sv))

---

## Case Study 1: End-to-End Serial-to-Parallel Data Integrity (`UART_VP` Items 1.1 & 1.3)

### Objective
Verify that every randomized 8-bit payload serialized onto `uart_if.rx_data` as `{1'b1, data[7:0], 1'b0}` (LSB-first) is accurately deserialized onto `o_data` when `o_valid` asserts, with zero dropped, duplicated, or reordered bytes.

### Testbench Mechanism
- **Sequence & Driver**: [`uart_demo_seq`](tb/agt/master/seq/uart_demo_seq.sv) generates `20` randomized `uart_tlm` bytes (`soft num_packets == 20`). [`uart_driver`](tb/agt/master/uart_driver.sv#L48-L62) publishes the reference transaction on `ap` and serially toggles `vif.rx_data` across 10 `uart_clk` edges plus idle hold.
- **Monitor & Scoreboard**: [`uart_slave_monitor`](tb/agt/slave/uart_slave_monitor.sv#L32-L41) samples `vif.o_data` on every `posedge vif.clk` where `vif.o_valid === 1'b1`. [`sb`](tb/chk/sb.sv#L26-L57) pushes expected bytes into `exp_queue[$]`, pops and compares on each actual byte, and asserts `exp_queue.size() == 0` in `check_phase`.

### Engineering Lesson Learned: TLM Reference Ordering Race
- **Symptom**: During initial integration, sending `ap.write(req)` *after* `send_data(req)` returned caused the scoreboard to report `UNEXPECTED packet received from monitor` followed by off-by-one byte mismatches.
- **Root Cause**: `send_data(req)` waits through the stop bit plus `repeat (2) @(posedge vif.uart_clk)` idle cycles before returning, whereas `receiver.v` asserts `o_Rx_DV` (`o_valid`) immediately after the stop bit window completes. Thus `uart_slave_monitor` delivered the actual byte to `sb` *before* `uart_driver` delivered the expected byte.
- **Resolution**: Moving `ap.write(req)` **before** `send_data(req)` in [`uart_driver.sv`](tb/agt/master/uart_driver.sv#L48-L49) ensures the reference item always arrives in `exp_queue` prior to DUT output completion.

### Observed Verification Results
- **Checkpoint 1 ([`uart_cp1.log`](uart_cp1.log))**:
  - Packet 0 (`0x3b`, frame `1001110110`) driven at `201,000 ps`, sampled at `9,181,000 ps` (`8,980 ns` latency); 20/20 bytes matched (`0x3b` through `0xe7`).
  - `Total Packets Matched : 20`, `Total Packets Mismatched : 0`, `UVM_ERROR : 0`, `UVM_FATAL : 0`, `Errors: 0, Warnings: 0`.
- **Checkpoint 2 ([`uart_cp2.log`](uart_cp2.log))**:
  - Executed with `-sv_seed random` (`Sv_Seed = 2381075418`); 20/20 distinct random bytes matched (`0xd0` through `0xe7`), `UVM_ERROR : 0`, `Errors: 0, Warnings: 1` (`vsim-8634` due to `Makefile` compiling RTL without `+cover`).

---

## Case Study 2: Functional Coverage Closure on `rx_data` (`UART_VP` Items 1.2 & 1.5)

### Objective
Measure how effectively constrained-random traffic exercises the 8-bit `rx_data` value space (`8'h00`–`8'hFF`) and capture coverage metrics into `top.ucdb`.

### Testbench Mechanism
[`uart_driver`](tb/agt/master/uart_driver.sv#L16-L24) instantiates `covergroup rx_data_cov` partitioned into four equal 64-value bins over `rx_data`, sampled once per driven transaction (`rx_data = req.data; rx_data_cov.sample();`).

### Observed Coverage Results ([`rx_data_cov.log`](rx_data_cov.log#L6916-L6987))
| Coverpoint Bin | Range | Goal | Observed Hits (`Sv_Seed = 2381075418`) |
| :--- | :--- | :---: | :---: |
| `low` | `0:63` (`8'h00`–`8'h3F`) | 1 | `3` |
| `mid1` | `64:127` (`8'h40`–`8'h7F`) | 1 | `5` |
| `mid2` | `128:191` (`8'h80`–`8'hBF`) | 1 | `8` |
| `high` | `192:255` (`8'hC0`–`8'hFF`) | 1 | `4` |
| **Total** | **`8'h00`–`8'hFF`** | **100%** | **`20` samples (`Errors: 0, Warnings: 0`)** |

### Gap Analysis Against `UART_VP` Item 1.2
- While 20 random packets closed all four quartile range bins (`100%` bin hit rate in `top.ucdb`), none of the exact directed boundary/toggle bytes from Item 1.2 (`0x00`, `0xFF`, `0x55`, `0xAA`) appeared in the `Sv_Seed = 2381075418` run (`0xd0`..`0xe7`).
- **Recommendation**: Add explicit `bins corners = {8'h00, 8'hFF, 8'h55, 8'hAA};` to `rx_data_cov` and a short directed sequence alongside random traffic to guarantee Item 1.2 closure deterministically.

---

## Case Study 3: Interface Stability & Timing Verification via SVA (`UART_VP` Items 2.1, 2.3, 2.4)

### Objective
Formally check on every `posedge clk` that `o_valid` never glitches to `X`/`Z`, pulses for strictly one clock cycle per frame, and that `o_data` is known and stable whenever `o_valid` is asserted.

### Testbench Mechanism
Four concurrent SVA assertions were placed inside [`uart_if.sv`](inf/uart_if.sv#L26-L45), gated by `disable iff (rst)`:
1. **`a_valid_one_clk`**: `$rose(o_valid) |=> !o_valid`
2. **`a_valid_known`**: `!$isunknown(o_valid)`
3. **`a_data_known_on_valid`**: `o_valid |-> !$isunknown(o_data)`
4. **`a_data_stable_on_valid`**: `o_valid |-> $stable(o_data)`

### Engineering Lesson Learned: SVA Implication Precedence Syntax
- **Symptom**: `vlog` failed on [`uart_if.sv`](inf/uart_if.sv) with `** Error: (vlog-13069) near "|->": syntax error, unexpected |->`.
- **Root Cause**: A combined expression `!$isunknown(o_valid) && (o_valid |-> !$isunknown(o_data))` embedded a property implication operator (`|->`) inside a boolean sequence conjunction (`&&`), which is illegal in SystemVerilog property syntax.
- **Resolution**: Separating boolean checking (`a_valid_known`) from implication checking (`a_data_known_on_valid`) satisfied QuestaSim's SVA compiler with `0` syntax or elaboration issues.

### Observed Assertion Results ([`rx_data_cov.log`](rx_data_cov.log#L546-L680))
- `/top/uart_if0/a_valid_one_clk`: `failbin = 0`, `passbin = 1`
- `/top/uart_if0/a_valid_known`: `failbin = 0`, `passbin = 1`
- `/top/uart_if0/a_data_known_on_valid`: `failbin = 0`, `passbin = 1`
- `/top/uart_if0/a_data_stable_on_valid`: `failbin = 0`, `passbin = 1`

### Gap Analysis Against `UART_VP` Item 2.2
- `p_valid_low_in_rx` (verifying `(r_SM_Main != 3'b100) |-> !o_valid`) references internal DUT state `r_SM_Main`, so it was omitted from `uart_if.sv` to avoid hard-coded hierarchical paths. If full white-box state observability is required, attach it via a SystemVerilog `bind receiver ...` module rather than inside the interface.

---

## Case Study 4: False Start-Bit Glitch Rejection & Recovery (`UART_VP` Items 1.4 & 2.5)

### Objective
Verify that a brief spurious LOW glitch on `rx_data` (shorter than half a bit period, `(CLKS_PER_BIT-1)/2 = 43` clocks) causes `receiver.v` to abort start-bit detection back to `s_IDLE` without asserting `o_valid` or corrupting downstream UVM checking.

### Testbench Mechanism
In [`uart_err_test.sv`](tb/tst/uart_err_test.sv#L26-L61):
1. Runs `20` normal `uart_demo_seq` transactions and waits `50 us` for drain.
2. Synchronizes to `posedge vif.clk`, drives `vif.rx_data <= 1'b0` for `10` clock cycles (`< 43` threshold), then restores `vif.rx_data <= 1'b1`.
3. Monitors `vif.o_valid` for `100` consecutive clock cycles and flags `uvm_error` if `vif.o_valid !== 1'b0` at any cycle.

### Observed Results ([`extra_credit.log`](extra_credit.log#L187-L218))
- Normal traffic: `20/20` packets matched, `0` mismatched.
- Glitch injection at `@ 278,791,000 ps`: `Injecting false start-bit glitch on rx_data (10 clk cycles < 43 mid-bit threshold)`.
- Post-glitch check at `@ 279,891,000 ps` (`1,100 ns` = `10 + 100` clocks later): `False start-bit glitch rejected cleanly: o_valid remained stable LOW (0)`.
- `UVM_ERROR : 0`, `UVM_FATAL : 0`, `Errors: 0, Warnings: 0`.

### Gap Analysis Against `UART_VP` Item 1.4
- While protocol glitch immunity (`2.5`) is actively verified with `0` errors in `uart_err_test`, negative payload-mismatch testing (`1.4`, corresponding to `mux_cfg.inject_error`) is not currently enabled in [`uart_cfg.sv`](tb/cfg/uart_cfg.sv) because `extra_credit.log` explicitly requires zero UVM/simulation errors. If needed in a separate negative test, `inject_error` can be added with `uvm_report_catcher` to demote expected mismatch errors cleanly.

---

## Traceability & Verification Closure Summary

| Item # | Scenario | Status in Current TB | Evidence / Remaining Action |
| :---: | :--- | :--- | :--- |
| **1.1** | Random 8-bit `rx_data` vs `o_data` | **Closed** | `20/20` matched in [`uart_cp1.log`](uart_cp1.log) & [`uart_cp2.log`](uart_cp2.log) |
| **1.2** | Corner payloads (`0x00`, `0xFF`, `0x55`, `0xAA`) | **Partial** | Exercised via random bins; add directed sequence + explicit corner bins |
| **1.3** | Multi-packet streaming & queue drain | **Closed** | `20` packets, `exp_queue` empty in `sb.sv::check_phase` |
| **1.4** | Negative payload error injection (`inject_error`) | **Deferred** | Omitted to keep `extra_credit.log` at `0` errors; add `inject_error` + catcher if needed |
| **1.5** | `rx_data` functional coverage (`top.ucdb`) | **Closed** | `low=3`, `mid1=5`, `mid2=8`, `high=4` (`100%` quartile bins) in [`rx_data_cov.log`](rx_data_cov.log) |
| **2.1** | Single-clock `o_valid` pulse width | **Closed** | `a_valid_one_clk`: `failbin = 0`, `passbin = 1` in [`rx_data_cov.log`](rx_data_cov.log) |
| **2.2** | `o_valid == 0` outside `s_CLEANUP` | **Open (White-box)** | Omitted from `uart_if.sv` to avoid hierarchical reference; add via `bind` |
| **2.3** | No `X`/`Z` on `o_valid` and valid `o_data` | **Closed** | `a_valid_known` & `a_data_known_on_valid`: `failbin = 0` |
| **2.4** | `o_data` stability while `o_valid == 1` | **Closed** | `a_data_stable_on_valid`: `failbin = 0`, `passbin = 1` |
| **2.5** | False start-bit glitch rejection | **Closed** | 10-clock glitch rejected cleanly in [`extra_credit.log`](extra_credit.log) |
