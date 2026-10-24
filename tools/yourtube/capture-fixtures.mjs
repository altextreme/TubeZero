#!/usr/bin/env node
// YourTube: saves raw InnerTube (WEB client) responses as parser test fixtures.
// Uses youtubei.js only as an HTTP client (parse: false), so the JSON is exactly what YouTube sends.
// Responses are trimmed to the parts our parsers read, to keep fixtures small.
//
// Usage: node tools/yourtube/capture-fixtures.mjs [videoId] [liveVideoId]
import { Innertube } from 'youtubei.js';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const outDir = path.join(root, 'playlet-lib/src/source/tests/fixtures/yourtube');
const videoId = process.argv[2] || 'dQw4w9WgXcQ';
const liveVideoId = process.argv[3] || 'jfKfPfyJRdk';
const MAX_COMMENTS = 20;

function findAll(node, predicate, out = []) {
    if (Array.isArray(node)) {
        node.forEach((child) => findAll(child, predicate, out));
    } else if (node && typeof node === 'object') {
        if (predicate(node)) out.push(node);
        Object.values(node).forEach((child) => findAll(child, predicate, out));
    }
    return out;
}

function save(name, data) {
    fs.mkdirSync(outDir, { recursive: true });
    const file = path.join(outDir, name);
    fs.writeFileSync(file, JSON.stringify(data, null, 1));
    console.log(`wrote ${path.relative(root, file)} (${(fs.statSync(file).size / 1024).toFixed(0)} KB)`);
}

const yt = await Innertube.create({ retrieve_player: false, lang: 'en', location: 'US' });
const exec = async (endpoint, args) => (await yt.actions.execute(endpoint, { ...args, parse: false })).data;

// 1. /next for a regular video: comments entry point + continuation, like button state
const next = await exec('/next', { videoId });
const commentSection = findAll(next, (n) => n.sectionIdentifier === 'comment-item-section')[0];
save('next-video.json', {
    contents: {
        twoColumnWatchNextResults: {
            results: { results: { contents: next.contents?.twoColumnWatchNextResults?.results?.results?.contents ?? [] } },
        },
    },
    engagementPanels: next.engagementPanels ?? [],
    frameworkUpdates: next.frameworkUpdates,
});
const commentsToken = findAll(commentSection, (n) => n.continuationCommand?.token)[0]?.continuationCommand?.token;
if (!commentsToken) throw new Error('No comments continuation in /next');

// 2. First comments page (top comments), trimmed to MAX_COMMENTS threads
const comments = await exec('/next', { continuation: commentsToken });
const keepKeys = new Set();
for (const action of comments.onResponseReceivedEndpoints ?? []) {
    const items = (action.reloadContinuationItemsCommand ?? action.appendContinuationItemsAction)?.continuationItems;
    if (!items) continue;
    const threads = items.filter((i) => i.commentThreadRenderer);
    const rest = items.filter((i) => !i.commentThreadRenderer);
    const kept = threads.slice(0, MAX_COMMENTS);
    findAll(kept, (n) => typeof n.commentKey === 'string').forEach((n) => keepKeys.add(n.commentKey));
    findAll(kept, (n) => typeof n.toolbarStateKey === 'string').forEach((n) => keepKeys.add(n.toolbarStateKey));
    findAll(kept, (n) => typeof n.commentSurfaceKey === 'string').forEach((n) => keepKeys.add(n.commentSurfaceKey));
    findAll(kept, (n) => typeof n.sharedKey === 'string').forEach((n) => keepKeys.add(n.sharedKey));
    (action.reloadContinuationItemsCommand ?? action.appendContinuationItemsAction).continuationItems = [...kept, ...rest];
}
const mutations = comments.frameworkUpdates?.entityBatchUpdate?.mutations ?? [];
comments.frameworkUpdates.entityBatchUpdate.mutations = mutations.filter((m) => keepKeys.has(m.entityKey));
delete comments.responseContext;
save('comments-page.json', comments);

// 3. Replies to the first thread that has any
const replyToken = findAll(comments, (n) => n.commentRepliesRenderer)
    .map((r) => findAll(r, (n) => n.continuationCommand?.token)[0]?.continuationCommand?.token)
    .find(Boolean);
if (replyToken) {
    const replies = await exec('/next', { continuation: replyToken });
    delete replies.responseContext;
    save('comment-replies.json', replies);
}

// 4. Live chat: /next for a live stream -> chat continuation -> get_live_chat.
// Falls back to the first live result of a search if the given stream isn't live.
async function liveChatToken(id) {
    const data = await exec('/next', { videoId: id });
    const token = findAll(data, (n) => n.reloadContinuationData?.continuation)[0]?.reloadContinuationData?.continuation;
    return { data, token };
}
let { data: liveNext, token: chatToken } = await liveChatToken(liveVideoId);
if (!chatToken) {
    const search = await yt.search('live news', { features: ['live'] });
    for (const video of search.videos.slice(0, 5)) {
        const id = video.video_id ?? video.id;
        if (!id) continue;
        ({ data: liveNext, token: chatToken } = await liveChatToken(id));
        if (chatToken) {
            console.log(`using live stream ${id}`);
            break;
        }
    }
}
save('next-live.json', { contents: { twoColumnWatchNextResults: { conversationBar: liveNext.contents?.twoColumnWatchNextResults?.conversationBar } } });
if (chatToken) {
    const chat = await exec('/live_chat/get_live_chat', { continuation: chatToken });
    delete chat.responseContext;
    save('live-chat.json', chat);
} else {
    console.warn(`No live chat for ${liveVideoId} (not live right now?)`);
}
