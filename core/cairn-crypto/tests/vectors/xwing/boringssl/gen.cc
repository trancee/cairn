// Reads "seed eseed" hex lines; writes "pk ct ss dk_m sk_x" hex lines using
// BoringSSL's X-Wing API. The expanded ML-KEM key uses BoringSSL's own
// SHAKE256 and NIST-format marshalling, matching its xwing.cc expansion.
#include <openssl/bytestring.h>
#include <openssl/mlkem.h>
#include <openssl/xwing.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "crypto/fipsmodule/bcm_interface.h"
#include "crypto/fipsmodule/keccak/internal.h"

using namespace bssl;

static void fail(const char *what) {
  std::fprintf(stderr, "boringssl generator: %s\n", what);
  std::exit(1);
}

static void parse_hex(const char *hex, uint8_t *out, size_t len) {
  if (std::strlen(hex) != 2 * len) fail("bad hex length");
  for (size_t i = 0; i < len; i++) {
    unsigned value;
    if (std::sscanf(hex + 2 * i, "%2x", &value) != 1) fail("bad hex");
    out[i] = static_cast<uint8_t>(value);
  }
}

static void print_hex(const uint8_t *in, size_t len, const char *end) {
  for (size_t i = 0; i < len; i++) std::printf("%02x", in[i]);
  std::printf("%s", end);
}

int main() {
  char seed_hex[2 * XWING_PRIVATE_KEY_BYTES + 1];
  char eseed_hex[129];
  while (std::scanf("%64s %128s", seed_hex, eseed_hex) == 2) {
    uint8_t seed[XWING_PRIVATE_KEY_BYTES], eseed[64];
    parse_hex(seed_hex, seed, sizeof(seed));
    parse_hex(eseed_hex, eseed, sizeof(eseed));

    XWING_private_key private_key;
    CBS cbs;
    CBS_init(&cbs, seed, sizeof(seed));
    if (!XWING_parse_private_key(&private_key, &cbs) || CBS_len(&cbs) != 0)
      fail("parse private key");
    uint8_t pk[XWING_PUBLIC_KEY_BYTES];
    if (!XWING_public_from_private(pk, &private_key)) fail("public key");
    uint8_t ct[XWING_CIPHERTEXT_BYTES], ss[XWING_SHARED_SECRET_BYTES];
    if (!XWING_encap_external_entropy(ct, ss, pk, eseed)) fail("encap");
    uint8_t decapsulated[XWING_SHARED_SECRET_BYTES];
    if (!XWING_decap(decapsulated, ct, &private_key) ||
        std::memcmp(decapsulated, ss, sizeof(ss)) != 0)
      fail("decap");

    uint8_t expanded[96];
    BORINGSSL_keccak(expanded, sizeof(expanded), seed, sizeof(seed),
                     boringssl_shake256);
    MLKEM768_private_key mlkem;
    if (!MLKEM768_private_key_from_seed(&mlkem, expanded, 64))
      fail("ML-KEM seed");
    uint8_t dk_m[BCM_MLKEM768_PRIVATE_KEY_BYTES];
    CBB cbb;
    if (!CBB_init_fixed(&cbb, dk_m, sizeof(dk_m)) ||
        !bcm_success(BCM_mlkem768_marshal_private_key(&cbb, &mlkem)) ||
        CBB_len(&cbb) != sizeof(dk_m))
      fail("marshal ML-KEM private key");

    print_hex(pk, sizeof(pk), " ");
    print_hex(ct, sizeof(ct), " ");
    print_hex(ss, sizeof(ss), " ");
    print_hex(dk_m, sizeof(dk_m), " ");
    print_hex(expanded + 64, 32, "\n");
  }
  return 0;
}
