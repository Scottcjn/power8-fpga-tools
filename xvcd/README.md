Xilinx Virtual Cable server for Xilinx Platform Cable II
========================================================

What is that ???
----------------

My issue was simple and common: I wanted to use ChipScopePro on a remote
linux computer.  The linux drivers provided by Xilinx are very old (as old
as ISE), so they don't work on my computer.

There is http://www.rmdir.de/~michael/xilinx/ but I was not able to run it
(althought I was in the past).

How to use it ?
---------------

Plug the Xilinx Cable II.
It first appears as:

```
$ lsusb
Bus 001 Device 011: ID 03fd:0013 Xilinx, Inc.
```

You then need to program its firmware.

```
$ sudo fxload -v -t fx2 -I xusb_xp2.hex -D /dev/bus/usb/BUS/DEV
```

(xusb_xp2.hex can be found in ISE installs).

The device now appears as:

```
$ lsusb
Bus 001 Device 013: ID 03fd:0008 Xilinx, Inc. Platform Cable USB II
```

Start the server:
```
$ sudo xvcd
```

Open ChipScope.

```
$ analyzer
```

In menu `JTAG Chain`, click on `Open Plug-In`, and set:

```
xilinx_xvc host=HOST:2542 disableversioncheck=true
```


The procotol is documented on https://github.com/Xilinx/XilinxVirtualCable


Copyright License
-----------------

GPL

The code for xpc.c is derived from:
https://sourceforge.net/p/urjtag/git/ci/master/tree/

The code for xvcd.c is derived from:
https://github.com/tmbinc/xvcd/blob/ftdi/src/xvcd.c


Other references
----------------

Discussion about XPCU-II schematics (but 404):
https://www.mikrocontroller.net/topic/142358?page=single

Open-source firmware for USB JTAG:
https://github.com/mithro/ixo-usb-jtag

An open-source USB JTAG adapter:
https://www.geek-share.com/detail/2395472121.html
