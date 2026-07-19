# Verify Claude Code Hooks with Synthetic Data

Fetch and study the Claude Code hooks reference at <https://code.claude.com/docs/en/hooks>

See @.claude/settings.json for repository-specific hooks and their locations under @.claude/hooks directory.
Test their functionality with synthetic data to ensure they work as expected.

**IMPORTANT:** All hooks are written with JavaScript and `zx` scripting toolkit.
If you need to consult its documentation, fetch it from <https://google.github.io/zx/api>.

## How to Pass Data

Edit the example synthetic JSON objects below, strip the comments, and pass it to the hooks via standard input.

```bash
echo "<JSON data>" | ./.claude/hooks/<hook_name>.mjs
```

## `PostToolUse` hook

```jsonc
{
  "session_id": "27aad7ef-aacf-4d06-9ba5-be7539dd91a6", // any string
  "transcript_path": "", // can be empty
  "cwd": "", // always use the current working directory
  "permission_mode": "default",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write", // can also be "Edit"
  "tool_input": {
    "file_path": "/path/to/file.txt", // path to any synthetic file
    "content": "file content" // contents of the file above
  },
  "tool_response": {
    "filePath": "/path/to/file.txt",
    "success": true
  },
  "tool_use_id": "08563287-7903-4b7e-a00e-c127a2d74c68", // any string
  "duration_ms": 1
}
```

## `Stop` hook

```jsonc
{
  "session_id": "190100f7-7a57-4fb5-acb2-77a9496a4bbc", // any string
  "transcript_path": "", // can be empty
  "cwd": "", // always use the current working directory
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": false, // can also be true
  "last_assistant_message": "All to-dos completed.",
  "background_tasks": [],
  "session_crons": []
}
```

## Verification

For successful scenarios, hooks should always return exit code 0 without output.
This signals the Claude agent to proceed.

For error scenarios, hooks must always return non-zero exit code (typically 2)
and a terse contextual explanation of what went wrong. It is crucial to validate this explanation
and verify it is of genuine help to Claude agents.

## Potential Fixes

If the verification above fails for any reason, debug the hook scripts more closely and suggest fixes.
After implementing the fixes, run the verification again.
