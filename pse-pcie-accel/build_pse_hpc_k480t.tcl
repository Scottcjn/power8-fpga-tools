# Build PSE PCIe Accelerator for HPC XC7K480T Chinese Board
# Uses correct pinout from: https://gist.github.com/Kohei-Toyoda/709a1adf5d3dacd196574dc702ed3b94

set project_name "pse_hpc_k480t"
set project_dir "/opt/Xilinx/projects/pse_pcie_accel"
set part "xc7k480tffg1156-2"

puts "=============================================="
puts "Building PSE for HPC XC7K480T Board"
puts "PCIe RefClk: AD6 (BANK 112)"
puts "PCIe Reset: W21"
puts "=============================================="

# Create project
create_project -force $project_name "$project_dir/$project_name" -part $part

# Set board-specific properties
set_property target_language Verilog [current_project]

# Create block design
create_bd_design "pse_system"

# Add AXI PCIe IP configured for BANK 112
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_pcie:2.9 axi_pcie_0

# Configure AXI PCIe for HPC board (Endpoint mode for this design)
set_property -dict [list \
    CONFIG.INCLUDE_RC {PCI_Express_Endpoint_device} \
    CONFIG.NO_OF_LANES {X8} \
    CONFIG.MAX_LINK_SPEED {2.5_GT/s} \
    CONFIG.DEVICE_ID {0x7028} \
    CONFIG.VENDOR_ID {0x10EE} \
    CONFIG.CLASS_CODE {0x058000} \
    CONFIG.BAR0_SCALE {Megabytes} \
    CONFIG.BAR0_SIZE {256} \
    CONFIG.PCIEBAR2AXIBAR_0 {0x00000000} \
    CONFIG.S_AXI_DATA_WIDTH {128} \
    CONFIG.M_AXI_DATA_WIDTH {128} \
    CONFIG.XLNX_REF_BOARD {None} \
    CONFIG.shared_logic_in_core {true} \
    CONFIG.REF_CLK_FREQ {100_MHz} \
] [get_bd_cells axi_pcie_0]

# Make PCIe MGT external
make_bd_intf_pins_external [get_bd_intf_pins axi_pcie_0/pcie_7x_mgt]

# The REFCLK is typically exposed as an interface when shared_logic_in_core=true
# Check what ports exist and make them external
catch {make_bd_intf_pins_external [get_bd_intf_pins axi_pcie_0/REFCLK]} result
if {$result ne ""} {
    puts "Note: REFCLK externalized as interface"
} else {
    # Try as regular pin if interface doesn't exist
    catch {make_bd_pins_external [get_bd_pins axi_pcie_0/REFCLK]}
}

# Create external port for reset (PERST# from PCIe slot)
# The AXI PCIe IP has a INTX_MSI_REQUEST or similar - we need the sys_rst_n input
create_bd_port -dir I -type rst pcie_perst_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports pcie_perst_n]

# Connect to the proper reset input - try common names
catch {connect_bd_net [get_bd_ports pcie_perst_n] [get_bd_pins axi_pcie_0/sys_rst_n]}
catch {connect_bd_net [get_bd_ports pcie_perst_n] [get_bd_pins axi_pcie_0/ext_reset_in]}

# Rename external interfaces - use catch to handle if port doesn't exist
catch {set_property name pcie_7x_mgt [get_bd_intf_ports pcie_7x_mgt_0]}
catch {set_property name pcie_refclk [get_bd_intf_ports REFCLK_0]}

# Create simple AXI interconnect for PSE engine connection point
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0
set_property -dict [list CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] [get_bd_cells axi_interconnect_0]

# For endpoint mode, reset is axi_aresetn (not axi_ctl_aresetn)
# Connect clocks
connect_bd_net [get_bd_pins axi_pcie_0/axi_aclk_out] [get_bd_pins axi_interconnect_0/ACLK]
connect_bd_net [get_bd_pins axi_pcie_0/axi_aclk_out] [get_bd_pins axi_interconnect_0/S00_ACLK]
connect_bd_net [get_bd_pins axi_pcie_0/axi_aclk_out] [get_bd_pins axi_interconnect_0/M00_ACLK]

# Connect resets using the correct pin name for endpoint mode
connect_bd_net [get_bd_pins axi_pcie_0/axi_aresetn] [get_bd_pins axi_interconnect_0/ARESETN]
connect_bd_net [get_bd_pins axi_pcie_0/axi_aresetn] [get_bd_pins axi_interconnect_0/S00_ARESETN]
connect_bd_net [get_bd_pins axi_pcie_0/axi_aresetn] [get_bd_pins axi_interconnect_0/M00_ARESETN]

# Connect AXI interfaces
connect_bd_intf_net [get_bd_intf_pins axi_pcie_0/M_AXI] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

# Validate and save
validate_bd_design
save_bd_design

# Generate output products
generate_target all [get_files "$project_dir/$project_name/$project_name.srcs/sources_1/bd/pse_system/pse_system.bd"]

# Create HDL wrapper
make_wrapper -files [get_files "$project_dir/$project_name/$project_name.srcs/sources_1/bd/pse_system/pse_system.bd"] -top
add_files -norecurse "$project_dir/$project_name/$project_name.gen/sources_1/bd/pse_system/hdl/pse_system_wrapper.v"

# Add HPC board constraints
add_files -fileset constrs_1 "$project_dir/pcie_hpc_k480t.xdc"

update_compile_order -fileset sources_1

# Run synthesis
synth_design -top pse_system_wrapper -part $part
report_timing_summary -file "$project_dir/$project_name/timing_synth.rpt"

# Run implementation
opt_design
place_design
route_design

report_timing_summary -file "$project_dir/$project_name/timing_impl.rpt"
report_utilization -file "$project_dir/$project_name/utilization.rpt"

# Generate bitstream
write_bitstream -force "$project_dir/pse_hpc_k480t.bit"

puts ""
puts "=============================================="
puts "BUILD COMPLETE!"
puts "Bitstream: $project_dir/pse_hpc_k480t.bit"
puts "=============================================="
