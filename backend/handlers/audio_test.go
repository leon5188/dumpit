package handlers

import (
	"encoding/json"
	"testing"
)

func TestFormatToneSample_Empty(t *testing.T) {
	result := formatToneSample(nil)
	if result != "" {
		t.Fatalf("expected empty string for no history, got %q", result)
	}
}

func TestFormatToneSample_SkipsMalformedEntries(t *testing.T) {
	valid, _ := json.Marshal(map[string]string{"summary": "今天搞定了 PPT"})
	malformed := json.RawMessage(`{not valid json`)

	result := formatToneSample([]json.RawMessage{valid, malformed})
	if result != "今天搞定了 PPT" {
		t.Fatalf("expected only the valid summary, got %q", result)
	}
}

func TestFormatToneSample_JoinsMultiple(t *testing.T) {
	first, _ := json.Marshal(map[string]string{"summary": "第一条"})
	second, _ := json.Marshal(map[string]string{"summary": "第二条"})

	result := formatToneSample([]json.RawMessage{first, second})
	expected := "第一条\n---\n第二条"
	if result != expected {
		t.Fatalf("expected %q, got %q", expected, result)
	}
}
