#ifndef TA_METER_H
#define TA_METER_H

/* Generate your own with uuidgen before shipping this for real. */
#define TA_METER_UUID \
	{ 0x8a3c1f52, 0x6d0e, 0x4b7a, \
	  { 0x9e, 0x21, 0x4f, 0x3d, 0x77, 0xa0, 0x5c, 0x19 } }

/*
 * SIGN_READING - params[0].value.{a,b} = reading_wh (low/high 32 bits)
 *                params[1].value.a     = counter (out)
 *                params[2].memref      = 64-byte raw ECDSA signature (out)
 */
#define TA_METER_CMD_SIGN_READING	0

#define TA_METER_SIG_LEN		64

#endif /* TA_METER_H */
