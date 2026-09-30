CC		?= $(CROSS_COMPILE)gcc
CFLAGS		+= -Wall -I../ta/include -I$(TEEC_EXPORT)/include
LDFLAGS		+= -L$(TEEC_EXPORT)/lib
LDADD		+= -lteec

BINARY = meterd

.PHONY: all
all: $(BINARY)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<
$(BINARY): meterd.o
	$(CC) $(LDFLAGS) -o $@ $< $(LDADD)

.PHONY: clean
clean:
	rm -f $(BINARY) *.o
