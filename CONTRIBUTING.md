# Contributing to POWER8 FPGA Programming Tools

Thanks for improving the POWER8 FPGA tooling notes and ports. This repository
tracks FPGA programming workflows on ppc64le systems, so contributions should
be precise about host hardware, cable adapters, FPGA boards, and tool versions.

## Useful Contributions

- Add verified programming notes for additional Xilinx/AMD boards.
- Improve POWER8 or ppc64le build instructions for included tools.
- Document JTAG adapter behavior and cable compatibility.
- Clarify pinout, IDCODE, or PCIe lane notes with cited sources.
- Add troubleshooting steps for common programming failures.

## Development Workflow

1. Fork the repository and create a focused branch.
2. Keep documentation, patches, and build changes separated when possible.
3. Cite datasheets, board schematics, or upstream tool documentation when adding
   hardware-specific details.
4. Include the exact host, board, adapter, and command used for validation.

## Validation

- Documentation-only changes: run `git diff --check`.
- Build changes: include compiler, OS, architecture, and build command.
- Hardware workflow changes: include board model, FPGA part, adapter/cable,
  command output, and whether programming completed successfully.

## Pull Request Checklist

- The affected board/tool is named clearly.
- Validation commands and hardware details are included.
- New hardware facts cite a public source or measured result.
- The PR avoids committing generated bitstreams or local build artifacts unless
  they are intentionally versioned.
- Any safety-sensitive hardware step is clearly marked.

## Reporting Issues

Please include the POWER system model, Linux distribution, FPGA board, adapter,
tool command, and full output. If the problem is board-specific, include the
reported IDCODE and any relevant jumper or cable setup details.
