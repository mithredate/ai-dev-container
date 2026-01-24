package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"syscall"

	"golang.org/x/term"
)

const version = "0.1.0"

func main() {
	var (
		showHelp    bool
		showVersion bool
		configPath  string
	)

	flag.BoolVar(&showHelp, "help", false, "Show this help message")
	flag.BoolVar(&showHelp, "h", false, "Show this help message (shorthand)")
	flag.BoolVar(&showVersion, "version", false, "Show version")
	flag.BoolVar(&showVersion, "v", false, "Show version (shorthand)")
	flag.StringVar(&configPath, "config", "", "Path to bridge config file")
	flag.StringVar(&configPath, "c", "", "Path to bridge config file (shorthand)")

	flag.Usage = printUsage
	flag.Parse()

	if showHelp {
		printUsage()
		os.Exit(0)
	}

	if showVersion {
		fmt.Printf("bridge version %s\n", version)
		os.Exit(0)
	}

	// Load config
	config, err := LoadConfig(configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %s\n", err)
		os.Exit(1)
	}

	args := flag.Args()
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Error: no command specified")
		fmt.Fprintln(os.Stderr, "Run 'bridge --help' for usage")
		os.Exit(1)
	}

	// Route and execute the command
	exitCode := runCommand(config, args)
	os.Exit(exitCode)
}

// runCommand routes and executes the given command based on config.
// Returns the exit code from the executed command.
func runCommand(config *Config, args []string) int {
	cmdName := args[0]
	cmdArgs := args[1:]

	// Check for native override first
	if execPath, isNative := config.ResolveCommand(cmdName); isNative {
		return execNative(execPath, args)
	}

	// Look up command in config
	cmd, found := config.Commands[cmdName]

	if !found {
		// Command not in config and no override - fall through to native lookup
		nativePath, err := exec.LookPath(cmdName)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: command '%s' not found in config and not available natively\n", cmdName)
			return 127 // Standard "command not found" exit code
		}
		return execNative(nativePath, args)
	}

	// Resolve container name (apply containers mapping)
	containerName := config.ResolveContainer(cmd.Container)

	// Determine the actual executable (use exec if set, otherwise cmdName)
	executable := cmd.Exec

	// Translate path arguments
	translatedArgs := cmd.TranslateArgs(cmdArgs)

	// Build docker exec command
	// Use -i for interactive mode (keeps stdin open)
	// Use -t for TTY allocation when both stdin and stdout are terminals (for colored output)
	dockerArgs := []string{"exec", "-i"}
	if term.IsTerminal(int(os.Stdin.Fd())) && term.IsTerminal(int(os.Stdout.Fd())) {
		dockerArgs = append(dockerArgs, "-t")
	}

	// Determine working directory for docker exec
	// Priority: 1) Translated CWD, 2) Static workdir from config, 3) Current CWD
	workdir := determineWorkdir(&cmd)
	dockerArgs = append(dockerArgs, "-w", workdir)

	// Add container name
	dockerArgs = append(dockerArgs, containerName)

	// Add the command and its arguments
	dockerArgs = append(dockerArgs, executable)
	dockerArgs = append(dockerArgs, translatedArgs...)

	// Execute docker command
	dockerCmd := exec.Command("docker", dockerArgs...)
	dockerCmd.Stdin = os.Stdin
	dockerCmd.Stdout = os.Stdout
	dockerCmd.Stderr = os.Stderr

	err := dockerCmd.Run()
	if err != nil {
		// Check for exit error to get exit code
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode()
		}
		// Other error (docker not found, etc.)
		fmt.Fprintf(os.Stderr, "Error: failed to execute docker: %s\n", err)
		return 1
	}

	return 0
}

// determineWorkdir determines the working directory to use for docker exec.
// Priority: 1) Translated CWD (if a path mapping matches)
//           2) Static workdir from config (if set and no mapping matched)
//           3) Current CWD (as fallback)
func determineWorkdir(cmd *Command) string {
	cwd, err := os.Getwd()
	if err != nil {
		// If we can't get CWD, fall back to config workdir or root
		if cmd.Workdir != "" {
			return cmd.Workdir
		}
		return "/"
	}

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

// execNative executes a native binary using syscall.Exec, replacing the current process.
// If syscall.Exec fails, it returns an error exit code.
// The args parameter should include the command name as the first element (argv[0]).
func execNative(execPath string, args []string) int {
	// syscall.Exec replaces the current process, so this function only returns on error
	err := syscall.Exec(execPath, args, os.Environ())
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: failed to exec '%s': %s\n", execPath, err)
		return 1
	}
	// This line is never reached because syscall.Exec replaces the process
	return 0
}

func printUsage() {
	fmt.Fprintf(os.Stderr, `bridge - Execute commands in sidecar containers

Usage:
  bridge [flags] <command> [args...]

Flags:
  -c, --config string   Path to bridge config file (default: $SIDECAR_CONFIG_DIR/bridge.yaml)
  -h, --help            Show this help message
  -v, --version         Show version

Examples:
  bridge npm install           Run npm install in the default container
  bridge php artisan migrate   Run php artisan migrate in the PHP container
  bridge --config ./my.yaml npm test

The bridge reads configuration from $SIDECAR_CONFIG_DIR/bridge.yaml (or BRIDGE_CONFIG env var).
SIDECAR_CONFIG_DIR defaults to $PWD/.sidecar if not set.
`)
}
