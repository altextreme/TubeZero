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
            } else if (/(^|\/)config\/preferences\.json5$/.test(dest)) {
                // user-visible labels only; keys and values stay as they are
                const contents = fs.readFileSync(filePath, 'utf8');
                // (the JSON plugin has already turned it into minified JSON by now)
                fs.writeFileSync(filePath, contents.replace(/"(displayText|description)":"((?:[^"\\]|\\.)*)"/g,
                    (_m, key, value) => `"${key}":"${value.replace(/\bPlaylet\b(?! Lib)/g, TO)}"`));
            } else if (/(^|\/)loading-messages\.json5?$/.test(dest)) {
                const contents = fs.readFileSync(filePath, 'utf8');
                fs.writeFileSync(filePath, contents.replace(FROM, TO));
            }
        }
    }

    // Theme: swap Playlet's colors and fonts for YourTube's in the transpiled output
    // (.xml and .brs), instead of editing every upstream component.
    afterPublish(builder: ProgramBuilder, _files: FileObj[]) {
        // Test builds keep Playlet's colors/fonts so the upstream specs keep asserting logic, not theme.
        if ((builder.options as any).testMode) {
            return;
        }
        const stagingDir = builder.options.stagingDir!;
        const widgetTags = WIDGET_STYLES.map((style) => findDerived(stagingDir, style.bases));
        // Only the lib ships Roboto; the launcher keeps the system font.
        const hasRoboto = fs.existsSync(path.join(stagingDir, 'fonts/roboto'));
        for (const filePath of walk(stagingDir)) {
            if (!/\.(xml|brs)$/i.test(filePath)) {
                continue;
            }
            const contents = fs.readFileSync(filePath, 'utf8');
            let rewritten = rewriteColors(contents);
            for (const [from, to] of THEME_IMAGES) {
                rewritten = rewritten.split(from).join(to);
            }
            if (hasRoboto) {
                if (filePath.toLowerCase().endsWith('.xml')) {
                    rewritten = rewritePresetFontAttributes(rewritten);
                    WIDGET_STYLES.forEach((style, i) => { rewritten = styleWidgets(rewritten, widgetTags[i], style); });
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
    '161616': '0F0F0F', // near-black written in code (lint wants broadcast-safe values)
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

// Playlet's shared UI images -> YourTube's (generated by tools/yourtube/make-assets.sh)
const THEME_IMAGES: [string, string][] = [
    ['focus-glow-padding-30.$$RES$$.9.png', 'yt-focus-ring.$$RES$$.9.png'],
    ['focus-glow-padding-42.$$RES$$.9.png', 'yt-focus-ring.$$RES$$.9.png'],
    ['button-ex.$$RES$$.9.png', 'yt-button-pill.$$RES$$.9.png'],
    // Google Material Symbols (Rounded), rendered by tools/yourtube/material-icons.sh
    ...([
        ['home', 'home'], ['search', 'search'], ['settings', 'settings'], ['info', 'info'],
        ['phone', 'smartphone'], ['star', 'bookmark'], ['user', 'account_circle'],
        ['user-200', 'account_circle_200'], ['filters', 'tune'], ['globe-white', 'language'],
        ['globe-black', 'language_dark'], ['edit', 'edit'], ['crown', 'workspace_premium'],
        ['test-passed', 'check_circle'], ['test-failed', 'cancel'],
        ['player/play', 'play_arrow'], ['player/pause', 'pause'], ['player/minimize', 'picture_in_picture_alt'],
        ['player/next', 'skip_next'], ['player/previous', 'skip_previous'],
    ] as [string, string][]).map(([from, to]) => [`images/icons/${from}.png`, `images/icons/ms/${to}.png`] as [string, string]),
];

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

// Roku's built-in widgets default to gray gradient bars. Give them the YouTube TV look (white pill focus,
// light text that turns dark on focus, Roboto), only where Playlet didn't set its own values.
type WidgetStyle = { bases: Set<string>; defaults: [string, string][]; fonts: string };
const roboto = (role: string, weight: string, size: number) =>
    `<Font role="${role}" uri="pkg:/fonts/roboto/Roboto-${weight}.ttf" size="${size}" />`;
const WIDGET_STYLES: WidgetStyle[] = [
    {
        // settings lists, dialogs, pickers: nothing behind resting rows; padded pill keeps text inset
        bases: new Set(['LabelList', 'CheckList', 'RadioButtonList']),
        defaults: [
            ['focusBitmapUri', 'pkg:/images/yt-pill-light-padded.$$RES$$.9.png'],
            ['focusFootprintBitmapUri', 'pkg:/images/yt-transparent.png'],
            ['color', '0xF1F1F1FF'],
            ['focusedColor', '0x0F0F0FFF'],
        ],
        fonts: roboto('font', 'Regular', 22) + roboto('focusedFont', 'Medium', 22),
    },
    {
        // standalone buttons: dark pill at rest, white pill on focus
        bases: new Set(['Button']),
        defaults: [
            ['focusBitmapUri', 'pkg:/images/yt-pill-light.$$RES$$.9.png'],
            ['focusFootprintBitmapUri', 'pkg:/images/yt-pill-dark.$$RES$$.9.png'],
            ['textColor', '0xF1F1F1FF'],
            ['focusedTextColor', '0x0F0F0FFF'],
        ],
        fonts: roboto('textFont', 'Regular', 22) + roboto('focusedTextFont', 'Medium', 22),
    },
];

// Component names in this build that extend (directly or not) one of the given base widgets.
function findDerived(stagingDir: string, bases: Set<string>): Set<string> {
    const parents = new Map<string, string>();
    for (const file of walk(stagingDir)) {
        if (!file.toLowerCase().endsWith('.xml')) continue;
        const head = fs.readFileSync(file, 'utf8').match(/<component\s[^>]*>/);
        const name = head?.[0].match(/\bname="([^"]+)"/)?.[1];
        const ext = head?.[0].match(/\bextends="([^"]+)"/)?.[1];
        if (name && ext) parents.set(name, ext);
    }
    const result = new Set(bases);
    for (const name of parents.keys()) {
        let current: string | undefined = name;
        for (let i = 0; current && i < 20; i++) {
            if (bases.has(current)) { result.add(name); break; }
            current = parents.get(current);
        }
    }
    return result;
}

function styleWidgets(xml: string, tags: Set<string>, style: WidgetStyle): string {
    return xml.replace(/<([A-Za-z][\w:]*)(\s[^<>]*?)?(\/?)>/g, (match, tag, attrs = '', selfClosing, offset) => {
        if (!tags.has(tag) || match.startsWith('<component')) {
            return match;
        }
        let added = '';
        for (const [name, value] of style.defaults) {
            if (!new RegExp(`\\s${name}=`).test(attrs)) {
                added += ` ${name}="${value}"`;
            }
        }
        const inner = selfClosing ? '' : xml.slice(offset, xml.indexOf(`</${tag}>`, offset));
        const hasFont = /\s\w*[fF]ont=/.test(attrs) || /role="\w*[fF]ont"/.test(inner);
        const fonts = hasFont ? '' : style.fonts;
        if (selfClosing) {
            return fonts ? `<${tag}${attrs}${added}>${fonts}</${tag}>` : `<${tag}${attrs}${added} />`;
        }
        return `<${tag}${attrs}${added}>${fonts}`;
    });
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
