#!/usr/bin/env node
// TubeZero: BrighterScript resolves a bare name inside a namespace to a namespace function of the same name
// (case-insensitive), so a parameter called `today` next to a `Today()` function compiles into a reference to
// the function and fails at runtime ("Operator - can't be applied to Function"). bsc doesn't flag it; this
// scans the compiled .brs for namespaced functions used as values and fails the build when it finds one.
// Deliberate references (callbacks, parser tables) keep the declared spelling, while a shadowing local keeps
// its own (`YourTubeKids_today` for `YourTubeKids_Today`), so a value whose case differs from the
// declaration is the tell.
const fs = require("fs");
const path = require("path");

const root = process.argv[2] || "build/playlet-lib";
const files = [];
(function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) walk(full);
        else if (entry.name.endsWith(".brs")) files.push(full);
    }
})(root);

const sources = files.map((file) => [file, fs.readFileSync(file, "utf8")]);
const functions = new Map(); // lowercase name -> declared spelling
for (const [, text] of sources) {
    for (const match of text.matchAll(/^\s*(?:function|sub)\s+(\w+_\w+)\s*\(/gim)) {
        functions.set(match[1].toLowerCase(), match[1]);
    }
}

const problems = [];
for (const [file, text] of sources) {
    text.split("\n").forEach((line, i) => {
        const code = line.replace(/"[^"]*"/g, '""').split("'")[0];
        if (/^\s*(?:end\s+)?(?:function|sub)\b/i.test(code)) return;
        for (const match of code.matchAll(/(?<![\w.])(\w+_\w+)\b(?!\s*\()/g)) {
            const declared = functions.get(match[1].toLowerCase());
            if (declared !== undefined && declared !== match[1] && !match[1].startsWith("__")) {
                problems.push(`${path.relative(root, file)}:${i + 1}: ${code.trim()}`);
            }
        }
    });
}

if (problems.length > 0) {
    console.error("Namespaced function used as a value (a local or parameter shares its name?):");
    for (const problem of problems) console.error("  " + problem);
    process.exit(1);
}
