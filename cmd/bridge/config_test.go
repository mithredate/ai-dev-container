package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadConfig_WithOverrides(t *testing.T) {
	// Create a temporary config file with overrides
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "bridge.yaml")

	configContent := `
version: "1"
commands:
  go:
    container: golang
    exec: go
overrides:
  echo:
    native: /bin/echo
  claude:
    native: /usr/local/bin/claude
`
	if err := os.WriteFile(configPath, []byte(configContent), 0644); err != nil {
		t.Fatalf("failed to write test config: %v", err)
	}

	config, err := LoadConfig(configPath)
	if err != nil {
		t.Fatalf("LoadConfig failed: %v", err)
	}

	// Verify overrides were parsed correctly
	if len(config.Overrides) != 2 {
		t.Errorf("expected 2 overrides, got %d", len(config.Overrides))
	}

	echoOverride, ok := config.Overrides["echo"]
	if !ok {
		t.Error("expected 'echo' override to exist")
	} else if echoOverride.Native != "/bin/echo" {
		t.Errorf("expected echo native to be '/bin/echo', got '%s'", echoOverride.Native)
	}

	claudeOverride, ok := config.Overrides["claude"]
	if !ok {
		t.Error("expected 'claude' override to exist")
	} else if claudeOverride.Native != "/usr/local/bin/claude" {
		t.Errorf("expected claude native to be '/usr/local/bin/claude', got '%s'", claudeOverride.Native)
	}
}

func TestLoadConfig_WithoutOverrides(t *testing.T) {
	// Create a config without overrides section (should still work)
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "bridge.yaml")

	configContent := `
version: "1"
commands:
  go:
    container: golang
    exec: go
`
	if err := os.WriteFile(configPath, []byte(configContent), 0644); err != nil {
		t.Fatalf("failed to write test config: %v", err)
	}

	config, err := LoadConfig(configPath)
	if err != nil {
		t.Fatalf("LoadConfig failed: %v", err)
	}

	// Overrides should be nil or empty when not specified
	if config.Overrides != nil && len(config.Overrides) > 0 {
		t.Errorf("expected no overrides, got %d", len(config.Overrides))
	}
}

func TestLoadConfig_OverrideValidation_EmptyNative(t *testing.T) {
	// Create a config with an override that has empty native path
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "bridge.yaml")

	configContent := `
version: "1"
commands:
  go:
    container: golang
    exec: go
overrides:
  echo:
    native: ""
`
	if err := os.WriteFile(configPath, []byte(configContent), 0644); err != nil {
		t.Fatalf("failed to write test config: %v", err)
	}

	_, err := LoadConfig(configPath)
	if err == nil {
		t.Error("expected validation error for empty native path")
	}
}

func TestLoadConfig_OverrideValidation_MissingNative(t *testing.T) {
	// Create a config with an override that has no native field
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "bridge.yaml")

	configContent := `
version: "1"
commands:
  go:
    container: golang
    exec: go
overrides:
  echo:
`
	if err := os.WriteFile(configPath, []byte(configContent), 0644); err != nil {
		t.Fatalf("failed to write test config: %v", err)
	}

	_, err := LoadConfig(configPath)
	if err == nil {
		t.Error("expected validation error for missing native field")
	}
}

func TestValidate_OverridesField(t *testing.T) {
	tests := []struct {
		name      string
		config    Config
		expectErr bool
		errMsg    string
	}{
		{
			name: "valid config with overrides",
			config: Config{
				Version: "1",
				Commands: map[string]Command{
					"go": {Container: "golang", Exec: "go"},
				},
				Overrides: map[string]Override{
					"echo": {Native: "/bin/echo"},
				},
			},
			expectErr: false,
		},
		{
			name: "valid config without overrides",
			config: Config{
				Version: "1",
				Commands: map[string]Command{
					"go": {Container: "golang", Exec: "go"},
				},
			},
			expectErr: false,
		},
		{
			name: "invalid override - empty native",
			config: Config{
				Version: "1",
				Commands: map[string]Command{
					"go": {Container: "golang", Exec: "go"},
				},
				Overrides: map[string]Override{
					"echo": {Native: ""},
				},
			},
			expectErr: true,
			errMsg:    "override 'echo': missing required field 'native'",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if tt.expectErr {
				if err == nil {
					t.Errorf("expected error, got nil")
				} else if tt.errMsg != "" && err.Error() != tt.errMsg {
					t.Errorf("expected error message '%s', got '%s'", tt.errMsg, err.Error())
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
			}
		})
	}
}

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

func TestResolveCommand(t *testing.T) {
	tests := []struct {
		name           string
		config         Config
		commandName    string
		expectExecPath string
		expectIsNative bool
	}{
		{
			name: "override hit - returns native path",
			config: Config{
				Version: "1",
				Commands: map[string]Command{
					"go": {Container: "golang", Exec: "go"},
				},
				Overrides: map[string]Override{
					"echo":   {Native: "/bin/echo"},
					"claude": {Native: "/usr/local/bin/claude"},
				},
			},
			commandName:    "echo",
			expectExecPath: "/bin/echo",
			expectIsNative: true,
		},
		{
			name: "sidecar routing - command in commands but not overrides",
			config: Config{
				Version: "1",
				Commands: map[string]Command{
					"go": {Container: "golang", Exec: "go"},
				},
				Overrides: map[string]Override{
					"echo": {Native: "/bin/echo"},
				},
			},
			commandName:    "go",
			expectExecPath: "",
			expectIsNative: false,
		},
		{
			name: "unknown command fallthrough - not in commands or overrides",
			config: Config{
				Version: "1",
				Commands: map[string]Command{
					"go": {Container: "golang", Exec: "go"},
				},
				Overrides: map[string]Override{
					"echo": {Native: "/bin/echo"},
				},
			},
			commandName:    "unknown",
			expectExecPath: "",
			expectIsNative: false,
		},
		{
			name: "config with nil overrides",
			config: Config{
				Version: "1",
				Commands: map[string]Command{
					"go": {Container: "golang", Exec: "go"},
				},
				Overrides: nil,
			},
			commandName:    "go",
			expectExecPath: "",
			expectIsNative: false,
		},
		{
			name: "config with empty overrides map",
			config: Config{
				Version: "1",
				Commands: map[string]Command{
					"go": {Container: "golang", Exec: "go"},
				},
				Overrides: map[string]Override{},
			},
			commandName:    "go",
			expectExecPath: "",
			expectIsNative: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			execPath, isNative := tt.config.ResolveCommand(tt.commandName)
			if execPath != tt.expectExecPath {
				t.Errorf("expected execPath '%s', got '%s'", tt.expectExecPath, execPath)
			}
			if isNative != tt.expectIsNative {
				t.Errorf("expected isNative %v, got %v", tt.expectIsNative, isNative)
			}
		})
	}
}
