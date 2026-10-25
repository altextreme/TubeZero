// TubeZero: phone pairing. Routes that act as the signed-in user or control playback answer 401 until this
// phone has typed the code the TV shows. The token is kept in localStorage (per TV) and sent as a header; the
// TV also sets a tz_pair cookie so plain links (/invidious/login, /watch) carry it too.
import { getHost } from "lib/Api/Host";
import { addToast } from "lib/Toast";

export const PairHeader = "X-TubeZero-Pair";
const CsrfHeader = "X-Playlet";
const CookieName = "tz_pair";

const host = () => `http://${getHost()}`;
const storageKey = () => `tubezero_pair_token_${getHost()}`;

export function getPairToken(): string | null {
    try {
        return localStorage.getItem(storageKey());
    } catch {
        return null;
    }
}

function setPairToken(token: string | null) {
    try {
        if (token) {
            localStorage.setItem(storageKey(), token);
        } else {
            localStorage.removeItem(storageKey());
        }
    } catch {
        // private mode: the cookie still works for this session
    }
    if (token) {
        document.cookie = `${CookieName}=${token}; path=/; max-age=315360000; samesite=lax`;
    }
}

export function withPairHeader(headers: Record<string, string> = {}) {
    const token = getPairToken();
    if (token) {
        headers[PairHeader] = token;
    }
    return headers;
}

export async function isPairingRequired(response: Response) {
    if (response.status === 401) {
        return true;
    }
    if (response.status === 403) {
        const body = await response.clone().text().catch(() => "");
        return body.includes("pair");
    }
    return false;
}

let pending: Promise<boolean> | null = null;

// Shows a code on the TV and asks for it. Concurrent callers share one prompt.
export function requestPairing(): Promise<boolean> {
    if (!pending) {
        pending = pair().finally(() => {
            pending = null;
        });
    }
    return pending;
}

async function pair(): Promise<boolean> {
    setPairToken(null);
    for (let attempt = 0; attempt < 3; attempt++) {
        const codeResponse = await fetch(`${host()}/api/pair/code`, { method: "POST", headers: { [CsrfHeader]: "1" } });
        if (!codeResponse.ok && codeResponse.status !== 429) {
            addToast("Couldn't show a pairing code on the TV.", "error");
            return false;
        }
        const message = attempt === 0
            ? "Pair this phone with TubeZero.\nEnter the code shown on your TV:"
            : "That code didn't work. A new code is on your TV:";
        const code = window.prompt(message);
        if (!code) {
            return false;
        }
        const response = await fetch(`${host()}/api/pair`, {
            method: "POST",
            headers: { [CsrfHeader]: "1", "Content-Type": "application/json" },
            body: JSON.stringify({ code: code.trim() }),
        });
        if (response.ok) {
            const { token } = await response.json();
            setPairToken(token);
            addToast("Phone paired with TubeZero.", "success");
            return true;
        }
        // The TV closes the code after one try; wait out its 2 s rate limit before asking for a new one.
        await new Promise((resolve) => setTimeout(resolve, 2100));
    }
    return false;
}

// For links the browser opens itself: pair first if needed so the cookie is set.
export async function ensurePaired(): Promise<boolean> {
    const token = getPairToken();
    if (token) {
        const response = await fetch(`${host()}/api/pair/status`, { headers: withPairHeader() }).catch(() => null);
        const status = await response?.json().catch(() => null);
        if (status?.paired) {
            setPairToken(token);
            return true;
        }
    }
    return await requestPairing();
}

// fetch() that adds the pairing header, and pairs and retries once when the TV asks for it.
export async function pairedFetch(url: string, init: RequestInit = {}): Promise<Response> {
    const run = () => fetch(url, { ...init, headers: withPairHeader({ ...(init.headers as Record<string, string> ?? {}) }) });
    const response = await run();
    if (!(await isPairingRequired(response))) {
        return response;
    }
    if (!(await requestPairing())) {
        return response;
    }
    return await run();
}
