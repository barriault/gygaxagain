#!/usr/bin/env bun
import postcss from "postcss"
import tailwindcss from "@tailwindcss/postcss"
import { readFile, writeFile, mkdir } from "node:fs/promises"
import { dirname } from "node:path"
import watcher from "@parcel/watcher"

const INPUT = "app/assets/stylesheets/application.tailwind.css"
const OUTPUT = "app/assets/builds/application.css"
const WATCH_PATHS = [
  "app/views",
  "app/components",
  "app/helpers",
  "app/javascript",
  "app/assets/stylesheets",
]
const IGNORE = ["node_modules", "tmp", "log", "vendor", ".git", "app/assets/builds"]

const processor = postcss([tailwindcss()])

async function build() {
  const css = await readFile(INPUT, "utf8")
  const started = Date.now()
  const result = await processor.process(css, { from: INPUT, to: OUTPUT })
  await mkdir(dirname(OUTPUT), { recursive: true })
  await writeFile(OUTPUT, result.css)
  const kb = (result.css.length / 1024).toFixed(1)
  const ms = Date.now() - started
  console.log(`[build:css] ${OUTPUT} (${kb} KB) in ${ms}ms`)
}

await build()

if (process.argv.includes("--watch")) {
  console.log(`[build:css] watching ${WATCH_PATHS.join(", ")}`)
  for (const path of WATCH_PATHS) {
    await watcher.subscribe(
      path,
      async (err) => {
        if (err) return console.error("[build:css]", err)
        try {
          await build()
        } catch (e) {
          console.error("[build:css]", e)
        }
      },
      { ignore: IGNORE },
    )
  }
}
