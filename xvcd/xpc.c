/*
 * $Id$
 *
 * Xilinx Platform Cable USB Driver (slow GPIO only)
 * Copyright (C) 2008 Kolja Waschk
 *
 * Loosely based on Xilinx DLC5 JTAG Parallel Cable III Driver
 * Copyright (C) 2002, 2003 ETC s.r.o.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 *
 */

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

#include <libusb-1.0/libusb.h>

#include "xpc.h"

#define URJ_STATUS_FAIL -1
#define URJ_STATUS_OK 0

#define URJ_LOG_LEVEL_NORMAL 1
#define URJ_LOG_LEVEL_DETAIL 2

//#define VERBOSE 1
//#undef VERBOSE

static void
urj_log(unsigned level, const char *msg, ...)
{
    va_list args;
    va_start(args, msg);

    vprintf(msg, args);
    va_end(args);
}

/* Connectivity on Spartan-3E starter kit:
 *
 * = FX2 Port A =
 *
 *   IOA.0 => green LED (0=off)
 *   IOA.1 => red LED   (0=off)
 *   IOA.2 is tied to VCC via R25 on my board
 *   IOA.3 isn't connected
 *   IOA.4 => CPLD pin 85 (reset?)
 *   IOA.5 => CPLD pin 86, eventually OE?
 *   IOA.6 => CPLD pin 83 (reset?)
 *   IOA.7 => CPLD pin 49 (reset?)
 *
 * = FX2 Port C =
 *
 *   probably used as GPIFADR 0..7, to CPLD
 *
 * = FX2 Port E =
 *
 *   IOE.3 => CPLD TCK
 *   IOE.4 => CPLD TMS
 *   IOE.5 => CPLD TDO
 *   IOE.6 => CPLD TDI
 */

/* ---------------------------------------------------------------------- */

static int
xpcu_output_enable (struct libusb_device_handle *xpcu, int enable)
{
    if (libusb_control_transfer
        (xpcu, 0x40, 0xB0, enable ? 0x18 : 0x10, 0, NULL, 0, 1000) < 0)
    {
        fprintf(stderr, "libusb_control_transfer(0x10/0x18)\n");
        return URJ_STATUS_FAIL;
    }

    return URJ_STATUS_OK;
}

/* ----------------------------------------------------------------- */

static int
xpcu_request_28 (struct libusb_device_handle *xpcu, int value)
{
    /* Typical values seen during autodetection of chain configuration: 0x11, 0x12 */

    if (libusb_control_transfer (xpcu, 0x40, 0xB0, 0x0028, value, NULL, 0, 1000) < 0)
    {
        fprintf(stderr, "libusb_control_transfer(0x28.x)");
        return URJ_STATUS_FAIL;
    }

    return URJ_STATUS_OK;
}

/* ---------------------------------------------------------------------- */

static int
xpcu_write_gpio (struct libusb_device_handle *xpcu, uint8_t bits)
{
    if (libusb_control_transfer (xpcu, 0x40, 0xB0, 0x0030, bits, NULL, 0, 1000) < 0)
    {
        fprintf(stderr, "libusb_control_transfer(0x30.0x00) (write port E)");
        return URJ_STATUS_FAIL;
    }

    return URJ_STATUS_OK;
}

/* ---------------------------------------------------------------------- */


static int
xpcu_read_cpld_version (struct libusb_device_handle *xpcu, uint16_t *buf)
{
    if (libusb_control_transfer
        (xpcu, 0xC0, 0xB0, 0x0050, 0x0001, (unsigned char *) buf, 2, 1000) < 0)
    {
        fprintf(stderr, "libusb_control_transfer(0x50.1) (read_cpld_version)");
        return URJ_STATUS_FAIL;
    }
    return URJ_STATUS_OK;
}

/* ---------------------------------------------------------------------- */

static int
xpcu_read_firmware_version (struct libusb_device_handle *xpcu, uint16_t *buf)
{
    if (libusb_control_transfer
        (xpcu, 0xC0, 0xB0, 0x0050, 0x0000, (unsigned char *) buf, 2, 1000) < 0)
    {
        fprintf(stderr, "libusb_control_transfer(0x50.0) (read_firmware_version)");
        return URJ_STATUS_FAIL;
    }

    return URJ_STATUS_OK;
}

/* ----------------------------------------------------------------- */

static int
xpcu_select_gpio (struct libusb_device_handle *xpcu, int int_or_ext)
{
    if (libusb_control_transfer (xpcu, 0x40, 0xB0, 0x0052, int_or_ext, NULL, 0, 1000)
        < 0)
    {
        fprintf(stderr, "libusb_control_transfer(0x52.x) (select gpio)");
        return URJ_STATUS_FAIL;
    }

    return URJ_STATUS_OK;
}

/* ---------------------------------------------------------------------- */

/* === A6 transfer (TDI/TMS/TCK/RDO) ===
 *
 *   Vendor request 0xA6 initiates a quite universal shift operation. The data
 *   is passed directly to the CPLD as 16-bit words.
 *
 *   The argument N in the request specifies the number of state changes/bits.
 *
 *   State changes are described by the following bulk write. It consists
 *   of ceil(N/4) little-endian 16-bit words, each describing up to 4 changes:
 *
 *   Care has to be taken that N is NOT a multiple of 4.
 *   The CPLD doesn't seem to handle that well.
 *
 *   Bit 0: Value for first TDI to shift out.
 *   Bit 1: Second TDI.
 *   Bit 2: Third TDI.
 *   Bit 3: Fourth TDI.
 *
 *   Bit 4: Value for first TMS to shift out.
 *   Bit 5: Second TMS.
 *   Bit 6: Third TMS.
 *   Bit 7: Fourth TMS.
 *
 *   Bit 8: Whether to raise/lower TCK for first bit.
 *   Bit 9: Same for second bit.
 *   Bit 10: Third bit.
 *   Bit 11: Fourth bit.
 *
 *   Bit 12: Whether to read TDO for first bit
 *   Bit 13: Same for second bit.
 *   Bit 14: Third bit.
 *   Bit 15: Fourth bit.
 *
 *   After the bulk write, if any of the bits 12..15 was set in any word, a
 *   bulk_read shall follow to collect the TDO data.
 *
 *   TDO data is shifted in from MSB. In a "full" word with 16 TDO bits, the
 *   earliest one reached bit 0. The earliest of 15 bits however would be bit 0,
 *   and if there's only one TDO bit, it arrives as the MSB of the word.
 */

/** @return 0 on success; -1 on error */
static int
xpcu_shift (struct libusb_device_handle *xpcu, int bits, uint8_t *in,
            int out_len, uint8_t *out)
{
    int ret, actual;
    int reqno = 0xA6;
    int in_len = 2 * ((bits + 3) >> 2);

    ret = libusb_control_transfer (xpcu, 0x40, 0xB0, reqno, bits, NULL, 0, 1000);
    if (ret < 0) {
        fprintf(stderr, "libusb_control_transfer(x.x) (shift)\n");
        return -1;
    }

#if VERBOSE
    {
        int i;
        urj_log (URJ_LOG_LEVEL_DETAIL, "DLC9 A6 inbits=%u, outlen=%u",
                 bits, out_len);
        for (i = 0; i < in_len; i += 2)
            urj_log (URJ_LOG_LEVEL_DETAIL, "  %02X %02X", in[i], in[i+1]);
        urj_log (URJ_LOG_LEVEL_DETAIL, " -> ");
    }
#endif

    ret = libusb_bulk_transfer (xpcu, 0x02, in, in_len, &actual, 1000);
    if (ret) {
        fprintf(stderr, "usb_bulk_write error(shift): %d (transferred %d)\n",
                          ret, actual);
        return -1;
    }

    if (out_len > 0) {
        ret = libusb_bulk_transfer (xpcu, 0x06 | LIBUSB_ENDPOINT_IN, out, out_len, &actual, 1000);
        if (ret) {
            fprintf(stderr, "usb_bulk_transfer error(shift): %d %s (transferred %d)\n",
                    ret, libusb_strerror(ret), actual);
            return -1;
        }
    }
#if VERBOSE
    {
        int i;
        for (i = 0; i < out_len; i++)
            urj_log (URJ_LOG_LEVEL_DETAIL, " %02X", out[i]);
        urj_log (URJ_LOG_LEVEL_DETAIL, "\n");
    }
#endif

    return 0;
}

/* ---------------------------------------------------------------------- */

static struct libusb_device_handle *
io_open_dev (struct libusb_device **devs, unsigned vendor, unsigned product)
{
  int res;
  unsigned i;
  struct libusb_device *dev;
  struct libusb_device_handle *hand;

  if (verbose)
      fprintf (stderr, "Looking for USB %04x:%04x\n", vendor, product);

  for (i = 0; ; i++) {
      struct libusb_device_descriptor desc;
      int iconf;

      dev = devs[i];

      if (dev == NULL)
          break;

      res = libusb_get_device_descriptor(dev, &desc);
      if (res < 0) {
          fprintf(stderr, "failed to get device descriptor");
          return NULL;
      }

      if (verbose)
          fprintf (stderr, "USB %04x:%04x\n",
                   desc.idVendor, desc.idProduct);

      if (desc.idVendor == vendor && desc.idProduct == product)  {
          res = libusb_open(dev, &hand);
          if (res != 0) {
              fprintf(stderr, "usb_open failed (%d)\n", res);
              return NULL;
          }

          res = libusb_reset_device(hand);
          if (res != 0) {
              fprintf(stderr, "usb reset device failed (%d)\n", res);
              return NULL;
          }

#if 0
        if (description != NULL) {
            char string[256];
            if (libusb_get_string_descriptor(xpcu, dev->descriptor.iProduct,
                                      string, sizeof(string)) <= 0)
              {
                usb_close (xpcu);
                xpc_error_return(-8,
                                 "unable to fetch product description");
              }
            if (strncmp(string, description, sizeof(string)) != 0)
              {
                if (usb_close (xpcu) != 0)
                  xpc_error_return(-10, "unable to close device");
                continue;
              }
          }
#endif

        res = libusb_get_configuration(hand, &iconf);
        if (res < 0) {
            fprintf(stderr,
                    "io_init: cannot get config descriptor (%d)\n", res);
            goto error;
        }

#if 0
        /* Not working ?? */
        {
            struct libusb_config_descriptor *conf;
            res = libusb_get_config_descriptor(dev, 0, &conf);
            if (res < 0) {
                fprintf(stderr,
                        "io_init: cannot get config descriptor (%d)\n", res);
                goto error;
            }
            iconf = conf->bConfigurationValue;
            libusb_free_config_descriptor(conf);
        }
#endif

        res = libusb_set_configuration (hand, iconf);
        if (res < 0) {
            fprintf (stderr, "usb_set_configuration: failed conf %d: %s\n",
                     iconf, libusb_strerror(res));
            goto error;
          }

        res = libusb_claim_interface (hand, 0);
        if (res < 0){
            fprintf (stderr, "io_init:usb_claim_interface: failed interface 0\n");
          fprintf (stderr, " %s\n", libusb_strerror(res));
          goto error;
        }
#if 0
        int rc = xpcu_read_hid(xpcu);
        if (rc < 0)
          {
            if (rc == -EPIPE)
              {
                if (lserial != 0)
                  {
                    hint_loadfirmware(dev);
                    return 0;
                  }
              }
            else
              fprintf(stderr, "usb_control_msg(0x42.1 %s\n",
                      usb_strerror());
          }
        else
          if ((lserial != 0) && (lserial != hid))
            {
              usb_close (xpcu);
              continue;
            }
#endif
        return hand;
      }
  }

  // device not found
  fprintf(stderr, "No USB probe found\n");
  return NULL;

error:
  libusb_close (hand);
  return NULL;
}

static struct libusb_device_handle *
io_open (unsigned vendor, unsigned product)
{
  int cnt;
  struct libusb_device **devs;
  struct libusb_device_handle *hand;

  cnt = libusb_get_device_list(NULL, &devs);
  if (cnt < 0) {
    fprintf (stderr, "libusb: cannot get device list (%d)\n", cnt);
    return NULL;
  }

  hand = io_open_dev(devs, vendor, product);

  libusb_free_device_list(devs, 1);

  return hand;
}

struct libusb_device_handle *global_xpcu;

static int
xpcu_common_init (unsigned vendor, unsigned product, const char *desc)
{
    int r;
    uint16_t buf;
    struct libusb_device_handle *xpcu;

    r = libusb_init(NULL);
    if (r < 0) {
        fprintf (stderr, "libusb: cannot initialize (%d)\n", r);
        return -1;
    }

    xpcu = io_open(vendor, product);

    if (xpcu == NULL) {
        libusb_exit(NULL);
        return -1;
    }

    global_xpcu = xpcu;

    r = xpcu_request_28 (xpcu, 0x11);
    if (r != URJ_STATUS_FAIL)
        r = xpcu_write_gpio (xpcu, 8);

    /* Read firmware version (constant embedded in firmware) */

    if (r != URJ_STATUS_FAIL)
        r = xpcu_read_firmware_version (xpcu, &buf);
    if (r != URJ_STATUS_FAIL)
        if (verbose)
            fprintf (stderr, "firmware version = 0x%04X (%u)\n", buf, buf);

    /* Read CPLD version (via GPIF) */

    if (r != URJ_STATUS_FAIL)
        // @@@@ RFHH added assignment of result to r:
        r = xpcu_read_cpld_version (xpcu, &buf);
    if (r != URJ_STATUS_FAIL) {
        if (verbose)
            fprintf (stderr, "cable CPLD version = 0x%04X (%u)\n", buf, buf);
        if (buf == 0) {
            urj_log (URJ_LOG_LEVEL_NORMAL,
                     "version '0' can't be correct. Please try resetting the cable\n");
            r = URJ_STATUS_FAIL;
        }
    }

    if (r != URJ_STATUS_OK)
        libusb_close (xpcu);

    return r;
}

static int
xpc_int_init (void)
{
    struct libusb_device_handle *xpcu = global_xpcu;

    if (xpcu_select_gpio (xpcu, 0) == URJ_STATUS_FAIL)
        return URJ_STATUS_FAIL;

    return URJ_STATUS_OK;
}

static int
xpc_ext_init (void)
{
    struct libusb_device_handle *xpcu = global_xpcu;
    uint8_t zero[2] = { 0, 0 };
    int r;

    r = xpcu_output_enable (xpcu, 0);
    if (r == URJ_STATUS_OK)
        r = xpcu_request_28 (xpcu, 0x11);
    if (r == URJ_STATUS_OK)
        r = xpcu_output_enable (xpcu, 1);
    if (r == URJ_STATUS_OK)
        r = xpcu_shift (xpcu, 2, zero, 0, NULL) == -1
            ? URJ_STATUS_FAIL : URJ_STATUS_OK;
    if (r == URJ_STATUS_OK)
        r = xpcu_request_28 (xpcu, 0x12);

    return r;
}

int
io_init (unsigned vendor, unsigned product, const char *desc)
{
    int r;

    r = xpcu_common_init (vendor, product, desc);
    if (r == URJ_STATUS_FAIL)
        return r;

    if (1)
        r = xpc_ext_init();
    else
        r = xpc_int_init();

    if (r != URJ_STATUS_OK) {
        libusb_close (global_xpcu);
        libusb_exit(NULL);
        global_xpcu = NULL;
    }

    return r;
}

/* ---------------------------------------------------------------------- */

/* 16-bit words. More than 4 currently leads to bit errors; 13 to serious problems */
#define XPC_A6_CHUNKSIZE 4

typedef struct
{
    struct libusb_device_handle *xpcu;
    int in_bits;
    int out_bits;
    int out_done;
    uint8_t *out;
    uint8_t buf[XPC_A6_CHUNKSIZE * 2];
}
xpc_ext_transfer_state_t;

/* ---------------------------------------------------------------------- */

/** @return 0 on success; -1 on error */
static int
xpcu_do_ext_transfer (xpc_ext_transfer_state_t *xts)
{
    int r;
    int out_len;

    out_len = 2 * ((xts->out_bits + 15) >> 4);

    r = xpcu_shift (xts->xpcu, xts->in_bits, xts->buf, out_len, xts->buf);

    if (r == 0) {
        int out_idx = 0;
        int out_rem = xts->out_bits;

        while (out_rem > 0)
        {
            uint32_t mask, rxw;

            rxw = (xts->buf[out_idx + 1] << 8) | xts->buf[out_idx];

            /* In the last (incomplete) word, the data isn't shifted completely to LSB */

            mask = (out_rem >= 16) ? 1 : (1 << (16 - out_rem));

            while (mask <= (1 << 15) && out_rem > 0)
            {
                unsigned last_tdo = (rxw & mask) ? 1 : 0;
                if ((xts->out_done & 7) == 0)
                    xts->out[xts->out_done >> 3] = last_tdo;
                else
                    xts->out[xts->out_done >> 3] |= last_tdo << (xts->out_done & 7);
                xts->out_done++;
                mask <<= 1;
                out_rem--;
            }

            out_idx += 2;
        }
    }

    xts->in_bits = 0;
    xts->out_bits = 0;

    return r;
}

/* ---------------------------------------------------------------------- */

static void
xpcu_add_bit_for_ext_transfer (xpc_ext_transfer_state_t *xts,
                               unsigned tdi, unsigned tms,
                               int is_real)
{
    int bit_idx = (xts->in_bits & 3);
    int buf_idx = (xts->in_bits - bit_idx) >> 1;

    if (bit_idx == 0) {
        /* Clear for the next chunk. */
        xts->buf[buf_idx] = 0;
        xts->buf[buf_idx + 1] = 0;
    }

    xts->in_bits++;

    if (is_real)
    {
        xts->buf[buf_idx] |= ((tms << 4) | tdi) << bit_idx;
        xts->buf[buf_idx + 1] |= (0x11 << bit_idx);
        xts->out_bits++;
    }
}

/* ---------------------------------------------------------------------- */

// @@@@ RFHH the specx say that it should be
//      @return: num clocks on success, -1 on error.
//              Might have to be: return i;

/** @return 0 on success; -1 on error */
int
io_scan(const unsigned char *tdi, const unsigned char *tms,
        unsigned char *tdo, unsigned len)
{
    unsigned i;
    int res;
    xpc_ext_transfer_state_t xts;

    /* Initialize state.  */
    xts.xpcu = global_xpcu;
    xts.out = (uint8_t *) tdo;
    xts.in_bits = 0;
    xts.out_bits = 0;
    xts.out_done = 0;

    for (i = 0; i < len; i++) {
        unsigned di = (tdi[i >> 3] >> (i & 7)) & 1;
        unsigned tm = (tms[i >> 3] >> (i & 7)) & 1;
        xpcu_add_bit_for_ext_transfer (&xts, di, tm, 1);
        if (xts.in_bits == (4 * XPC_A6_CHUNKSIZE - 1)) {
            res = xpcu_do_ext_transfer (&xts);
            if (res < 0)
                return -1;
        }
    }

    if (xts.in_bits > 0) {
        /* CPLD doesn't like multiples of 4; add one dummy bit */
        if ((xts.in_bits & 3) == 0)
            xpcu_add_bit_for_ext_transfer (&xts, 0, 0, 0);
        res = xpcu_do_ext_transfer (&xts);
        if (res < 0)
            return -1;
    }

    return 0;
}

void
io_close(void)
{
    if (global_xpcu) {
        libusb_close (global_xpcu);
        libusb_exit(NULL);
        global_xpcu = NULL;
    }
}
