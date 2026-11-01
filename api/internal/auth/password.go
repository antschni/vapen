package auth

import (
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"strings"

	"golang.org/x/crypto/argon2"
)

const (
	argonTime    = 3
	argonMemory  = 64 * 1024
	argonThreads = 2
	argonKeyLen  = 32
	// maxConcurrentHashes caps argon2 memory use at maxConcurrentHashes * 64 MiB.
	maxConcurrentHashes = 4
)

var hashSlots = make(chan struct{}, maxConcurrentHashes)

var dummyHash = HashPassword("vapen-timing-dummy-password-not-used")

func idKey(password, salt []byte, keyLen uint32) []byte {
	hashSlots <- struct{}{}
	defer func() { <-hashSlots }()
	return argon2.IDKey(password, salt, argonTime, argonMemory, argonThreads, keyLen)
}

func HashPassword(password string) string {
	salt := make([]byte, 16)
	if _, err := readRand(salt); err != nil {
		panic(err)
	}
	key := idKey([]byte(password), salt, argonKeyLen)
	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Key := base64.RawStdEncoding.EncodeToString(key)
	return fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s", argon2.Version, argonMemory, argonTime, argonThreads, b64Salt, b64Key)
}

func VerifyPassword(hash, password string) bool {
	parts := strings.Split(hash, "$")
	if len(parts) != 6 || parts[1] != "argon2id" {
		return false
	}
	salt, err := base64.RawStdEncoding.DecodeString(parts[4])
	if err != nil {
		return false
	}
	expected, err := base64.RawStdEncoding.DecodeString(parts[5])
	if err != nil || len(expected) == 0 || len(expected) > 64 {
		return false
	}
	key := idKey([]byte(password), salt, uint32(len(expected))) // #nosec G115 -- bounded to 64 above
	return subtle.ConstantTimeCompare(key, expected) == 1
}

func TimingSafeDummyVerify() {
	VerifyPassword(dummyHash, "x")
}
