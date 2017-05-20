/* Get prototype. */
#include <stdio.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <pdf/base64.h>
static const char b64_enc[64] =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static void
base64_encode_blocks (uint8_t *in, size_t block_count, uint8_t *out) {
  for (;block_count > 0; block_count--, in += 3)
    {
      *out++ = b64_enc[in[0] >> 2];
      *out++ = b64_enc[((in[0] << 4) + (in[1] >> 4)) & 0x3f];
      *out++ = b64_enc[((in[1] << 2) + (in[2] >> 6)) & 0x3f];
      *out++ = b64_enc[in[2] & 0x3f];
    }
}

void
pdf_encode_base64 (uint8_t* in, size_t inlen,
		uint8_t* out, size_t outlen)
{
  size_t whole_blocks = inlen / 3;
  if (whole_blocks * 4 > outlen) {
    whole_blocks = outlen / 4;
  }
  base64_encode_blocks (in, whole_blocks, out);
  inlen -= whole_blocks * 3;
  outlen -= whole_blocks * 4;
  in += whole_blocks * 3;
  out += whole_blocks * 4;

  if (inlen && outlen) {
    /* Final partial block */
    uint8_t in_tail[3] = {
      in[0],
      inlen > 1 ? in[1] : 0,
      inlen > 2 ? in[2] : 0
    };
    uint8_t out_tail[4];
    uint8_t i;

    base64_encode_blocks (in_tail, 1, out_tail);
    /* Pad */
    if (inlen < 2) {
      out_tail[2] = '=';
    }
    out_tail[3] = '=';

    for (i = 0; i < 4 && outlen > 0; outlen--) {
      *out++ = out_tail[i++];
    }
  }

}

#define W 254  // Whitespace
#define X 255 // Illegal Character

static uint8_t b64_dec[256] = {
    W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,
    W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,  W,
    W,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  62, X,  62, X,  63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, X,  X,  X,  X,  X,  X,
    X,   0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, X,  X,  X,  X,  63,
    X,  26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, X,  X,  X,  X,  X,
    X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,
    X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,
    X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,
    X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,
    X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,
    X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,
    X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,
    X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X,  X
};

uint8_t next_digit(uint8_t* in,
		   size_t inlen,
		   size_t *i,
		   uint8_t *n,
		   uint8_t *error
		   ) {
  uint8_t digit = 0;
  if (*i < inlen) {
    digit = b64_dec[ in[ (*i)++ ] ];
    if (digit == W) {    // White-space
      digit = next_digit(in, inlen, i, n, error);
    }
    else {
      if (digit == X) {  // Illegal character
	*error = 1;
	digit = next_digit(in, inlen, i, n, error);
      }
      else {
	(*n)++;
      }
    }
  }
  return digit;
}

int32_t pdf_decode_base64(uint8_t* in,
			  size_t inlen,
			  uint8_t* out,
			  size_t outlen) {

    size_t i;
    int32_t j;
    uint8_t error = 0;

    while (inlen > 0 && in[inlen - 1] == '='
	   || b64_dec[ in[inlen - 1] ] == W) {
      inlen--;
    }

    for (i = 0, j = 0; i < inlen && j < outlen && !error;) {

      uint8_t sextet[4] = {0, 0, 0, 0};
      uint32_t triple;
      uint8_t n_digits = 0;
      int8_t k, m;
      for (k = 0; k < 4; k++) {
	sextet[k] = next_digit(in, inlen, &i, &n_digits, &error);
      }

      triple = (sextet[0] << 3 * 6)
        + (sextet[1] << 2 * 6)
        + (sextet[2] << 1 * 6)
        + (sextet[3] << 0 * 6);

      m = n_digits == 4 ? 0 : n_digits == 3 ? 1 : 2;
      for (k = 2; k >= m && j < outlen; k--) {
	out[j++] = (triple >> k * 8) & 0xFF;
      }
    }

    return error ? -1 : j;
}
