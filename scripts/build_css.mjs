#!/usr/bin/env bun
import { spawn } from "node:child_process"
import watcher from "@parcel/watcher"
import { resolve } from "node:path"

const INPUT = "app/assets/stylesheets/application.tailwind.css"
const OUTPUT = "app/assets/builds/application.css"
const WATCH_PATHS = [
  "app/views",
  "app/components",
  "app/helpers",
  "app/javascript",
  "app/assets/stylesheets",
]
const IGNORE = ["**/node_modules/**", "**/tmp/**", "**/log/**", "**/vendor/**", "**/.git/**"]

const TAILWIND_BIN = "node_modules/.bin/tailwindcss"

function build() {
  return new Promise((resolveBuild, rejectBuild) => {
    const args = ["-i", INPUT, "-o", OUTPUT, "--minify"]
    const started = Date.now()
    const proc = spawn(TAILWIND_BIN, args, { stdio: ["ignore", "pipe", "pipe"] })

    let stderr = ""
    proc.stderr.on("data", (chunk) => (stderr += chunk.toString()))

    proc.on("exit", (code) => {
      if (code === 0) {
        console.log(`[build:css] ${OUTPUT} in ${Date.now() - started}ms`)
        resolveBuild()
      } else {
        console.error(`[build:css] failed (exit ${code})\n${stderr}`)
        rejectBuild(new Error(`tailwindcss exit ${code}`))
      }
    })
  })
}

await build().catch((e) => {
  if (!process.argv.includes("--watch")) {
    process.exit(1)
  }
  console.error("[build:css]", e.message)
})

if (process.argv.includes("--watch")) {
  console.log(`[build:css] watching ${WATCH_PATHS.join(", ")}`)
  for (const path of WATCH_PATHS) {
    await watcher.subscribe(
      resolve(path),
      async (err) => {
        if (err) return console.error("[build:css]", err)
        try {
          await build()
        } catch (e) {
          console.error("[build:css]", e.message)
        }
      },
      { ignore: IGNORE },
    )
  }
}
