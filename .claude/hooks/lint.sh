#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
	exit 0
fi

BASENAME=$(basename "$FILE_PATH")
DIR=$(dirname "$FILE_PATH")

if [[ "$BASENAME" == *.* ]]; then
	EXT="${BASENAME##*.}"
else
	EXT=""
fi

run_check() {
	local output rc=0
	output=$("$@" 2>&1) || rc=$?

	if [[ $rc -ne 0 ]]; then
		jq -cn --arg ctx "$output" \
			'{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
	fi

	exit "$rc"
}

case "$EXT" in
lua)
	run_check selene --display-style=json2 "$FILE_PATH"
	;;
md)
	run_check markdownlint-cli2 "$FILE_PATH"
	;;
sh)
	run_check shellcheck "$FILE_PATH"
	;;
esac

if [[ "$EXT" == "yml" || "$EXT" == "yaml" ]] && [[ "$DIR" == *".github/workflows"* ]]; then
	run_check actionlint "$FILE_PATH"
fi

exit 0
