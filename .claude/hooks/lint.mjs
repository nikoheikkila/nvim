#!/usr/bin/env zx

// Tool configs (selene.toml, stylua.toml) resolve from the project root — the
// session shell's working directory may be a subdirectory.
cd(process.env.CLAUDE_PROJECT_DIR ?? path.resolve(__dirname, "../.."));

const input = JSON.parse(await stdin());
const filePath = input.tool_input?.file_path;

if (!filePath || !fs.existsSync(filePath)) process.exit(0);

const ext = path.extname(filePath).slice(1);
const run = $({ nothrow: true, quiet: true });

const selene = (path) => run`selene ${path}`;
const stylua = (path) => run`stylua --check ${path}`;
const markdownLint = (path) => run`markdownlint-cli2 ${path}`;
const shellCheck = (path) => run`shellcheck ${path}`;
const actionlint = (path) => run`actionlint ${path}`;
const zizmor = (path) => run`zizmor --persona auditor ${path}`;

// Each check emits machine-readable output: JSON where the tool supports it,
// otherwise the tool's terse one-finding-per-line text (markdownlint-cli2 has
// no JSON output without an extra formatter package).
const checks = [];

if (ext === "lua") {
  checks.push(selene(filePath));
  checks.push(stylua(filePath));
}

if (ext === "md") {
  checks.push(markdownLint(filePath));
}

if (ext === "sh") {
  checks.push(shellCheck(filePath));
}

if (
  ["yml", "yaml"].includes(ext) &&
  path.dirname(filePath).includes(".github/workflows")
) {
  checks.push(actionlint(filePath));
  checks.push(zizmor(filePath));
}

if (
  ["yml", "yaml"].includes(ext) &&
  path.dirname(filePath).includes(".github/actions")
) {
  checks.push(zizmor(filePath));
}

const failures = (await Promise.all(checks)).filter(
  (result) => result.exitCode !== 0,
);

// markdownlint-cli2's version/file-list banner carries no diagnostic value
const banner = /^(markdownlint-cli2 v|Finding: |Linting: )/;

if (failures.length > 0) {
  const reason = failures
    .flatMap((result) => result.stdall.trim().split("\n"))
    .filter((line) => !banner.test(line))
    .join("\n");

  // A PostToolUse hook blocks by exiting 2 with the reason on STDERR: Claude
  // Code feeds stderr back to the model on a non-zero exit and discards stdout,
  // so a stdout JSON payload here would be silently dropped ("No stderr output").
  console.error(reason);
  process.exit(2);
}

process.exit(0);
