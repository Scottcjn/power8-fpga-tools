# Minimal K480T test - forces DONE high
set part "xc7k480tffg1156-2"
set project_name "minimal_k480t"
set project_dir "/opt/Xilinx/projects/pse_pcie_accel"

create_project -force $project_name "$project_dir/$project_name" -part $part

# Minimal design with one LUT
set verilog {
module minimal_top ();
    // Minimal inverter chain that can't be optimized away
    (* DONT_TOUCH = "TRUE", ALLOW_COMBINATORIAL_LOOPS = "TRUE" *)
    wire [3:0] chain;
    assign chain[0] = ~chain[3];
    assign chain[1] = chain[0];
    assign chain[2] = chain[1];
    assign chain[3] = chain[2];
endmodule
}

set fp [open "$project_dir/$project_name/minimal.v" w]
puts $fp $verilog
close $fp

add_files "$project_dir/$project_name/minimal.v"

# Critical bitstream options for HPC K480T board
set xdc {
# Standard config - HPC board uses 2.5V for config bank
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
# Disable compression for debugging
set_property BITSTREAM.GENERAL.COMPRESS FALSE [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]
set_property CFGBVS VCCO [current_design]

# CRITICAL: Force DONE pin to be actively driven (not just pull-up)
set_property BITSTREAM.CONFIG.DRIVEDONE YES [current_design]

# Startup clock - use JTAG clock for JTAG programming
set_property BITSTREAM.STARTUP.STARTUPCLK JTAGCLK [current_design]
set_property BITSTREAM.CONFIG.CONFIGFALLBACK DISABLE [current_design]

# Allow configuration to proceed even without DONE acknowledge
set_property BITSTREAM.STARTUP.DONE_PIPE NO [current_design]
set_property BITSTREAM.STARTUP.GTS_CYCLE 1 [current_design]
set_property BITSTREAM.STARTUP.GWE_CYCLE 2 [current_design]
set_property BITSTREAM.STARTUP.LCK_CYCLE NOWAIT [current_design]
set_property BITSTREAM.STARTUP.DONE_CYCLE 3 [current_design]

# Set unused pins to pull-down to avoid floating inputs
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLDOWN [current_design]

# Allow the ring oscillator
set_property ALLOW_COMBINATORIAL_LOOPS TRUE [get_nets chain*]
set_false_path -through [get_nets chain*]

# Override DRC for minimal design
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
}

set fp [open "$project_dir/$project_name/minimal.xdc" w]
puts $fp $xdc
close $fp

add_files -fileset constrs_1 "$project_dir/$project_name/minimal.xdc"
update_compile_order -fileset sources_1

synth_design -top minimal_top -part $part
opt_design
place_design
route_design
write_bitstream -force "$project_dir/minimal_k480t.bit"

puts "Minimal K480T bitstream: $project_dir/minimal_k480t.bit"
