# POWER8 FPGA Programming Tools

Tools and resources for programming Xilinx/AMD FPGAs from IBM POWER8 systems (ppc64le).

## Background

This repository contains ports and builds of FPGA programming tools for the ppc64le architecture, specifically tested on IBM POWER8 S824 servers. These tools enable JTAG programming of Xilinx 7-series FPGAs without requiring an x86 workstation.

## Target Hardware

### FPGA Board: HPC XC7K420T/K480T Chinese Board (2019)

This is a low-cost Chinese development board commonly found on AliExpress/Taobao featuring:
- **FPGA**: Kintex-7 XC7K480T-FFG1156 (IDCODE: 0x23751093)
  - Note: Often sold as "K420T" but K420T and K480T are the same silicon die
- **PCIe**: Gen1 x8 lanes routed to BANK 112 (GT Quad X0Y0)
- **Package**: FFG1156
- **Speed Grade**: -2

#### Key Pinout (from [Kohei-Toyoda's Gist](https://gist.github.com/Kohei-Toyoda/709a1adf5d3dacd196574dc702ed3b94))

| Signal | Pin | Notes |
|--------|-----|-------|
| PCIe RefClk P | AD6 | BANK 112 MGTREFCLK0, 100MHz |
| PCIe RefClk N | AD5 | Differential pair |
| PCIe PERST# | W21 | Active low, LVCMOS25 |
| System Clock P | U22 | 100MHz LVDS (optional) |
| System Clock N | U23 | Differential pair |

#### PCIe GT Lanes (BANK 112)
```
Lane 0: GTXE2_CHANNEL_X0Y0 (RX: AC4, TX: AH2)
Lane 1: GTXE2_CHANNEL_X0Y1 (RX: AE4, TX: AK2)
Lane 2: GTXE2_CHANNEL_X0Y2 (RX: AG4, TX: AJ4)
Lane 3: GTXE2_CHANNEL_X0Y3 (RX: AH6, TX: AK6)
Lane 4: GTXE2_CHANNEL_X0Y4 (RX: AE12, TX: AG8)
Lane 5: GTXE2_CHANNEL_X0Y5 (RX: AF10, TX: AJ8)
Lane 6: GTXE2_CHANNEL_X0Y6 (RX: AG12, TX: AK10)
Lane 7: GTXE2_CHANNEL_X0Y7 (RX: AH10, TX: AJ12)
```

### Host System: IBM POWER8 S824

- **Model**: 8286-42A
- **CPUs**: Dual 8-core POWER8 (16 cores, 128 threads with SMT8)
- **RAM**: 576 GB DDR3
- **OS**: Ubuntu 20.04 LTS (last version with POWER8 support)

## Tools Included

### 1. xc3sprog (ppc64le)

Open-source FPGA programmer supporting JTAG via various cables including Platform Cable USB II.
- Forked from: https://github.com/matrix-io/xc3sprog

```bash
# Detect chain
./bin/ppc64le/xc3sprog -c xpc_usb -j

# Program bitstream
./bin/ppc64le/xc3sprog -c xpc_usb -v pse_hpc_k480t.bit
```

**Build from source:**
```bash
sudo apt install git cmake g++ libusb-1.0-0-dev libftdi1-dev
cd xc3sprog
mkdir build && cd build
cmake .. -DUSE_WIRINGPI=OFF
make -j4
```

### 2. xvcd (Xilinx Virtual Cable Daemon)

XVC server for Platform Cable USB II, enabling remote JTAG access.

```bash
# Start server
./bin/ppc64le/xvcd -P 0x0008

# Connect from Vivado Hardware Manager
# Target: localhost:2542
```

### 3. detectchain

Simple JTAG chain detection utility.

```bash
./bin/ppc64le/detectchain
# Output: JTAG loc.: 0 IDCODE: 0x23751093 Desc: XC7K480T Rev: C
```

## PSE PCIe Accelerator Project

The `pse-pcie-accel/` directory contains a Vivado project for the Proto-Sentient Engine (PSE) PCIe accelerator targeting the HPC K480T board.

### Files

| File | Description |
|------|-------------|
| `build_pse_hpc_k480t.tcl` | Main build script for HPC board |
| `pcie_hpc_k480t.xdc` | Constraint file with correct HPC pinout |
| `build_minimal_k480t.tcl` | Minimal test design |

### Build Instructions

```bash
# Set license
export XILINXD_LICENSE_FILE=/path/to/Xilinx.lic

# Run build
vivado -mode batch -source pse-pcie-accel/build_pse_hpc_k480t.tcl
```

### Architecture

```
                    ┌─────────────────────────────────────────┐
                    │           HPC K480T Board               │
                    │  ┌──────────────────────────────────────┐ │
  PCIe x8 ──────────┼──┤       AXI PCIe Bridge            │   │
  (BANK 112)        │  │     (Gen1 x8, 2.5 GT/s)          │   │
                    │  └───────────────┬──────────────────┘   │
                    │                  │ AXI4 128-bit         │
                    │  ┌───────────────┴──────────────────┐   │
                    │  │       AXI Interconnect           │   │
                    │  └───────────────┬──────────────────┘   │
                    │                  │                      │
                    │  ┌───────────────┴──────────────────┐   │
                    │  │        PSE Engine                │   │
                    │  │   (Vec_Perm Collapse Logic)      │   │
                    │  │   (Non-Bijunctive Attention)     │   │
                    │  └──────────────────────────────────┘   │
                    └─────────────────────────────────────────┘
```

## Troubleshooting

### "End of startup status: LOW"

If the bitstream loads but DONE pin stays low:
1. Verify you're using the correct pinout for YOUR board
2. Check `BITSTREAM.CONFIG.DRIVEDONE YES` is set
3. Ensure power supplies are stable
4. Try a minimal test design first

### Wrong Device ID

- K420T IDCODE: 0x03752093
- K480T IDCODE: 0x03751093 (with revision bits: 0x23751093)

Both are the same silicon die - use K480T bitstreams.

### xvcd Not Detecting Devices

Try xc3sprog directly instead of going through Vivado's hw_server:
```bash
./xc3sprog -c xpc_usb -j
```

## References

- [HPC K420T Pinout Gist](https://gist.github.com/Kohei-Toyoda/709a1adf5d3dacd196574dc702ed3b94)
- [xc3sprog Documentation](http://xc3sprog.sourceforge.net/)
- [Xilinx Virtual Cable Protocol](https://github.com/Xilinx/XilinxVirtualCable)

## License

Tools are provided under their original licenses:
- xc3sprog: GPLv2
- xvcd: BSD-style
- PSE project files: MIT
