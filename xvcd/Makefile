OBJS=xvcd.o xpc.o

CFLAGS=-g -Wall

all: xvcd

xvcd: $(OBJS)
	$(CC) -o $@ $(OBJS) -lusb-1.0

clean:
	$(RM) -f $(OBJS) xvcd
