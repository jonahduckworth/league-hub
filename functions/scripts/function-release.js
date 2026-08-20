#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const {execFileSync} = require("node:child_process");

const RELEASE_PLAN_PATH = "functions/release-plan.json";
const FUNCTION_NAME = /^[A-Za-z][A-Za-z0-9_]*$/;
const SHARED_RUNTIME_FILES = new Set([
  "functions/package.json",
  "functions/package-lock.json",
  "functions/tsconfig.json",
]);

function parseArgs(args) {
  const parsed = {_: []};
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (!arg.startsWith("--")) {
      parsed._.push(arg);
      continue;
    }
    const name = arg.slice(2);
    const value = args[index + 1];
    if (value == null || value.startsWith("--")) {
      parsed[name] = true;
    } else {
      parsed[name] = value;
      index += 1;
    }
  }
  return parsed;
}

function normalizeTargets(value) {
  const values = Array.isArray(value) ? value : String(value ?? "").split(",");
  const targets = values.map((target) => target.trim()).filter(Boolean);
  const unique = new Set(targets);
  if (unique.size !== targets.length) {
    throw new Error("Function deploy targets must not contain duplicates.");
  }
  for (const target of targets) {
    if (!FUNCTION_NAME.test(target)) {
      throw new Error(`Invalid Function deploy target: ${target}`);
    }
  }
  return targets;
}

function parseReleasePlan(contents) {
  const plan = JSON.parse(contents);
  if (typeof plan !== "object" || plan == null || Array.isArray(plan)) {
    throw new Error("functions/release-plan.json must contain an object.");
  }
  if (typeof plan.all !== "boolean") {
    throw new Error("functions/release-plan.json must include an all boolean.");
  }
  if (!Array.isArray(plan.targets)) {
    throw new Error("functions/release-plan.json must include a targets array.");
  }
  if (typeof plan.reason !== "string" || plan.reason.trim().length < 10) {
    throw new Error("functions/release-plan.json must explain the release in reason.");
  }
  const targets = normalizeTargets(plan.targets);
  if (plan.all && targets.length > 0) {
    throw new Error("An all-functions release cannot also specify individual targets.");
  }
  return {all: plan.all, targets, reason: plan.reason.trim()};
}

function classifyChangedFiles(files) {
  const workflowChanged = files.some((file) =>
    file === ".github/workflows/deploy-web.yml" ||
    file === ".github/workflows/deploy-functions.yml",
  );
  const firebaseConfigChanged = files.some((file) =>
    file === ".firebaserc" || file === "firebase.json",
  );
  const functionsValidationChanged = files.some((file) => file.startsWith("functions/"));
  const functionsRuntimeChanged = files.some((file) =>
    file.startsWith("functions/src/") || SHARED_RUNTIME_FILES.has(file),
  );
  const adminChanged = files.some((file) => file.startsWith("apps/admin/"));
  const marketingChanged = files.some((file) => file.startsWith("apps/marketing/"));

  return {
    functionsValidate: workflowChanged || firebaseConfigChanged || functionsValidationChanged || adminChanged,
    functionsDeploy: functionsRuntimeChanged,
    adminValidate: workflowChanged || firebaseConfigChanged || adminChanged,
    adminDeploy: firebaseConfigChanged || adminChanged,
    marketingValidate: workflowChanged || firebaseConfigChanged || marketingChanged,
    marketingDeploy: firebaseConfigChanged || marketingChanged,
  };
}

function validateAutomaticPlan(files, plan) {
  const classification = classifyChangedFiles(files);
  if (!classification.functionsDeploy) return classification;

  if (!files.includes(RELEASE_PLAN_PATH)) {
    throw new Error(
      "Production Functions changed without updating functions/release-plan.json.",
    );
  }
  const sharedRuntimeChanged = files.some((file) => SHARED_RUNTIME_FILES.has(file));
  if (sharedRuntimeChanged && !plan.all) {
    throw new Error(
      "Shared Functions runtime or Firebase configuration changes require an explicit all-functions release.",
    );
  }
  if (!plan.all && plan.targets.length === 0) {
    throw new Error("List every affected Function export in functions/release-plan.json.");
  }
  return classification;
}

function changedFiles(base, head) {
  if (!base || !head) throw new Error("Both --base and --head are required.");
  const output = execFileSync("git", ["diff", "--name-only", base, head], {
    encoding: "utf8",
  });
  return output.split("\n").map((file) => file.trim()).filter(Boolean);
}

function validateTargetsAgainstExports(targets, exportedNames) {
  const names = new Set(exportedNames);
  const missing = targets.filter((target) => !names.has(target));
  if (missing.length > 0) {
    throw new Error(`Unknown Function exports: ${missing.join(", ")}`);
  }
}

function localFunctionExports(repoRoot) {
  const modulePath = path.join(repoRoot, "functions", "lib", "index.js");
  const exports = require(modulePath);
  return Object.entries(exports)
    .filter(([, value]) => typeof value === "function")
    .map(([name]) => name)
    .sort();
}

function verifyDeployment({functionsList, targets, expectedRuntime, expectedRegion}) {
  if (functionsList?.status !== "success" || !Array.isArray(functionsList.result)) {
    throw new Error("Firebase Functions list did not return a successful result.");
  }
  const functionsById = new Map(functionsList.result.map((entry) => [entry.id, entry]));
  for (const target of targets) {
    const deployed = functionsById.get(target);
    if (!deployed) throw new Error(`Deployed Function is missing: ${target}`);
    if (deployed.state !== "ACTIVE") {
      throw new Error(`${target} is ${deployed.state ?? "in an unknown state"}, not ACTIVE.`);
    }
    if (deployed.runtime !== expectedRuntime) {
      throw new Error(`${target} is running ${deployed.runtime}, not ${expectedRuntime}.`);
    }
    if (deployed.region !== expectedRegion) {
      throw new Error(`${target} is deployed in ${deployed.region}, not ${expectedRegion}.`);
    }
  }
  return targets.map((target) => {
    const deployed = functionsById.get(target);
    return {
      id: target,
      region: deployed.region,
      runtime: deployed.runtime,
      state: deployed.state,
    };
  });
}

function appendOutputs(outputPath, outputs) {
  if (!outputPath) {
    console.log(JSON.stringify(outputs, null, 2));
    return;
  }
  const lines = Object.entries(outputs).map(([key, value]) => `${key}=${value}\n`).join("");
  fs.appendFileSync(outputPath, lines);
}

function readPlan(repoRoot) {
  return parseReleasePlan(fs.readFileSync(path.join(repoRoot, RELEASE_PLAN_PATH), "utf8"));
}

function runPlan(args) {
  const repoRoot = path.resolve(args["repo-root"] ?? path.join(__dirname, "../.."));
  const files = changedFiles(args.base, args.head);
  const plan = readPlan(repoRoot);
  const classification = validateAutomaticPlan(files, plan);
  appendOutputs(args.output, {
    functions_validate: classification.functionsValidate,
    functions_deploy: classification.functionsDeploy,
    functions_all: plan.all,
    functions_targets: plan.targets.join(","),
    admin_validate: classification.adminValidate,
    admin_deploy: classification.adminDeploy,
    marketing_validate: classification.marketingValidate,
    marketing_deploy: classification.marketingDeploy,
  });
}

function runTargets(args) {
  const repoRoot = path.resolve(args["repo-root"] ?? path.join(__dirname, "../.."));
  const all = args.all === true || args.all === "true";
  const targets = all ? localFunctionExports(repoRoot) : normalizeTargets(args.targets);
  if (targets.length === 0) throw new Error("At least one Function deploy target is required.");
  validateTargetsAgainstExports(targets, localFunctionExports(repoRoot));
  appendOutputs(args.output, {
    target_names: targets.join(","),
    firebase_only: all ? "functions" : targets.map((target) => `functions:${target}`).join(","),
  });
}

function runVerify(args) {
  const functionsList = JSON.parse(fs.readFileSync(args["functions-list"], "utf8"));
  const targets = normalizeTargets(args.targets);
  if (targets.length === 0) throw new Error("At least one deployed Function must be verified.");
  const verified = verifyDeployment({
    functionsList,
    targets,
    expectedRuntime: args.runtime,
    expectedRegion: args.region,
  });
  console.log(JSON.stringify({verified}, null, 2));
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0];
  if (command === "plan") return runPlan(args);
  if (command === "targets") return runTargets(args);
  if (command === "verify") return runVerify(args);
  throw new Error("Use plan, targets, or verify.");
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  }
}

module.exports = {
  classifyChangedFiles,
  normalizeTargets,
  parseReleasePlan,
  validateAutomaticPlan,
  validateTargetsAgainstExports,
  verifyDeployment,
};
