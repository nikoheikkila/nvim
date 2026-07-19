#!/usr/bin/env zx

// Hooks inherit the session shell's working directory, which may be a subdirectory
cd(process.env.CLAUDE_PROJECT_DIR ?? path.resolve(__dirname, '../..'))

const input = JSON.parse(await stdin())

// Avoid infinite loops if a continuation was already triggered by this hook
if (input.stop_hook_active) process.exit(0)

const transcriptPath = input.transcript_path
if (!transcriptPath || !fs.existsSync(transcriptPath)) process.exit(0)

for (const suite of ['unit', 'integration']) {
  const result = await $({ nothrow: true, quiet: true })`busted --run=${suite}`

  if (result.exitCode !== 0) {
    echo(JSON.stringify({ decision: 'block', reason: result.stdall }))
    process.exit(2);
  }
}

process.exit(0)
