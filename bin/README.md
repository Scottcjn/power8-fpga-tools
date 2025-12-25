# Precompiled Binaries

## ppc64le (POWER8/POWER9)

Built on Ubuntu 20.04 ppc64le (IBM POWER8 S824)

### xc3sprog
```
ELF 64-bit LSB shared object, 64-bit PowerPC
Dependencies: libusb-1.0, libftdi1
```

### xvcd  
```
ELF 64-bit LSB shared object, 64-bit PowerPC
Dependencies: libusb-1.0
```

### detectchain
```
Quick JTAG chain detection utility
```

## Usage
```bash
chmod +x bin/ppc64le/*
./bin/ppc64le/xc3sprog -c xpc  # Detect via Platform Cable USB II
./bin/ppc64le/xvcd -p 2542     # Start XVC server
```
