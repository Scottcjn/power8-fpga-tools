# POWER8 FPGA Tools

FPGA programming tools ported to IBM POWER8 (ppc64le architecture).

## Tools Included

### xc3sprog (ppc64le)
Xilinx FPGA programmer supporting Platform Cable USB II on POWER8.
- Forked from: https://github.com/matrix-io/xc3sprog
- Build: `cmake .. -DUSE_WIRINGPI=OFF && make`

### xvcd (ppc64le)  
Xilinx Virtual Cable daemon for Platform Cable USB II.
- Enables remote JTAG programming via XVC protocol
- Compiled for ppc64le with libusb

## Hardware Tested
- IBM Power System S824 (POWER8)
- Xilinx Platform Cable USB II (03fd:0008)
- Kintex-7 XC7K480T FPGA

## Build Requirements (Ubuntu 20.04 ppc64le)
```bash
apt install git cmake g++ libusb-1.0-0-dev libftdi1-dev
```

## Usage

### xc3sprog
```bash
# Detect JTAG chain
./xc3sprog -c xpc

# Program bitstream
./xc3sprog -c xpc -v bitstream.bit
```

### xvcd
```bash
# Start XVC server on port 2542
./xvcd -v -p 2542
```

## License
xc3sprog: GPLv2
xvcd: MIT
