# HPC K480T Board Troubleshooting

## Configuration Failure: "Device failed to configure, INSTRUCTION_CAPTURE is 0x09"

### Symptoms
- Bitstream loads successfully (confirmed by correct bit count)
- Programming completes in expected time
- Device fails to exit startup sequence
- DONE pin stays LOW
- INSTRUCTION_CAPTURE returns 0x09

### What INSTRUCTION_CAPTURE 0x09 Means
For 7-series FPGAs:
- The device received the bitstream but did not complete the startup sequence
- The FPGA is stuck in an intermediate configuration state
- This typically indicates a hardware or voltage issue, not a bitstream problem

### Verified Settings
We have tried and verified:
- [x] Correct device ID: 0x23751093 (XC7K480T Rev C)
- [x] CONFIG_VOLTAGE 2.5V (matching HPC board LVCMOS25 IOs)
- [x] CFGBVS VCCO
- [x] BITSTREAM.CONFIG.DRIVEDONE YES
- [x] BITSTREAM.STARTUP.STARTUPCLK JTAGCLK
- [x] Various startup cycle configurations
- [x] Both compressed and uncompressed bitstreams

### Hardware Checks Needed

1. **Check DONE LED**
   - Does the board have a DONE LED?
   - Does it illuminate after power-on without programming?
   - If it stays dark after programming, DONE is not going HIGH

2. **Check INIT_B LED**
   - INIT_B should go HIGH after loading
   - If INIT_B is LOW, there's a CRC error in the bitstream

3. **Measure VCCO Bank 0**
   - Should be 2.5V for LVCMOS25 configuration
   - If 3.3V, change CONFIG_VOLTAGE to 3.3
   - If 1.8V, change CFGBVS to GND

4. **Check Power Supply**
   - VCCINT (1.0V) must be stable
   - VCCAUX (1.8V) must be stable
   - VCCO Bank 0 must match CONFIG_VOLTAGE

5. **Check PUDC_B Pin**
   - If tied wrong, can prevent startup
   - Should typically be HIGH for JTAG configuration

### Board-Specific Notes

The HPC XC7K420T/K480T board from the [Kohei-Toyoda gist](https://gist.github.com/Kohei-Toyoda/709a1adf5d3dacd196574dc702ed3b94) may have:
- External SPI flash that conflicts with JTAG startup
- Special configuration mode switches
- Power sequencing requirements

### Alternative Programming Methods

1. **Use SPI Flash**
   - Program the SPI flash instead of JTAG
   - Let the FPGA boot from flash on power cycle

2. **Use xvcd + Vivado**
   ```bash
   # Start xvcd on POWER8
   ./xvcd -P 0x0008

   # Connect from Vivado Hardware Manager
   # Open Target -> Open New Target -> Remote Server
   # Host: 100.94.28.32, Port: 2542
   ```

3. **Try Different Cable**
   - Issue could be with Platform Cable USB II timing
   - Try FTDI-based cable if available

### References
- [UG470 - 7 Series Configuration](https://www.xilinx.com/support/documentation/user_guides/ug470_7Series_Config.pdf)
- [AR# 52626 - DONE Does Not Go High](https://support.xilinx.com/s/article/52626)
