# Contributing to POWER8 FPGA Programming Tools

Thanks for helping improve the POWER8 FPGA toolchain. This repository is focused on programming and debugging Xilinx/AMD 7-series FPGA boards from ppc64le POWER8 systems, so contributions should preserve the hardware-specific assumptions documented in the README and troubleshooting notes.

## Repository Layout

- `bin/ppc64le/` contains prebuilt POWER8/POWER9 binaries for `xc3sprog`, `xvcd`, and `detectchain`.
- `xvcd/` contains the Xilinx Virtual Cable daemon source used with Platform Cable USB II.
- `xc3sprog/BUILD_POWER8.md` documents how the ppc64le `xc3sprog` binary was built.
- `pse-pcie-accel/` contains Vivado Tcl build scripts and XDC constraints for the Kintex-7 K480T PCIe accelerator project.
- `TROUBLESHOOTING.md` records board-level configuration and startup diagnostics.

## Development Setup

Use a ppc64le Linux environment when validating binaries or POWER8-specific behavior. The current notes target Ubuntu 20.04 on IBM POWER8 S824 hardware.

Install the common build tools:

```bash
sudo apt update
sudo apt install build-essential git cmake libusb-1.0-0-dev libftdi1-dev fxload
```

For Vivado project changes, install a Vivado version that supports Kintex-7 devices and make sure your license is available:

```bash
export XILINXD_LICENSE_FILE=/path/to/Xilinx.lic
```

If you are testing Platform Cable USB II, confirm the cable enumerates as `03fd:0008` after firmware loading. The pre-firmware ID is commonly `03fd:0013`; see `xvcd/README.md` for the `fxload` flow.

## Build And Test Checks

For `xvcd` source changes, build from the source directory:

```bash
make -C xvcd clean
make -C xvcd
```

For `xc3sprog` rebuilds, follow `xc3sprog/BUILD_POWER8.md` and keep `-DUSE_WIRINGPI=OFF`, since WiringPi is Raspberry Pi-specific.

For Vivado Tcl or XDC changes, run the relevant batch build when you have Vivado available:

```bash
vivado -mode batch -source pse-pcie-accel/build_pse_hpc_k480t.tcl
```

Before opening a PR, run the checks that match your change:

```bash
git diff --check
make -C xvcd
```

Hardware validation is encouraged when available:

```bash
./bin/ppc64le/xc3sprog -c xpc_usb -j
./bin/ppc64le/detectchain
```

If your cable setup uses `xpc` instead of `xpc_usb`, mention that in the PR along with the `xc3sprog -c` output.

## Hardware Safety

FPGA programming changes can affect real boards. Use the documented K480T/HPC pinout unless you are intentionally adding another board target.

- Verify the exact FPGA part, package, and speed grade before changing Tcl scripts or XDC constraints.
- Keep PCIe lane, reference clock, and reset pin changes tied to board documentation.
- Do not replace the existing K480T constraints with a different board variant unless the old target remains available.
- When troubleshooting DONE/INIT_B failures, update `TROUBLESHOOTING.md` with measured evidence instead of guessing.
- Avoid committing generated Vivado project directories, bitstreams, logs, or timing reports unless a maintainer asks for a release artifact.

## Coding Style

For C code in `xvcd/`:

- Keep the code compatible with GCC on ppc64le Linux.
- Preserve `-Wall` cleanliness from the existing Makefile.
- Prefer small, explicit error paths for USB and socket failures.
- Do not introduce architecture-specific assumptions without guarding or documenting them.
- Keep protocol changes compatible with Xilinx Virtual Cable clients.

For Tcl and XDC files:

- Keep board-specific constants near the top of the file.
- Use clear names for ports, clocks, resets, and PCIe interfaces.
- Include comments for non-obvious pinout or voltage assumptions.
- Keep generated output paths out of the repository unless they are intentional examples.

For documentation:

- Prefer commands that work on POWER8 Ubuntu systems.
- Call out when a command requires physical hardware, root privileges, Vivado, or a Xilinx license.
- Keep board IDs, IDCODEs, and cable IDs exact.

## Pull Request Guidelines

Open focused PRs. A good PR usually changes one of these areas:

- A documentation fix or setup clarification.
- An `xvcd` build or runtime fix.
- A board-specific Tcl/XDC update.
- A new tested ppc64le binary with matching build notes.

Include the following in the PR description:

- What hardware or host OS you used, if any.
- Which commands you ran.
- Whether Vivado, JTAG hardware, or physical FPGA validation was available.
- Any new failure mode added to `TROUBLESHOOTING.md`.

If you update prebuilt binaries, include the source commit, build command, target architecture, and `file` output for the binary.

## Reporting Problems

When reporting an issue, include:

- Host system and OS version.
- FPGA board and part marking.
- Cable type and USB ID from `lsusb`.
- Exact command and output.
- Whether DONE, INIT_B, or other board LEDs changed.
- Relevant voltage or jumper observations, if you have them.

Clear hardware context helps maintainers distinguish tool bugs from board startup, power, or pinout problems.
