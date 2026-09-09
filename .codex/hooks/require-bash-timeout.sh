#!/bin/bash
# Reject Bash tool calls without an explicit timeout wrapper.
# The timeout must cover the ENTIRE command — compound commands must be
# wrapped in 'bash -c' so timeout applies globally.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Strip leading whitespace
COMMAND="${COMMAND#"${COMMAND%%[![:space:]]*}"}"

# Must start with 'timeout'
if [[ ! "$COMMAND" =~ ^timeout[[:space:]] ]]; then
  echo "ERROR: All bash commands must be wrapped with 'timeout'. Use: timeout <seconds> <command>" >&2
  echo "For compound commands (using && ; | &), wrap in bash -c:" >&2
  echo "  timeout 30 bash -c 'cmd1 && cmd2'" >&2
  exit 2
fi

# Extract everything after 'timeout <N> [options]' — the actual command portion.
REST=$(echo "$COMMAND" | sed -E 's/^timeout[[:space:]]+(-[^ ]+[[:space:]]+)*[0-9]+[smhd]?[[:space:]]+//')

# If wrapped in bash -c, timeout covers the whole thing — OK
if [[ "$REST" =~ ^bash[[:space:]]+-c[[:space:]] ]]; then
  exit 0
fi

# Check for shell operators that would escape the timeout
if [[ "$REST" =~ (&&|\;|\|\||[^\\|]\|[^\\|]|[^\&]\&[^\&]) ]]; then
  echo "ERROR: timeout only covers the first command. For compound commands, use:" >&2
  echo "  timeout 30 bash -c 'cmd1 && cmd2'" >&2
  echo "Your command: $COMMAND" >&2
  exit 2
fi

exit 0
