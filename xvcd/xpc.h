#define VENDOR_ID 0x03FD
#define PRODUCT_ID 0x0008

int io_init(unsigned vendor, unsigned product, const char *desc);

int io_scan(const unsigned char *tdi, const unsigned char *tms,
            unsigned char *tdo, unsigned len);
void io_close(void);

extern int verbose;
extern int trace_usb;
extern int trace_protocol;
