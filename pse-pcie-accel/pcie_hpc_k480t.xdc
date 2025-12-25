# PCIe Constraints for HPC XC7K420T/K480T Chinese Board
# Based on: https://gist.github.com/Kohei-Toyoda/709a1adf5d3dacd196574dc702ed3b94
#
# This board uses BANK 112 for PCIe GT lanes

# =============================================================================
# Configuration Settings
# =============================================================================
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]
set_property CFGBVS VCCO [current_design]

# Force DONE pin to be actively driven
set_property BITSTREAM.CONFIG.DRIVEDONE YES [current_design]

# =============================================================================
# PCIe Reference Clock - BANK 112 MGTREFCLK0
# =============================================================================
# 100MHz differential reference clock from PCIe slot
set_property PACKAGE_PIN AD6 [get_ports pcie_refclk_clk_p]
set_property PACKAGE_PIN AD5 [get_ports pcie_refclk_clk_n]

# Create clock constraint for PCIe reference clock (100 MHz)
create_clock -period 10.000 -name pcie_refclk [get_ports pcie_refclk_clk_p]

# =============================================================================
# PCIe Reset Signal - Active Low
# =============================================================================
set_property PACKAGE_PIN W21 [get_ports pcie_perst_n]
set_property IOSTANDARD LVCMOS25 [get_ports pcie_perst_n]
set_property PULLUP true [get_ports pcie_perst_n]

# PCIe reset is asynchronous
set_false_path -from [get_ports pcie_perst_n]

# =============================================================================
# PCIe GT Lanes - BANK 112 (X0Y0 to X0Y7)
# =============================================================================
# Note: GT locations are typically auto-assigned by Vivado based on the
# reference clock location. The IP should place lanes in BANK 112.
#
# Physical pins per gist:
# RX: AC4, AE4, AG4, AH6, AE12, AF10, AG12, AH10
# TX: AH2, AK2, AJ4, AK6, AG8, AJ8, AK10, AJ12
#
# These are GT pins - they're auto-constrained by the PCIe IP based on
# the selected GT Quad. We set the LOC for the GT Quad here.

# Constrain PCIe block to use GT Quad X0Y0 (BANK 112)
# This should match where the physical PCIe lanes are routed
set_property LOC GTXE2_CHANNEL_X0Y0 [get_cells -hierarchical -filter {NAME =~ *gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property LOC GTXE2_CHANNEL_X0Y1 [get_cells -hierarchical -filter {NAME =~ *gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property LOC GTXE2_CHANNEL_X0Y2 [get_cells -hierarchical -filter {NAME =~ *gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property LOC GTXE2_CHANNEL_X0Y3 [get_cells -hierarchical -filter {NAME =~ *gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property LOC GTXE2_CHANNEL_X0Y4 [get_cells -hierarchical -filter {NAME =~ *gt_top_i/pipe_wrapper_i/pipe_lane[4].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property LOC GTXE2_CHANNEL_X0Y5 [get_cells -hierarchical -filter {NAME =~ *gt_top_i/pipe_wrapper_i/pipe_lane[5].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property LOC GTXE2_CHANNEL_X0Y6 [get_cells -hierarchical -filter {NAME =~ *gt_top_i/pipe_wrapper_i/pipe_lane[6].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]
set_property LOC GTXE2_CHANNEL_X0Y7 [get_cells -hierarchical -filter {NAME =~ *gt_top_i/pipe_wrapper_i/pipe_lane[7].gt_wrapper_i/gtx_channel.gtxe2_channel_i}]

# =============================================================================
# System Clocks (optional - if you need additional clocks)
# =============================================================================
# Y2 - 100MHz LVDS
# set_property PACKAGE_PIN U22 [get_ports sys_clk_p]
# set_property PACKAGE_PIN U23 [get_ports sys_clk_n]
# set_property IOSTANDARD LVDS_25 [get_ports sys_clk_p]
# set_property IOSTANDARD LVDS_25 [get_ports sys_clk_n]

# 100MHz LVCMOS single-ended
# set_property PACKAGE_PIN U24 [get_ports sys_clk_100]
# set_property IOSTANDARD LVCMOS25 [get_ports sys_clk_100]

# =============================================================================
# PSE Engine Ring Oscillator TRNG
# =============================================================================
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets -hierarchical -filter {NAME =~ *pse_engine*/inst/ro*/chain*}]
set_false_path -through [get_nets -hierarchical -filter {NAME =~ *pse_engine*/inst/ro*/chain*}]

# =============================================================================
# DRC Overrides
# =============================================================================
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
