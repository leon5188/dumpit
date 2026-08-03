package services

import "testing"

func TestVerifyFirebaseIDToken_MalformedToken(t *testing.T) {
	_, _, err := VerifyFirebaseIDToken("not-a-jwt", "some-project-id")
	if err == nil {
		t.Fatal("expected error for malformed token, got nil")
	}
}
