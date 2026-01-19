package main

import (
	"flag"
	"fmt"
	"os"

	_ "gopkg.in/yaml.v3"
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

	args := flag.Args()
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Error: no command specified")
		fmt.Fprintln(os.Stderr, "Run 'bridge --help' for usage")
		os.Exit(1)
	}

	// TODO: implement config parsing and command routing
	fmt.Fprintf(os.Stderr, "bridge: command routing not yet implemented\n")
	os.Exit(1)
}

func printUsage() {
	fmt.Fprintf(os.Stderr, `bridge - Execute commands in sidecar containers

Usage:
  bridge [flags] <command> [args...]

Flags:
  -c, --config string   Path to bridge config file (default: /workspace/.claude/bridge.yaml)
  -h, --help            Show this help message
  -v, --version         Show version

Examples:
  bridge npm install           Run npm install in the default container
  bridge php artisan migrate   Run php artisan migrate in the PHP container
  bridge --config ./my.yaml npm test

The bridge reads configuration from /workspace/.claude/bridge.yaml (or BRIDGE_CONFIG
environment variable) to determine which container to use for each command.
`)
}
