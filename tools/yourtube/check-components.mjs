#!/usr/bin/env node
// YourTube: catches component XML mistakes the BrighterScript compiler lets through but Roku rejects at runtime:
//   - an <interface> field that re-declares a field from an ancestor component in this project
//     ("Attempt to add duplicate field ... Extends node type already has a field named ...").
// Usage: node tools/yourtube/check-components.mjs   (exit code 1 on problems)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const dirs = ['playlet-lib/src/components', 'playlet-app/src/components'];

function walk(dir, out = []) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            if (entry.name !== 'tests') walk(full, out);
        } else if (entry.name.endsWith('.xml') && !entry.name.endsWith('.part.xml')) {
            out.push(full);
        }
    }
    return out;
}

const components = new Map();
for (const dir of dirs) {
    for (const file of walk(path.join(root, dir))) {
        const xml = fs.readFileSync(file, 'utf8').replace(/<!--[\s\S]*?-->/g, '');
        const head = xml.match(/<component\s[^>]*>/);
        if (!head) continue;
        const name = head[0].match(/\bname="([^"]+)"/)?.[1];
        const ext = head[0].match(/\bextends="([^"]+)"/)?.[1];
        const iface = xml.match(/<interface>([\s\S]*?)<\/interface>/)?.[1] ?? '';
        const fields = [...iface.matchAll(/<field\s[^>]*\bid="([^"]+)"/g)].map((m) => m[1]);
        if (name) components.set(name, { file: path.relative(root, file), ext, fields });
    }
}

let problems = 0;
for (const [name, comp] of components) {
    const seen = new Set(comp.fields);
    let parent = components.get(comp.ext);
    const chain = [];
    while (parent) {
        chain.push(parent);
        for (const field of parent.fields) {
            if (seen.has(field)) {
                console.error(`${comp.file}: "${name}" re-declares field "${field}" from ancestor (${parent.file})`);
                problems++;
            }
        }
        if (chain.length > 20) break;
        parent = components.get(parent.ext);
    }
}

if (problems) {
    console.error(`${problems} component problem(s). Roku will refuse to create these components.`);
    process.exit(1);
}
console.log(`Component check OK (${components.size} components).`);
