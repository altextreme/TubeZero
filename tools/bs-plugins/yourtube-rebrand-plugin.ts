// YourTube: rewrites the user-visible app name in the staged build, so the
// upstream locale files can stay untouched (keeps merges from Playlet clean).
// Only <translation> text and loading messages are changed; <source> keys are
// left alone because tr() looks strings up by source text.

import {
    CompilerPlugin, FileObj, ProgramBuilder,
} from 'brighterscript';
import path from 'path';
import fs from 'fs-extra'
import { exitOnCriticalErrors } from './critical-exit';

const FROM = /\bPlaylet\b/g;
const TO = 'YourTube';

export class YourTubeRebrandPlugin implements CompilerPlugin {
    public name = 'YourTubeRebrandPlugin';

    afterPrepublish(builder: ProgramBuilder, files: FileObj[]) {
        for (const file of files) {
            const dest = file.dest.replace(/\\/g, '/');
            const filePath = path.join(builder.options.stagingDir!, file.dest);

            if (/(^|\/)locale\/[^/]+\/translations\.ts$/.test(dest)) {
                const contents = fs.readFileSync(filePath, 'utf8');
                const rewritten = contents.replace(
                    /(<translation>)([\s\S]*?)(<\/translation>)/g,
                    (_m, open, text, close) => open + text.replace(FROM, TO) + close,
                );
                fs.writeFileSync(filePath, rewritten);
            } else if (/(^|\/)loading-messages\.json5?$/.test(dest)) {
                const contents = fs.readFileSync(filePath, 'utf8');
                fs.writeFileSync(filePath, contents.replace(FROM, TO));
            }
        }
    }

    // Theme: swap Playlet's colors for YourTube's in the transpiled output
    // (.xml and .brs), instead of editing every upstream component.
    afterPublish(builder: ProgramBuilder, _files: FileObj[]) {
        const stagingDir = builder.options.stagingDir!;
        for (const filePath of walk(stagingDir)) {
            if (!/\.(xml|brs)$/i.test(filePath)) {
                continue;
            }
            const contents = fs.readFileSync(filePath, 'utf8');
            let rewritten = contents;
            for (const [from, to] of THEME_COLORS) {
                rewritten = rewritten.replace(new RegExp(`(#|0x)${from}`, 'gi'), `$1${to}`);
            }
            if (rewritten !== contents) {
                fs.writeFileSync(filePath, rewritten);
            }
        }
    }
}

// Playlet color (RRGGBB) -> YourTube color
const THEME_COLORS: [string, string][] = [
    // Background / surfaces: Playlet gray -> YouTube near-black
    ['242424', '0F0F0F'],
];

function* walk(dir: string): Generator<string> {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            yield* walk(full);
        } else {
            yield full;
        }
    }
}

export default () => {
    return exitOnCriticalErrors(new YourTubeRebrandPlugin());
};
