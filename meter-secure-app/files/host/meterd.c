/*
 * meterd - companion code for "Edge Security by Design, Part 2"
 *
 * Ordinary Linux userspace. It never touches a key: it hands a reading to
 * the Meter TA and gets back a counter and a signature.
 *
 * This board (AXU3EG dev kit) has no metrology front end wired into the
 * PL, so metrology_read_wh() below is a stand-in - replace it with a real
 * read of your energy-metering IP. Everything either side of that call is
 * unchanged by what the reading actually measures.
 *
 * Usage: meterd [reading_wh] [out-file]
 *   reading_wh  demo reading in Wh (default: a counter that increments
 *               each run, via a small file in /tmp)
 *   out-file    where to write the signed frame (default: stdout, as hex)
 */

#include <err.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <tee_client_api.h>

#include "meter_ta.h"

/* Same 77-byte layout as Part 1's frame on the nRF5340: 13 signed bytes
 * (version, counter, reading, all little-endian) + a 64-byte signature. */
struct __attribute__((packed)) frame {
	uint8_t  version;
	uint32_t counter;
	uint64_t reading_wh;
	uint8_t  sig[TA_METER_SIG_LEN];
};

static uint64_t demo_reading_wh(void)
{
	FILE *f = fopen("/tmp/meterd_demo_wh", "r+");
	uint64_t wh = 0;

	if (f) {
		if (fscanf(f, "%" SCNu64, &wh) != 1)
			wh = 0;
	} else {
		f = fopen("/tmp/meterd_demo_wh", "w");
	}
	wh += 500;	/* pretend half a kWh was used since the last run */
	if (f) {
		rewind(f);
		fprintf(f, "%" PRIu64 "\n", wh);
		fclose(f);
	}
	return wh;
}

int main(int argc, char **argv)
{
	TEEC_Context ctx;
	TEEC_Session sess;
	TEEC_UUID uuid = TA_METER_UUID;
	TEEC_Operation op = { 0 };
	uint32_t origin;
	struct frame f = { .version = 1 };
	uint64_t wh;
	TEEC_Result res;

	wh = (argc > 1) ? strtoull(argv[1], NULL, 0) : demo_reading_wh();

	res = TEEC_InitializeContext(NULL, &ctx);
	if (res != TEEC_SUCCESS)
		errx(1, "TEEC_InitializeContext failed: 0x%x", res);

	res = TEEC_OpenSession(&ctx, &sess, &uuid, TEEC_LOGIN_PUBLIC,
				NULL, NULL, &origin);
	if (res != TEEC_SUCCESS)
		errx(1, "cannot open meter TA (origin 0x%x, res 0x%x)",
		     origin, res);

	op.paramTypes = TEEC_PARAM_TYPES(TEEC_VALUE_INPUT, TEEC_VALUE_OUTPUT,
					  TEEC_MEMREF_TEMP_OUTPUT, TEEC_NONE);
	op.params[0].value.a = (uint32_t)wh;
	op.params[0].value.b = (uint32_t)(wh >> 32);
	op.params[2].tmpref.buffer = f.sig;
	op.params[2].tmpref.size = sizeof(f.sig);

	res = TEEC_InvokeCommand(&sess, TA_METER_CMD_SIGN_READING, &op,
				  &origin);
	if (res != TEEC_SUCCESS)
		errx(1, "sign command failed (origin 0x%x, res 0x%x)",
		     origin, res);

	f.counter = op.params[1].value.a;
	f.reading_wh = wh;

	if (argc > 2) {
		FILE *out = fopen(argv[2], "wb");

		if (!out)
			err(1, "fopen %s", argv[2]);
		fwrite(&f, sizeof(f), 1, out);
		fclose(out);
	} else {
		unsigned char *raw = (unsigned char *)&f;

		for (size_t i = 0; i < sizeof(f); i++)
			printf("%02x", raw[i]);
		printf("\n");
	}

	fprintf(stderr, "reading %llu Wh, counter %u signed\n",
		(unsigned long long)wh, f.counter);

	TEEC_CloseSession(&sess);
	TEEC_FinalizeContext(&ctx);
	return 0;
}
