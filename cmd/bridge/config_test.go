package main

import (
	"testing"
)

func TestTranslatePathWithMatch(t *testing.T) {
	tests := []struct {
		name          string
		cmd           Command
		path          string
		expectedPath  string
		expectedMatch bool
	}{
		{
			name: "path matches and translates to different path",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Paths: map[string]string{
					"/workspaces": "/app",
				},
			},
			path:          "/workspaces/project",
			expectedPath:  "/app/project",
			expectedMatch: true,
		},
		{
			name: "path matches with identity mapping",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Paths: map[string]string{
					"/workspace": "/workspace",
				},
			},
			path:          "/workspace/subpkg",
			expectedPath:  "/workspace/subpkg",
			expectedMatch: true,
		},
		{
			name: "path does not match any mapping",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Paths: map[string]string{
					"/workspaces": "/app",
				},
			},
			path:          "/other/path",
			expectedPath:  "/other/path",
			expectedMatch: false,
		},
		{
			name: "no paths mapping defined",
			cmd: Command{
				Container: "test",
				Exec:      "go",
			},
			path:          "/some/path",
			expectedPath:  "/some/path",
			expectedMatch: false,
		},
		{
			name: "empty paths mapping",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Paths:     map[string]string{},
			},
			path:          "/some/path",
			expectedPath:  "/some/path",
			expectedMatch: false,
		},
		{
			name: "longest prefix wins (nested mappings)",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Paths: map[string]string{
					"/workspaces":         "/app",
					"/workspaces/project": "/project",
				},
			},
			path:          "/workspaces/project/src",
			expectedPath:  "/project/src",
			expectedMatch: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			path, matched := tt.cmd.TranslatePathWithMatch(tt.path)
			if path != tt.expectedPath {
				t.Errorf("expected path '%s', got '%s'", tt.expectedPath, path)
			}
			if matched != tt.expectedMatch {
				t.Errorf("expected matched %v, got %v", tt.expectedMatch, matched)
			}
		})
	}
}

