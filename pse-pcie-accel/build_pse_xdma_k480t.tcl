# Build PSE Collapse Engine with AXI PCIe for Kintex-7 K420T
# Target: POWER8 S824 PCIe slot
# Gen1 x8 = 2.5 GB/s theoretical bandwidth

set project_name "pse_xdma_k480t"
set project_dir "/opt/Xilinx/projects/pse_pcie_accel"
set part "xc7k480tffg1156-2"

puts "=============================================="
puts "PSE PCIe Build for Kintex-7 K420T"
puts "Gen1 x8 PCIe with AXI Interface"
puts "=============================================="

# Create project
create_project $project_name $project_dir/$project_name -part $part -force
set_property target_language Verilog [current_project]

# Add PSE RTL
add_files -norecurse $project_dir/rtl/pse_collapse_engine.v
update_compile_order -fileset sources_1

# Create block design
create_bd_design "pse_system"

# Add AXI PCIe IP
puts "Adding AXI PCIe IP (Gen1 x8)..."
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_pcie:2.9 axi_pcie_0

# Configure AXI PCIe for Gen1 x8 Endpoint
set_property -dict [list \
    CONFIG.INCLUDE_RC {PCI_Express_Endpoint_device} \
    CONFIG.AXIBAR_NUM {1} \
    CONFIG.AXIBAR_0 {0x00000000} \
    CONFIG.AXIBAR_HIGHADDR_0 {0x1FFFFFFF} \
    CONFIG.DEVICE_ID {0x7028} \
    CONFIG.REV_ID {0x00} \
    CONFIG.SUBSYSTEM_ID {0x0007} \
    CONFIG.SUBSYSTEM_VENDOR_ID {0x10EE} \
    CONFIG.CLASS_CODE {0x120000} \
    CONFIG.BAR0_SCALE {Megabytes} \
    CONFIG.BAR0_SIZE {2} \
    CONFIG.BAR0_ENABLED {true} \
    CONFIG.BAR_64BIT {true} \
    CONFIG.NO_OF_LANES {X8} \
    CONFIG.MAX_LINK_SPEED {2.5_GT/s} \
    CONFIG.S_AXI_DATA_WIDTH {128} \
    CONFIG.M_AXI_DATA_WIDTH {128} \
    CONFIG.PCIEBAR2AXIBAR_0 {0x00000000} \
    CONFIG.INTERRUPT_PIN {true} \
    CONFIG.REF_CLK_FREQ {100_MHz} \
    CONFIG.shared_logic_in_core {true} \
    CONFIG.PCIE_BLK_LOCN {X0Y0} \
] [get_bd_cells axi_pcie_0]

# Add PSE Collapse Engine as RTL module
puts "Adding PSE Collapse Engine..."
create_bd_cell -type module -reference pse_collapse_engine pse_engine_0

# Add AXI Interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.NUM_MI {2} CONFIG.NUM_SI {1}] [get_bd_cells axi_interconnect_0]

# Add AXI FIFO for streaming
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_fifo_mm_s:4.3 axi_fifo_0
set_property -dict [list \
    CONFIG.C_USE_TX_DATA {1} \
    CONFIG.C_USE_RX_DATA {1} \
    CONFIG.C_DATA_INTERFACE_TYPE {1} \
] [get_bd_cells axi_fifo_0]

# Add Processor System Reset
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0

# Add GT clock buffer (IBUFDS_GTE2) for PCIe reference clock
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0
set_property -dict [list CONFIG.C_BUF_TYPE {IBUFDSGTE}] [get_bd_cells util_ds_buf_0]

# Connect interfaces
puts "Connecting interfaces..."

# PCIe AXI Master to Interconnect
connect_bd_intf_net [get_bd_intf_pins axi_pcie_0/M_AXI] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# Interconnect to PSE engine control (AXI-Lite)
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins pse_engine_0/s_axil]

# Interconnect to FIFO
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_fifo_0/S_AXI]

# FIFO streaming to PSE engine
connect_bd_intf_net [get_bd_intf_pins axi_fifo_0/AXI_STR_TXD] [get_bd_intf_pins pse_engine_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins pse_engine_0/m_axis] [get_bd_intf_pins axi_fifo_0/AXI_STR_RXD]

# Create PCIe external ports for MGT
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie_7x_mgt
connect_bd_intf_net [get_bd_intf_pins axi_pcie_0/pcie_7x_mgt] [get_bd_intf_ports pcie_7x_mgt]

# Create PCIe reference clock port (differential)
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk
set_property -dict [list CONFIG.FREQ_HZ {100000000}] [get_bd_intf_ports pcie_refclk]

# Connect differential clock to buffer, then buffer output to PCIe REFCLK
connect_bd_intf_net [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins axi_pcie_0/REFCLK]

# PCIe reset
create_bd_port -dir I -type rst pcie_perst_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports pcie_perst_n]
connect_bd_net [get_bd_ports pcie_perst_n] [get_bd_pins axi_pcie_0/axi_aresetn]

# Get clocks from AXI PCIe (output clock)
set axi_aclk [get_bd_pins axi_pcie_0/axi_aclk_out]

# Connect proc_sys_reset
connect_bd_net $axi_aclk [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_ports pcie_perst_n] [get_bd_pins proc_sys_reset_0/ext_reset_in]
set aresetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn]

# Connect all clocks to AXI clock output
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect_0/M00_ACLK]
connect_bd_net $axi_aclk [get_bd_pins axi_interconnect_0/M01_ACLK]
connect_bd_net $axi_aclk [get_bd_pins pse_engine_0/clk]
connect_bd_net $axi_aclk [get_bd_pins axi_fifo_0/s_axi_aclk]

# Connect resets
connect_bd_net $aresetn [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net $aresetn [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_net $aresetn [get_bd_pins axi_interconnect_0/M00_ARESETN]
connect_bd_net $aresetn [get_bd_pins axi_interconnect_0/M01_ARESETN]
connect_bd_net $aresetn [get_bd_pins pse_engine_0/rst_n]
connect_bd_net $aresetn [get_bd_pins axi_fifo_0/s_axi_aresetn]

# Connect interrupt from PSE to PCIe
connect_bd_net [get_bd_pins pse_engine_0/irq_done] [get_bd_pins axi_pcie_0/INTX_MSI_Request]

# Assign addresses
assign_bd_address

# Validate design
puts "Validating design..."
validate_bd_design
save_bd_design

# Generate output products
puts "Generating output products..."
generate_target all [get_files $project_dir/$project_name/$project_name.srcs/sources_1/bd/pse_system/pse_system.bd]

# Create HDL wrapper
make_wrapper -files [get_files $project_dir/$project_name/$project_name.srcs/sources_1/bd/pse_system/pse_system.bd] -top
add_files -norecurse $project_dir/$project_name/$project_name.gen/sources_1/bd/pse_system/hdl/pse_system_wrapper.v
update_compile_order -fileset sources_1
set_property top pse_system_wrapper [current_fileset]

# Add constraints
add_files -fileset constrs_1 $project_dir/pcie_k480t.xdc

# Run synthesis (use launch_runs for proper project flow)
puts "Running synthesis..."
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
write_checkpoint -force $project_dir/post_synth.dcp

# Run implementation
puts "Running implementation..."
launch_runs impl_1 -jobs 4
wait_on_run impl_1
open_run impl_1
write_checkpoint -force $project_dir/post_route.dcp

# Set pre-hook for bitstream generation (to override DRC severity)
set_property STEPS.WRITE_BITSTREAM.TCL.PRE $project_dir/bitgen_pre_hook.tcl [get_runs impl_1]

# Generate bitstream
puts "Generating bitstream..."
reset_run impl_1 -from_step write_bitstream
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
file copy -force $project_dir/$project_name/$project_name.runs/impl_1/pse_system_wrapper.bit $project_dir/pse_xdma_k480t.bit

puts "=============================================="
puts "BUILD COMPLETE!"
puts "Bitstream: $project_dir/pse_xdma_k480t.bit"
puts "=============================================="
