#!/usr/bin/env zx

// Hooks inherit the session shell's working directory, which may be a subdirectory
cd(process.env.CLAUDE_PROJECT_DIR ?? path.resolve(__dirname, '../..'))

const input = JSON.parse(await stdin())

// Avoid infinite loops if a continuation was already triggered by this hook
if (input.stop_hook_active) process.exit(0)

const transcriptPath = input.transcript_path
if (!transcriptPath || !fs.existsSync(transcriptPath)) process.exit(0)

// Collect unique file paths from Edit/Write tool calls in the session transcript (JSONL)
const files = new Set()
for (const line of (await fs.readFile(transcriptPath, 'utf8')).split('\n')) {
  let entry
  try {
    entry = JSON.parse(line)
  } catch {
    continue
  }
  const content = entry.message?.content
  if (!Array.isArray(content)) continue
  for (const block of content) {
    if (block.type === 'tool_use' && ['Edit', 'Write'].includes(block.name) && block.input?.file_path) {
      files.add(block.input.file_path)
    }
  }
}

if (files.size === 0) process.exit(0)

// Same pipeline as `task test` (unit first, integration only if unit passes),
// invoked directly so busted runs without the task wrapper's output framing.
for (const suite of ['unit', 'integration']) {
  const result = await $({ nothrow: true, quiet: true })`busted --run=${suite}`
  if (result.exitCode !== 0) {
    // Claude Code only honors decision:block (and parses stdout as JSON at
    // all) on exit 0 — exiting with busted's own code would suppress the block.
    echo(JSON.stringify({ decision: 'block', reason: result.stdall }))
    break
  }
}

process.exit(0)
