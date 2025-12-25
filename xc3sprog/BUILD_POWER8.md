# Building xc3sprog on POWER8 (ppc64le)

## Clone
```bash
git clone https://github.com/matrix-io/xc3sprog.git
cd xc3sprog
```

## Build (disable wiringPi - Raspberry Pi only)
```bash
mkdir build && cd build
cmake .. -DUSE_WIRINGPI=OFF
make -j4
```

## Result
```
./xc3sprog: ELF 64-bit LSB shared object, 64-bit PowerPC
```

## Cable Support
- `xpc` - Xilinx Platform Cable USB II (03fd:0008)
- Full list: `./xc3sprog -c`
