#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const value = argv[i + 1];
    if (!value || value.startsWith("--")) throw new Error(`Missing value for --${key}`);
    args[key] = value;
    i += 1;
  }
  return args;
}

function resolvePlaywrightModule(explicitModule) {
  const candidates = [
    explicitModule,
    process.env.PLAYWRIGHT_MODULE,
    "playwright",
    "C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright",
  ].filter(Boolean);
  for (const candidate of candidates) {
    try {
      return require(candidate);
    } catch {
      // Try the next configured runtime.
    }
  }
  throw new Error("Playwright is unavailable. Set PLAYWRIGHT_MODULE or pass --playwright-module.");
}

function ensureFile(filePath, label) {
  const absolute = path.resolve(filePath);
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
    throw new Error(`${label} file does not exist: ${absolute}`);
  }
  return absolute;
}

function extractSimilarity(text) {
  const match = text.match(/-?\d+(?:\.\d+)?/);
  return match ? Number(match[0]) : null;
}

const args = parseArgs(process.argv.slice(2));
if (!args.source || !args.derivative || !args.report || !args.screenshot) {
  throw new Error(
    "Usage: check_wenpipi_originality.mjs --source <reference.txt> --derivative <script.txt> --report <report.json> --screenshot <result.png> [--url http://www.wenpipi.com/sim] [--level 1] [--browser <chrome.exe>] [--playwright-module <path>]",
  );
}

const sourcePath = ensureFile(args.source, "Source");
const derivativePath = ensureFile(args.derivative, "Derivative");
const reportPath = path.resolve(args.report);
const screenshotPath = path.resolve(args.screenshot);
const source = fs.readFileSync(sourcePath, "utf8").trim();
const derivative = fs.readFileSync(derivativePath, "utf8").trim();
if (!source || !derivative) throw new Error("Source and derivative text must both be non-empty.");

const { chromium } = resolvePlaywrightModule(args["playwright-module"]);
const browserOptions = { headless: true };
if (args.browser) browserOptions.executablePath = args.browser;
const browser = await chromium.launch(browserOptions);
const browserLog = [];

try {
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.mkdirSync(path.dirname(screenshotPath), { recursive: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  page.on("console", (message) => browserLog.push(`console:${message.type()}:${message.text()}`));
  page.on("pageerror", (error) => browserLog.push(`pageerror:${error.message}`));

  const url = args.url || "http://www.wenpipi.com/sim";
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
  await page.waitForFunction(
    () => typeof window.StartHetuEngine === "function" && window.gPenCapacity && Number(window.gPenCapacity.maxSim) > 0,
    null,
    { timeout: 60000 },
  );
  await page.locator("#content1").fill(source);
  await page.locator("#content2").fill(derivative);
  await page.selectOption("#HetuEngineLevelSelectId", String(args.level || "1"));
  await page.locator("button.jianceBtC").click();
  await page.waitForFunction(
    () => {
      const result = document.querySelector("#resultContentDivId")?.innerText?.trim() || "";
      const time = document.querySelector("#timeConsumDivId")?.innerText?.trim() || "";
      return result.length > 0 && /\d/.test(time);
    },
    null,
    { timeout: 180000 },
  );

  const pageResult = await page.evaluate(() => ({
    similarityText: document.querySelector("#simDivId")?.innerText?.trim() || "",
    verdictText: document.querySelector("#judgeDivId")?.innerText?.trim() || "",
    elapsedText: document.querySelector("#timeConsumDivId")?.innerText?.trim() || "",
    resultText: document.querySelector("#resultContentDivId")?.innerText?.trim() || "",
    leftCount: document.querySelector("#leftCurSizeId")?.innerText?.trim() || "",
    rightCount: document.querySelector("#rightCurSizeId")?.innerText?.trim() || "",
  }));
  await page.screenshot({ path: screenshotPath, fullPage: true });

  const similarityPercent = extractSimilarity(pageResult.similarityText);
  const validRun =
    pageResult.resultText.length > 0 &&
    /\d/.test(pageResult.elapsedText) &&
    similarityPercent !== null;
  const originalVerdict = /鉴定结果\s*[：:]?\s*原创/.test(pageResult.verdictText);
  const status = validRun && originalVerdict ? "pass" : "fail";
  const report = {
    schemaVersion: 1,
    gate: "O01",
    provider: "wenpipi",
    url,
    engineLevel: String(args.level || "1"),
    sourcePath,
    derivativePath,
    screenshotPath,
    checkedAt: new Date().toISOString(),
    sourceCount: pageResult.leftCount,
    derivativeCount: pageResult.rightCount,
    similarityText: pageResult.similarityText,
    similarityPercent,
    verdictText: pageResult.verdictText,
    elapsedText: pageResult.elapsedText,
    validRun,
    originalVerdict,
    status,
    browserLog: browserLog.slice(-30),
  };
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  process.stdout.write(`${JSON.stringify(report)}\n`);
  if (status !== "pass") process.exitCode = 2;
} finally {
  await browser.close();
}
