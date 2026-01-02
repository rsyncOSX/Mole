package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDeleteMultiplePathsCmdHandlesParentChild(t *testing.T) {
	base := t.TempDir()
	parent := filepath.Join(base, "parent")
	child := filepath.Join(parent, "child")

	// Structure: parent/fileA, parent/child/fileC.
	if err := os.MkdirAll(child, 0o755); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(parent, "fileA"), []byte("a"), 0o644); err != nil {
		t.Fatalf("write fileA: %v", err)
	}
	if err := os.WriteFile(filepath.Join(child, "fileC"), []byte("c"), 0o644); err != nil {
		t.Fatalf("write fileC: %v", err)
	}

	var counter int64
	msg := deleteMultiplePathsCmd([]string{parent, child}, &counter)()
	progress, ok := msg.(deleteProgressMsg)
	if !ok {
		t.Fatalf("expected deleteProgressMsg, got %T", msg)
	}
	if progress.err != nil {
		t.Fatalf("unexpected error: %v", progress.err)
	}
	if progress.count != 2 {
		t.Fatalf("expected 2 files deleted, got %d", progress.count)
	}
	if _, err := os.Stat(parent); !os.IsNotExist(err) {
		t.Fatalf("expected parent to be removed, err=%v", err)
	}
	if _, err := os.Stat(child); !os.IsNotExist(err) {
		t.Fatalf("expected child to be removed, err=%v", err)
	}
}
