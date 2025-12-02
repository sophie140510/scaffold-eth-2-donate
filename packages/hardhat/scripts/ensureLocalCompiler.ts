import fs from "fs/promises";
import os from "os";
import path from "path";

const SOLC_VERSION = "0.8.26";
const SOLC_LONG_VERSION = "0.8.26+commit.8a97fa7a";
const COMPILER_PLATFORM = "linux-amd64";
const COMPILER_FILE_NAME = `solc-${COMPILER_PLATFORM}-v${SOLC_LONG_VERSION}`;

async function ensureCompilerList(listPath: string) {
  const listDir = path.dirname(listPath);
  await fs.mkdir(listDir, { recursive: true });

  const list = {
    builds: [
      {
        path: COMPILER_FILE_NAME,
        version: SOLC_VERSION,
        build: "local",
        longVersion: SOLC_LONG_VERSION,
        keccak256: "",
        urls: [COMPILER_FILE_NAME],
        platform: COMPILER_PLATFORM,
      },
    ],
    latestRelease: SOLC_VERSION,
    releases: {
      [SOLC_VERSION]: COMPILER_FILE_NAME,
    },
  };

  await fs.writeFile(listPath, `${JSON.stringify(list, null, 2)}\n`);
}

async function ensureCompilerBinary(binaryPath: string) {
  await fs.mkdir(path.dirname(binaryPath), { recursive: true });

  const solcModulePath = require.resolve("solc", {
    paths: [path.resolve(__dirname, "..")],
  });

  const shim = [
    "#!/usr/bin/env node",
    "const fs = require('fs');",
    `const solc = require(${JSON.stringify(solcModulePath)});`,
    "const chunks = [];",
    "process.stdin.on('data', chunk => chunks.push(chunk));",
    "process.stdin.on('end', () => {",
    "  const input = Buffer.concat(chunks).toString();",
    "  let output;",
    "  try {",
    "    output = solc.compile(input);",
    "  } catch (error) {",
    "    console.error(error instanceof Error ? error.message : error);",
    "    process.exitCode = 1;",
    "    return;",
    "  }",
    "  process.stdout.write(output);",
    "});",
    "process.stdin.resume();",
    "",
  ].join("\n");

  await fs.writeFile(binaryPath, shim, { mode: 0o755 });
}

export async function ensureLocalCompilerCache() {
  const compilersRoot = path.join(os.homedir(), ".cache", "hardhat-nodejs", "compilers-v2");
  const platformDir = path.join(compilersRoot, COMPILER_PLATFORM);

  const listPath = path.join(platformDir, "list.json");
  const binaryPath = path.join(platformDir, COMPILER_FILE_NAME);

  await ensureCompilerList(listPath);
  await ensureCompilerBinary(binaryPath);
}
