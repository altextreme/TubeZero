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

    // Theme: swap Playlet's colors and fonts for YourTube's in the transpiled output
    // (.xml and .brs), instead of editing every upstream component.
    afterPublish(builder: ProgramBuilder, _files: FileObj[]) {
        const stagingDir = builder.options.stagingDir!;
        // Only the lib ships Roboto; the launcher keeps the system font.
        const hasRoboto = fs.existsSync(path.join(stagingDir, 'fonts/roboto'));
        for (const filePath of walk(stagingDir)) {
            if (!/\.(xml|brs)$/i.test(filePath)) {
                continue;
            }
            const contents = fs.readFileSync(filePath, 'utf8');
            let rewritten = rewriteColors(contents);
            if (hasRoboto) {
                if (filePath.toLowerCase().endsWith('.xml')) {
                    rewritten = rewritePresetFontAttributes(rewritten);
                }
                for (const [from, to] of THEME_FONTS) {
                    rewritten = rewritten.split(from).join(to);
                }
            }
            if (rewritten !== contents) {
                fs.writeFileSync(filePath, rewritten);
            }
        }
    }
}

// Playlet color (RRGGBB) -> YourTube color, applied in one pass (no chaining).
// Alpha suffixes are kept. See docs/UI-SPEC.md for the YouTube values.
const THEME_COLORS: Record<string, string> = {
    '242424': '0F0F0F', // page background
    '262626': '0F0F0F', // dark text on light focus / dark panels
    '202020': '0F0F0F', // dialog focused item text
    '323232': '212121', // side panels (playlist view)
    '3C3C3C': '282828', // unfocused button / key surface
    'DDDDDD': 'F1F1F1', // primary text, focused button surface
    'EBEBEB': 'F1F1F1', // primary text
    'CECECE': 'F1F1F1', // dialog focus
    'FEFEFE': 'F1F1F1', // player text
    'B4B4B4': 'AAAAAA', // secondary text
    '606060': '717171', // disabled
    'FF1C30': 'FF0033', // Playlet red -> YouTube red (progress, live)
    'D53E5A': 'FF0033', // live dot
    '4287F5': '3EA6FF', // links
};

function rewriteColors(text: string): string {
    return text.replace(/(#|0x)([0-9a-f]{6})(?=[0-9a-f]{2}\b|\b)/gi, (match, prefix, hex) => {
        const to = THEME_COLORS[hex.toUpperCase()];
        return to ? prefix + to : match;
    });
}

// Roku system font files -> bundled Roboto (OFL, playlet-lib/src/fonts/roboto).
const THEME_FONTS: [string, string][] = [
    ['font:MediumSystemFontFile', 'pkg:/fonts/roboto/Roboto-Medium.ttf'],
    ['font:BoldSystemFontFile', 'pkg:/fonts/roboto/Roboto-Bold.ttf'],
    ['font:SystemFontFile', 'pkg:/fonts/roboto/Roboto-Regular.ttf'],
];

// Roku preset fonts (720p sizes) -> Roboto. "Bold" presets map to Medium, which is
// what the YouTube TV app uses for emphasis outside of titles.
const PRESET_FONTS: Record<string, [string, number]> = {
    TinySystemFont: ['Regular', 14],
    TinyBoldSystemFont: ['Medium', 14],
    SmallestSystemFont: ['Regular', 18],
    SmallestBoldSystemFont: ['Medium', 18],
    SmallSystemFont: ['Regular', 22],
    SmallBoldSystemFont: ['Medium', 22],
    MediumSystemFont: ['Regular', 26],
    MediumBoldSystemFont: ['Medium', 26],
    LargeSystemFont: ['Regular', 30],
    LargeBoldSystemFont: ['Medium', 30],
};

// <Label font="font:SmallestSystemFont" .../> -> <Label ...><Font role="font" uri=Roboto size=18 /></Label>
function rewritePresetFontAttributes(xml: string): string {
    return xml.replace(
        /<([A-Za-z][\w:]*)([^<>]*?)\s(\w*[fF]ont)="font:(\w+)"([^<>]*?)(\/?)>/g,
        (match, tag, before, role, preset, after, selfClosing) => {
            const mapped = PRESET_FONTS[preset];
            if (!mapped) {
                return match;
            }
            const [weight, size] = mapped;
            const font = `<Font role="${role}" uri="pkg:/fonts/roboto/Roboto-${weight}.ttf" size="${size}" />`;
            return selfClosing
                ? `<${tag}${before}${after}>${font}</${tag}>`
                : `<${tag}${before}${after}>${font}`;
        },
    );
}

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
