# UART RX UVM Verification

UVM-1.1d verification environment for a UART receiver (`dut/receiver.v`) operating at **115200 baud** with a **10 MHz** system clock (`CLKS_PER_BIT = 87`, 8N1 format: 1 start bit, 8 data bits LSB-first, no parity, 1 stop bit).

## Repository Structure

```text
.
├── dut/
│   ├── receiver.v              # UART receiver RTL (DUT)
│   ├── transmitter.v           # UART transmitter RTL (reference)
│   ├── UART_TB.v               # Standalone Verilog testbench
│   ├── uart.readme             # Original design/TB notes
│   └── LICENSE.txt             # MIT License for DUT RTL
├── inf/
│   ├── clk_rst_if.sv           # 10 MHz clock & reset interface
│   └── uart_if.sv              # UART serial/parallel interface + SVA assertions
├── sim/
│   ├── Makefile                # Compile, run, coverage, and clean targets
│   ├── sim.do                  # Questa batch simulation script
│   ├── cov.do                  # Questa coverage save script
│   └── gui.do                  # Questa GUI script
├── tb/
│   ├── agt/
│   │   ├── master/             # Active UART TX driver, sequencer, and sequences
│   │   └── slave/              # Passive UART RX output monitor
│   ├── cfg/                    # Configuration object (`uart_cfg`)
│   ├── chk/                    # Scoreboard (`sb`)
│   ├── env/                    # Top module (`top`) and UVM environment (`uart_env`)
│   ├── tlm/                    # Transaction item (`uart_tlm`)
│   └── tst/                    # Tests (`uart_demo_test`, `uart_err_test`)
├── env.sh                      # Sets `SPI_TB_DIR` for Makefile paths
├── readme                      # Lab overview notes
├── run_instructions            # Quick simulation commands
├── UART_VP.md / .csv / .xlsx   # Verification Plan
├── UART_VP_case_studies.md     # Verification case studies & closure summary
├── uart_cp1.log                # Checkpoint 1 run log (`uart_demo_test`)
├── uart_cp2.log                # Checkpoint 2 random-seed run log (`uart_demo_test`)
├── rx_data_cov.log             # Coverage dump (`vcover dump top.ucdb`)
└── extra_credit.log            # Error injection / glitch test log (`uart_err_test`)
```

## Verification Architecture

- **Master Agent (`tb/agt/master`)**: `uart_demo_seq` generates randomized 8-bit `uart_tlm` transactions (`num_packets == 20` by default). `uart_driver` samples the `rx_data_cov` covergroup (4 equal bins covering `8'h00`–`8'hFF`), publishes expected transactions on its analysis port, and drives `{1'b1, data[7:0], 1'b0}` serially on `uart_if.rx_data`.
- **Slave Agent (`tb/agt/slave`)**: `uart_slave_monitor` monitors `o_valid` on `posedge clk` and captures `o_data` for comparison.
- **Scoreboard (`tb/chk/sb.sv`)**: Queues expected bytes from the driver, compares against actual bytes from the monitor, verifies an empty queue in `check_phase`, and reports overall pass/fail status in `report_phase`.
- **SVA Assertions (`inf/uart_if.sv`)**:
  - `a_valid_one_clk`: `o_valid` pulses for a single clock cycle.
  - `a_valid_known`: `o_valid` is never `X`/`Z` after reset.
  - `a_data_known_on_valid`: `o_data` is known whenever `o_valid` is high.
  - `a_data_stable_on_valid`: `o_data` remains stable while `o_valid` is high.

## Tests

| Test Name | Description |
| :--- | :--- |
| `uart_demo_test` | Drives 20 randomized 8-bit UART frames via `uart_demo_seq` and verifies 100% scoreboard match and drain. |
| `uart_err_test` | Runs `uart_demo_seq`, then injects a 10-clock false start-bit LOW glitch (`< 43` clock mid-bit threshold) and verifies `o_valid` stays `0`. |

## How to Run

From the repository root on a machine with Siemens QuestaSim (or Cadence Xcelium):

```bash
source env.sh
cd sim
```

### Siemens QuestaSim (default)

```bash
# Compile
make compile_uart

# Run demo test
make run test_name=uart_demo_test

# Run false start-bit glitch test
make run test_name=uart_err_test

# Run with random seed and coverage database (top.ucdb)
make coverage test_name=uart_demo_test
vcover dump top.ucdb > ../rx_data_cov.log
```

### Cadence Xcelium

```bash
make compile_uart tool=Cadence
make run test_name=uart_demo_test tool=Cadence
```

## Verification Plan & Results

See [UART_VP.md](UART_VP.md) and [UART_VP_case_studies.md](UART_VP_case_studies.md) for full requirement traceability across the recorded simulation logs:
- [uart_cp1.log](uart_cp1.log): `uart_demo_test` — 20/20 matched, 0 mismatched, `UVM_ERROR: 0`.
- [uart_cp2.log](uart_cp2.log): `uart_demo_test` (`-sv_seed random`) — 20/20 matched, 0 mismatched, `UVM_ERROR: 0`.
- [rx_data_cov.log](rx_data_cov.log): `rx_data_cov` 100% quartile bin hits (`low=3`, `mid1=5`, `mid2=8`, `high=4`) and 0 SVA assertion failures.
- [extra_credit.log](extra_credit.log): `uart_err_test` — 20/20 normal packets matched + false start-bit glitch rejected, `UVM_ERROR: 0`.
