/*
 * Meter TA - companion code for "Edge Security by Design, Part 2"
 *
 * Holds an ECDSA P-256 signing key and a monotonic counter inside OP-TEE.
 * The only thing the Linux side can ever get out of this TA is a
 * (counter, signature) pair - never the private key, and never a counter
 * it did not itself produce by signing.
 */

#include <string.h>
#include <tee_internal_api.h>
#include <tee_internal_api_extensions.h>

#include "meter_ta.h"

/* Production: TEE_STORAGE_PRIVATE_RPMB, if this board's eMMC has an RPMB
 * partition - see the blog post's "locking the doors" section. This demo
 * project boots from SD, so REE FS (Linux-held, TEE-encrypted files) is
 * what's actually available. */
#define STORAGE		TEE_STORAGE_PRIVATE_REE
#define KEY_ID		"meter.key"
#define CTR_ID		"meter.ctr"

/* The 13 bytes that get hashed and signed - identical layout to Part 1's
 * meter_tbs on the nRF5340, so the same supplier-side verifier works
 * against either platform's frame. */
struct __attribute__((packed)) meter_tbs {
	uint8_t  version;	/* 1 */
	uint32_t counter;
	uint64_t reading_wh;
};

static TEE_Result get_key(TEE_ObjectHandle *key)
{
	TEE_ObjectHandle tmp = TEE_HANDLE_NULL;
	TEE_Attribute curve;
	TEE_Result res;

	res = TEE_OpenPersistentObject(STORAGE, KEY_ID, strlen(KEY_ID),
					TEE_DATA_FLAG_ACCESS_READ, key);
	if (res != TEE_ERROR_ITEM_NOT_FOUND)
		return res;		/* opened, or a real error */

	/* First use: create the key inside the TEE, for signing only. */
	res = TEE_AllocateTransientObject(TEE_TYPE_ECDSA_KEYPAIR, 256, &tmp);
	if (res != TEE_SUCCESS)
		return res;

	TEE_InitValueAttribute(&curve, TEE_ATTR_ECC_CURVE,
				TEE_ECC_CURVE_NIST_P256, 0);
	res = TEE_GenerateKey(tmp, 256, &curve, 1);
	if (res == TEE_SUCCESS)	/* drops the "extractable" right for good */
		res = TEE_RestrictObjectUsage1(tmp, TEE_USAGE_SIGN);
	if (res == TEE_SUCCESS)
		res = TEE_CreatePersistentObject(STORAGE, KEY_ID,
						  strlen(KEY_ID),
						  TEE_DATA_FLAG_ACCESS_READ,
						  tmp, NULL, 0, key);
	TEE_FreeTransientObject(tmp);
	return res;
}

static TEE_Result next_counter(uint32_t *out)
{
	const uint32_t flags = TEE_DATA_FLAG_ACCESS_READ |
				TEE_DATA_FLAG_ACCESS_WRITE;
	TEE_ObjectHandle obj = TEE_HANDLE_NULL;
	uint32_t c = 0;
	size_t n = 0;
	TEE_Result res;

	res = TEE_OpenPersistentObject(STORAGE, CTR_ID, strlen(CTR_ID),
					flags, &obj);
	if (res == TEE_ERROR_ITEM_NOT_FOUND)	/* first use: start at 0 */
		res = TEE_CreatePersistentObject(STORAGE, CTR_ID,
						  strlen(CTR_ID), flags,
						  TEE_HANDLE_NULL, &c,
						  sizeof(c), &obj);
	if (res != TEE_SUCCESS)
		return res;

	res = TEE_ReadObjectData(obj, &c, sizeof(c), &n);
	if (res == TEE_SUCCESS && (n != sizeof(c) || c == UINT32_MAX))
		res = TEE_ERROR_CORRUPT_OBJECT;	/* never wrap around */
	if (res == TEE_SUCCESS) {
		c++;
		res = TEE_SeekObjectData(obj, 0, TEE_DATA_SEEK_SET);
	}
	if (res == TEE_SUCCESS)
		res = TEE_WriteObjectData(obj, &c, sizeof(c));
	TEE_CloseObject(obj);
	if (res == TEE_SUCCESS)
		*out = c;
	return res;
}

static TEE_Result cmd_sign(uint32_t pt, TEE_Param p[4])
{
	const uint32_t want = TEE_PARAM_TYPES(TEE_PARAM_TYPE_VALUE_INPUT,
					       TEE_PARAM_TYPE_VALUE_OUTPUT,
					       TEE_PARAM_TYPE_MEMREF_OUTPUT,
					       TEE_PARAM_TYPE_NONE);
	struct meter_tbs tbs = { .version = 1 };
	TEE_ObjectHandle key = TEE_HANDLE_NULL;
	TEE_OperationHandle dig = TEE_HANDLE_NULL, op = TEE_HANDLE_NULL;
	uint8_t hash[32];
	size_t hlen = sizeof(hash), slen;
	uint32_t counter;
	TEE_Result res;

	if (pt != want || p[2].memref.size < TA_METER_SIG_LEN)
		return TEE_ERROR_BAD_PARAMETERS;
	slen = p[2].memref.size;

	res = next_counter(&counter);		/* save the counter first ... */
	if (res != TEE_SUCCESS)
		return res;

	tbs.counter = counter;			/* ... then sign it with the reading */
	tbs.reading_wh = ((uint64_t)p[0].value.b << 32) | p[0].value.a;

	res = get_key(&key);
	if (res == TEE_SUCCESS)
		res = TEE_AllocateOperation(&dig, TEE_ALG_SHA256,
					     TEE_MODE_DIGEST, 0);
	if (res == TEE_SUCCESS)
		res = TEE_DigestDoFinal(dig, &tbs, sizeof(tbs), hash, &hlen);
	if (res == TEE_SUCCESS)
		res = TEE_AllocateOperation(&op, TEE_ALG_ECDSA_P256,
					     TEE_MODE_SIGN, 256);
	if (res == TEE_SUCCESS)
		res = TEE_SetOperationKey(op, key);
	if (res == TEE_SUCCESS)	/* raw r || s, like PSA in Part 1 */
		res = TEE_AsymmetricSignDigest(op, NULL, 0, hash, hlen,
						p[2].memref.buffer, &slen);

	TEE_FreeOperation(op);
	TEE_FreeOperation(dig);
	TEE_CloseObject(key);
	if (res != TEE_SUCCESS)
		return res;

	p[2].memref.size = slen;
	p[1].value.a = counter;
	return TEE_SUCCESS;
}

TEE_Result TA_CreateEntryPoint(void)
{
	return TEE_SUCCESS;
}

void TA_DestroyEntryPoint(void)
{
}

TEE_Result TA_OpenSessionEntryPoint(uint32_t pt, TEE_Param p[4],
				     void **sess)
{
	(void)pt; (void)p; (void)sess;
	return TEE_SUCCESS;
}

void TA_CloseSessionEntryPoint(void *sess)
{
	(void)sess;
}

TEE_Result TA_InvokeCommandEntryPoint(void *sess, uint32_t cmd,
				       uint32_t pt, TEE_Param p[4])
{
	(void)sess;
	if (cmd != TA_METER_CMD_SIGN_READING)
		return TEE_ERROR_NOT_SUPPORTED;
	return cmd_sign(pt, p);
}
