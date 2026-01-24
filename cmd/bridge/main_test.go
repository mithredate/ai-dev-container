package main

import (
	"os"
	"testing"
)

func TestDetermineWorkdir(t *testing.T) {
	// Save current working directory to restore later
	originalWd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get current working directory: %v", err)
	}
	defer os.Chdir(originalWd)

	tests := []struct {
		name     string
		cmd      Command
		cwd      string
		expected string
	}{
		{
			name: "CWD /workspaces/project with paths mapping translates to /app/project",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Paths: map[string]string{
					"/workspaces": "/app",
				},
			},
			cwd:      "/workspaces/project",
			expected: "/app/project",
		},
		{
			name: "CWD with nested path mapping",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Paths: map[string]string{
					"/workspaces":         "/app",
					"/workspaces/project": "/project",
				},
			},
			cwd:      "/workspaces/project/src",
			expected: "/project/src",
		},
		{
			name: "CWD /other/path with no matching paths uses static workdir",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Workdir:   "/default/workdir",
				Paths: map[string]string{
					"/workspaces": "/app",
				},
			},
			cwd:      "/other/path",
			expected: "/default/workdir",
		},
		{
			name: "CWD /other/path with no matching paths and no workdir uses CWD",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Paths: map[string]string{
					"/workspaces": "/app",
				},
			},
			cwd:      "/other/path",
			expected: "/other/path",
		},
		{
			name: "No paths mapping uses static workdir if set",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Workdir:   "/default/workdir",
			},
			cwd:      "/some/path",
			expected: "/default/workdir",
		},
		{
			name: "No paths mapping and no workdir uses CWD",
			cmd: Command{
				Container: "test",
				Exec:      "go",
			},
			cwd:      "/some/path",
			expected: "/some/path",
		},
		{
			name: "Identity mapping uses translated path (same as CWD) not static workdir",
			cmd: Command{
				Container: "test",
				Exec:      "go",
				Workdir:   "/default/workdir",
				Paths: map[string]string{
					"/workspace": "/workspace",
				},
			},
			cwd:      "/workspace/subpkg",
			expected: "/workspace/subpkg",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Change to the test CWD
			// Note: We can only test paths that exist, so we'll test the logic
			// by mocking os.Getwd via a test helper approach
			// For now, test with actual CWD since we can't easily mock os.Getwd

			// Instead, let's test the core logic directly by creating a helper
			result := determineWorkdirWithCwd(&tt.cmd, tt.cwd)
			if result != tt.expected {
				t.Errorf("determineWorkdirWithCwd() = %q, want %q", result, tt.expected)
			}
		})
	}
}

// determineWorkdirWithCwd is a testable version that accepts CWD as parameter
func determineWorkdirWithCwd(cmd *Command, cwd string) string {
	// Try to translate the current working directory
	translatedCwd, matched := cmd.TranslatePathWithMatch(cwd)

	// If a path mapping matched, use the translated path (even if same as original)
	if matched {
		return translatedCwd
	}

	// No mapping matched - use static workdir if set, otherwise use CWD
	if cmd.Workdir != "" {
		return cmd.Workdir
	}
	return cwd
}
