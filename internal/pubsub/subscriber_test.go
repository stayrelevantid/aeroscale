package pubsub

import (
	"encoding/json"
	"testing"
)

func TestMessageUnmarshal(t *testing.T) {
	data := `{"id": "msg-001", "payload": {"action": "process", "value": 42}}`

	var m Message
	if err := json.Unmarshal([]byte(data), &m); err != nil {
		t.Fatalf("failed to unmarshal: %v", err)
	}

	if m.ID != "msg-001" {
		t.Errorf("expected id msg-001, got %s", m.ID)
	}

	if m.Payload["action"] != "process" {
		t.Errorf("expected action process, got %v", m.Payload["action"])
	}
}

func TestMessageUnmarshalInvalid(t *testing.T) {
	data := `invalid json`

	var m Message
	if err := json.Unmarshal([]byte(data), &m); err == nil {
		t.Error("expected error for invalid JSON, got nil")
	}
}
