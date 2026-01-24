package main

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

const (
	exampleConfigPath = "examples/claude-bridge.yaml"
)

// getDefaultConfigPath returns the default config path based on SIDECAR_CONFIG_DIR
// or falls back to PWD/.sidecar/bridge.yaml
func getDefaultConfigPath() string {
	configDir := os.Getenv("SIDECAR_CONFIG_DIR")
	if configDir == "" {
		// Fall back to current working directory
		pwd, err := os.Getwd()
		if err != nil {
			pwd = "."
		}
		configDir = pwd + "/.sidecar"
	}
	return configDir + "/bridge.yaml"
}

// Config represents the bridge configuration file.
type Config struct {
	Version          string              `yaml:"version"`
	DefaultContainer string              `yaml:"default_container"`
	Containers       map[string]string   `yaml:"containers"`
	Commands         map[string]Command  `yaml:"commands"`
	Overrides        map[string]Override `yaml:"overrides"`
}

// Override represents a native command override configuration.
// When a command has an override, it executes natively instead of via docker exec.
type Override struct {
	Native string `yaml:"native"`
}

// Command represents a command mapping configuration.
type Command struct {
	Container string            `yaml:"container"`
	Exec      string            `yaml:"exec"`
	Workdir   string            `yaml:"workdir"`
	Paths     map[string]string `yaml:"paths"`
}

// LoadConfig reads and parses the bridge configuration file.
// It uses BRIDGE_CONFIG env var if set, otherwise uses the default path.
func LoadConfig(configPath string) (*Config, error) {
	// Determine config path
	path := configPath
	if path == "" {
		path = os.Getenv("BRIDGE_CONFIG")
	}
	if path == "" {
		path = getDefaultConfigPath()
	}

	// Read config file
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, fmt.Errorf("config file not found: %s\nSee %s for an example configuration", path, exampleConfigPath)
		}
		return nil, fmt.Errorf("failed to read config file %s: %w", path, err)
	}

	// Parse YAML
	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		var yamlErr *yaml.TypeError
		if errors.As(err, &yamlErr) {
			return nil, fmt.Errorf("invalid YAML in %s: %s", path, yamlErr.Errors[0])
		}
		return nil, fmt.Errorf("invalid YAML in %s: %w", path, err)
	}

	// Validate config
	if err := config.Validate(); err != nil {
		return nil, fmt.Errorf("invalid config in %s: %w", path, err)
	}

	return &config, nil
}

// Validate checks that the config has all required fields.
func (c *Config) Validate() error {
	if c.Version == "" {
		return fmt.Errorf("missing required field 'version'")
	}
	if c.Version != "1" {
		return fmt.Errorf("unsupported config version '%s', expected '1'", c.Version)
	}
	if len(c.Commands) == 0 {
		return fmt.Errorf("missing required field 'commands' (must have at least one command)")
	}

	// Validate each command
	for name, cmd := range c.Commands {
		if cmd.Container == "" {
			return fmt.Errorf("command '%s': missing required field 'container'", name)
		}
		if cmd.Exec == "" {
			return fmt.Errorf("command '%s': missing required field 'exec'", name)
		}
	}

	// Validate overrides
	for name, override := range c.Overrides {
		if override.Native == "" {
			return fmt.Errorf("override '%s': missing required field 'native'", name)
		}
	}

	return nil
}

// ResolveContainer resolves a logical container name to the actual container name.
// If the name is in the containers map, returns the mapped value.
// Otherwise, returns the original name unchanged.
func (c *Config) ResolveContainer(name string) string {
	if c.Containers != nil {
		if resolved, ok := c.Containers[name]; ok {
			return resolved
		}
	}
	return name
}

// TranslatePath translates a single path using the command's path mappings.
// If the path starts with a mapped prefix, it is replaced with the target path.
// If no mapping matches, the original path is returned unchanged.
// Longer prefixes are matched first to handle nested mappings correctly.
func (cmd *Command) TranslatePath(path string) string {
	translated, _ := cmd.TranslatePathWithMatch(path)
	return translated
}

// TranslatePathWithMatch translates a path and indicates if a mapping matched.
// Returns (translatedPath, true) if a path mapping matched (even if result is same).
// Returns (originalPath, false) if no path mapping matched.
func (cmd *Command) TranslatePathWithMatch(path string) (string, bool) {
	if len(cmd.Paths) == 0 {
		return path, false
	}

	// Find the longest matching prefix for correct nested path handling
	var longestPrefix string
	var longestTarget string
	for source, target := range cmd.Paths {
		if strings.HasPrefix(path, source) {
			if len(source) > len(longestPrefix) {
				longestPrefix = source
				longestTarget = target
			}
		}
	}

	if longestPrefix != "" {
		return longestTarget + path[len(longestPrefix):], true
	}
	return path, false
}

// TranslateArgs translates all path arguments using the command's path mappings.
// Each argument is checked for mapped prefixes and translated if found.
// Returns a new slice with translated arguments (original slice is not modified).
func (cmd *Command) TranslateArgs(args []string) []string {
	if len(cmd.Paths) == 0 {
		return args
	}

	result := make([]string, len(args))
	for i, arg := range args {
		result[i] = cmd.TranslatePath(arg)
	}
	return result
}

// ResolveCommand checks if a command should be executed natively or routed to a sidecar.
// It checks overrides first, then commands.
// Returns (nativePath, true) if command has a native override.
// Returns ("", false) if command should route to sidecar (in commands) or fall through (unknown).
func (c *Config) ResolveCommand(name string) (execPath string, isNative bool) {
	// Check overrides first - native execution takes priority
	if c.Overrides != nil {
		if override, ok := c.Overrides[name]; ok {
			return override.Native, true
		}
	}

	// Command not in overrides - return false to indicate sidecar routing or fallthrough
	return "", false
}
