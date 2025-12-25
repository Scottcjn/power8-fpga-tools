# PSE PCIe Accelerator for POWER8

Proto-Sentient Engine (PSE) hardware accelerator using AXI PCIe on Kintex-7.

## Target Hardware
- Kintex-7 XC7K480T (FFG1156 package)
- PCIe Gen1 x8 interface
- Designed for IBM POWER8 S824 server

## Files
- `pcie_k480t.xdc` - Constraints file
- `build_pse_xdma_k480t.tcl` - Vivado build script

## Build
```tcl
vivado -mode batch -source build_pse_xdma_k480t.tcl
```

## Features
- AXI PCIe Gen1 x8 endpoint
- Ring oscillator TRNG for entropy
- Device ID: 0x7028

## Status
- Synthesis: ✅ Complete
- Implementation: ✅ Complete  
- Bitstream: ✅ Generated
- Programming: ⚠️ FPGA loads but DONE doesn't go high (startup issue)
