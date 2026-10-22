// Reads "seed eseed" hex lines; writes "pk ct ss dk_m sk_x" hex lines using
// CIRCL's X-Wing package. The expanded ML-KEM key uses Go's SHAKE256 and
// CIRCL's NIST-format ML-KEM-768 private key packing.
package main

import (
	"bufio"
	"bytes"
	"crypto/sha3"
	"encoding/hex"
	"fmt"
	"os"
	"strings"

	"github.com/cloudflare/circl/kem/mlkem/mlkem768"
	"github.com/cloudflare/circl/kem/xwing"
)

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "circl generator:", err)
		os.Exit(1)
	}
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) != 2 {
			must(fmt.Errorf("expected seed and eseed"))
		}
		seed, err := hex.DecodeString(fields[0])
		must(err)
		eseed, err := hex.DecodeString(fields[1])
		must(err)
		if len(seed) != xwing.SeedSize || len(eseed) != xwing.EncapsulationSeedSize {
			must(fmt.Errorf("bad input length"))
		}

		sk, pk := xwing.DeriveKeyPairPacked(seed)
		ss, ct, err := xwing.Encapsulate(pk, eseed)
		must(err)
		if !bytes.Equal(xwing.Decapsulate(ct, sk), ss) {
			must(fmt.Errorf("decapsulation mismatch"))
		}

		expanded := sha3.SumSHAKE256(seed, 96)
		_, mlkem := mlkem768.NewKeyFromSeed(expanded[:64])
		dkM := make([]byte, mlkem768.PrivateKeySize)
		mlkem.Pack(dkM)

		fmt.Println(hex.EncodeToString(pk), hex.EncodeToString(ct), hex.EncodeToString(ss),
			hex.EncodeToString(dkM), hex.EncodeToString(expanded[64:]))
	}
	must(scanner.Err())
}
