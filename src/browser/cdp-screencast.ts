/**
 * CDP Screencast Service - Atlas/OWL-inspired embedded browser architecture.
 *
 * Uses Chrome DevTools Protocol for:
 * - Page.startScreencast: Stream rendered frames directly from Chromium compositor
 * - Input.dispatch*Event: Inject mouse/keyboard events directly to renderer (not OS-level)
 *
 * This gives us the same architecture as OpenAI Atlas:
 * - Chromium is process-isolated (runs via Playwright)
 * - Input is renderer-scoped (CDP injection, not OS events)
 * - Our UI only displays frames and forwards input
 * - Chromium owns all page state, JS execution, cookies, etc.
 */

import type { CDPSession, Page } from "playwright-core";
import { createSubsystemLogger } from "../logging/subsystem.js";
import { getPageForTargetId } from "./pw-session.js";

const log = createSubsystemLogger("browser").child("screencast");

export type ScreencastFrame = {
  data: string; // base64 JPEG
  metadata: {
    offsetTop: number;
    pageScaleFactor: number;
    deviceWidth: number;
    deviceHeight: number;
    scrollOffsetX: number;
    scrollOffsetY: number;
    timestamp?: number;
  };
  sessionId: number;
};

export type ScreencastOptions = {
  format?: "jpeg" | "png";
  quality?: number; // 0-100, default 80
  maxWidth?: number;
  maxHeight?: number;
  everyNthFrame?: number; // 1 = every frame
};

export type MouseEventType = "mousePressed" | "mouseReleased" | "mouseMoved" | "mouseWheel";
export type MouseButton = "none" | "left" | "middle" | "right" | "back" | "forward";

export type KeyEventType = "keyDown" | "keyUp" | "rawKeyDown" | "char";

export type ScreencastSession = {
  cdpUrl: string;
  targetId?: string;
  session: CDPSession;
  page: Page;
  streaming: boolean;
  frameCallback?: (frame: ScreencastFrame) => void;
};

const activeSessions = new Map<string, ScreencastSession>();

function sessionKey(cdpUrl: string, targetId?: string): string {
  return `${cdpUrl}::${targetId ?? "default"}`;
}

/**
 * Start screencast streaming for a page.
 * Frames are pushed via the callback as Chrome renders them.
 */
export async function startScreencast(opts: {
  cdpUrl: string;
  targetId?: string;
  options?: ScreencastOptions;
  onFrame: (frame: ScreencastFrame) => void;
}): Promise<{ sessionKey: string }> {
  const key = sessionKey(opts.cdpUrl, opts.targetId);

  // Stop existing session if any
  const existing = activeSessions.get(key);
  if (existing?.streaming) {
    await stopScreencast({ cdpUrl: opts.cdpUrl, targetId: opts.targetId });
  }

  log.info(`Getting page for targetId: ${opts.targetId}`);
  const page = await getPageForTargetId({
    cdpUrl: opts.cdpUrl,
    targetId: opts.targetId,
  });
  log.info(`Got page, URL: ${page.url()}`);

  log.info(`Creating CDP session for page`);
  const session = await page.context().newCDPSession(page);
  log.info(`CDP session created`);

  const screencastSession: ScreencastSession = {
    cdpUrl: opts.cdpUrl,
    targetId: opts.targetId,
    session,
    page,
    streaming: true,
    frameCallback: opts.onFrame,
  };

  activeSessions.set(key, screencastSession);

  // Listen for screencast frames
  let frameCount = 0;
  session.on("Page.screencastFrame", (params) => {
    frameCount++;
    const frame: ScreencastFrame = {
      data: params.data,
      metadata: params.metadata,
      sessionId: params.sessionId,
    };

    // Log first frame and then every 30th frame to avoid spam
    if (frameCount === 1 || frameCount % 30 === 0) {
      log.info(`Frame ${frameCount} received for ${key}, size=${params.data.length}`);
    }

    // Acknowledge frame receipt (required by CDP protocol)
    session.send("Page.screencastFrameAck", { sessionId: params.sessionId }).catch(() => {
      // Ignore ack errors
    });

    // Call the frame callback
    if (screencastSession.frameCallback) {
      if (frameCount === 1) {
        log.info(`Invoking frameCallback for first frame`);
      }
      screencastSession.frameCallback(frame);
    } else {
      if (frameCount === 1) {
        log.warn(`No frameCallback set for session ${key}`);
      }
    }
  });

  // Start the screencast
  const format = opts.options?.format ?? "jpeg";
  const quality = opts.options?.quality ?? 80;
  const maxWidth = opts.options?.maxWidth ?? 1920;
  const maxHeight = opts.options?.maxHeight ?? 1080;
  const everyNthFrame = opts.options?.everyNthFrame ?? 1;

  log.info(
    `Calling Page.startScreencast for ${key} with format=${format}, quality=${quality}, maxWidth=${maxWidth}, maxHeight=${maxHeight}, everyNthFrame=${everyNthFrame}`,
  );

  try {
    await session.send("Page.startScreencast", {
      format,
      quality,
      maxWidth,
      maxHeight,
      everyNthFrame,
    });
    log.info(`Page.startScreencast succeeded for ${key}`);
  } catch (err) {
    log.error(`Page.startScreencast failed for ${key}: ${err}`);
    throw err;
  }

  log.info(`Screencast started for ${key} (${format} @ ${quality}%)`);

  return { sessionKey: key };
}

/**
 * Stop screencast streaming for a page.
 */
export async function stopScreencast(opts: { cdpUrl: string; targetId?: string }): Promise<void> {
  const key = sessionKey(opts.cdpUrl, opts.targetId);
  const existing = activeSessions.get(key);

  if (!existing) {
    return;
  }

  existing.streaming = false;
  existing.frameCallback = undefined;

  try {
    await existing.session.send("Page.stopScreencast");
    await existing.session.detach();
  } catch {
    // Ignore cleanup errors
  }

  activeSessions.delete(key);
  log.info(`Screencast stopped for ${key}`);
}

/**
 * Navigate an existing tab to a new URL.
 * Preserves the screencast session and continues streaming.
 */
export async function navigateTab(opts: {
  cdpUrl: string;
  targetId?: string;
  url: string;
}): Promise<void> {
  const key = sessionKey(opts.cdpUrl, opts.targetId);
  const existing = activeSessions.get(key);

  if (!existing) {
    throw new Error(`No active session for ${key}`);
  }

  log.info(`Navigating tab ${key} to ${opts.url}`);

  // Use CDP Page.navigate to navigate without creating a new page
  await existing.session.send("Page.navigate", { url: opts.url });

  // Wait for the page to load
  await existing.page.waitForLoadState("domcontentloaded").catch(() => {
    // Ignore timeout - page may still be loading
    log.warn(`Page load timeout for ${opts.url}, continuing anyway`);
  });
}

/**
 * Dispatch a mouse event directly to the Chromium renderer.
 * This is renderer-scoped (like Atlas), not OS-level.
 */
export async function dispatchMouseEvent(opts: {
  cdpUrl: string;
  targetId?: string;
  type: MouseEventType;
  x: number;
  y: number;
  button?: MouseButton;
  clickCount?: number;
  deltaX?: number; // For mouseWheel
  deltaY?: number; // For mouseWheel
  modifiers?: number; // Bitmask: 1=Alt, 2=Ctrl, 4=Meta, 8=Shift
}): Promise<void> {
  const key = sessionKey(opts.cdpUrl, opts.targetId);
  let existing = activeSessions.get(key);

  // Create a temporary session if no screencast is active
  if (!existing) {
    const page = await getPageForTargetId({
      cdpUrl: opts.cdpUrl,
      targetId: opts.targetId,
    });
    const session = await page.context().newCDPSession(page);
    existing = {
      cdpUrl: opts.cdpUrl,
      targetId: opts.targetId,
      session,
      page,
      streaming: false,
    };
    // Don't store it - it's temporary
  }

  // Build params with required fields, then add optional ones
  const params = {
    type: opts.type,
    x: opts.x,
    y: opts.y,
    ...(opts.button && opts.button !== "none" ? { button: opts.button } : {}),
    ...(opts.clickCount !== undefined ? { clickCount: opts.clickCount } : {}),
    ...(opts.type === "mouseWheel" ? { deltaX: opts.deltaX ?? 0, deltaY: opts.deltaY ?? 0 } : {}),
    ...(opts.modifiers !== undefined ? { modifiers: opts.modifiers } : {}),
  };

  await existing.session.send("Input.dispatchMouseEvent", params);
}

/**
 * Dispatch a keyboard event directly to the Chromium renderer.
 * This is renderer-scoped (like Atlas), not OS-level.
 */
export async function dispatchKeyEvent(opts: {
  cdpUrl: string;
  targetId?: string;
  type: KeyEventType;
  key?: string; // Key value (e.g., "a", "Enter", "Backspace")
  code?: string; // Physical key code (e.g., "KeyA", "Enter")
  text?: string; // Text to insert (for 'char' type)
  modifiers?: number; // Bitmask: 1=Alt, 2=Ctrl, 4=Meta, 8=Shift
  windowsVirtualKeyCode?: number;
  nativeVirtualKeyCode?: number;
}): Promise<void> {
  const key = sessionKey(opts.cdpUrl, opts.targetId);
  let existing = activeSessions.get(key);

  // Create a temporary session if no screencast is active
  if (!existing) {
    const page = await getPageForTargetId({
      cdpUrl: opts.cdpUrl,
      targetId: opts.targetId,
    });
    const session = await page.context().newCDPSession(page);
    existing = {
      cdpUrl: opts.cdpUrl,
      targetId: opts.targetId,
      session,
      page,
      streaming: false,
    };
  }

  // Build params with required fields, then add optional ones
  const params = {
    type: opts.type,
    ...(opts.key ? { key: opts.key } : {}),
    ...(opts.code ? { code: opts.code } : {}),
    ...(opts.text ? { text: opts.text } : {}),
    ...(opts.modifiers !== undefined ? { modifiers: opts.modifiers } : {}),
    ...(opts.windowsVirtualKeyCode !== undefined
      ? { windowsVirtualKeyCode: opts.windowsVirtualKeyCode }
      : {}),
    ...(opts.nativeVirtualKeyCode !== undefined
      ? { nativeVirtualKeyCode: opts.nativeVirtualKeyCode }
      : {}),
  };

  await existing.session.send("Input.dispatchKeyEvent", params);
}

/**
 * Helper to send a click at coordinates.
 * Dispatches mousePressed + mouseReleased (like a real click).
 */
export async function sendClick(opts: {
  cdpUrl: string;
  targetId?: string;
  x: number;
  y: number;
  button?: MouseButton;
  clickCount?: number;
  modifiers?: number;
}): Promise<void> {
  const button = opts.button ?? "left";
  const clickCount = opts.clickCount ?? 1;

  await dispatchMouseEvent({
    ...opts,
    type: "mousePressed",
    button,
    clickCount,
  });

  await dispatchMouseEvent({
    ...opts,
    type: "mouseReleased",
    button,
    clickCount,
  });
}

/**
 * Helper to type text character by character.
 */
export async function sendText(opts: {
  cdpUrl: string;
  targetId?: string;
  text: string;
  delayMs?: number;
}): Promise<void> {
  const delay = opts.delayMs ?? 50;

  for (const char of opts.text) {
    await dispatchKeyEvent({
      cdpUrl: opts.cdpUrl,
      targetId: opts.targetId,
      type: "char",
      text: char,
    });

    if (delay > 0) {
      await new Promise((r) => setTimeout(r, delay));
    }
  }
}

/**
 * Helper to press a special key (Enter, Tab, Escape, etc.).
 */
export async function sendKey(opts: {
  cdpUrl: string;
  targetId?: string;
  key: string;
  modifiers?: number;
}): Promise<void> {
  await dispatchKeyEvent({
    cdpUrl: opts.cdpUrl,
    targetId: opts.targetId,
    type: "keyDown",
    key: opts.key,
    modifiers: opts.modifiers,
  });

  await dispatchKeyEvent({
    cdpUrl: opts.cdpUrl,
    targetId: opts.targetId,
    type: "keyUp",
    key: opts.key,
    modifiers: opts.modifiers,
  });
}

/**
 * Get current screencast session info.
 */
export function getScreencastSession(opts: {
  cdpUrl: string;
  targetId?: string;
}): ScreencastSession | undefined {
  const key = sessionKey(opts.cdpUrl, opts.targetId);
  return activeSessions.get(key);
}

/**
 * Stop all active screencast sessions.
 */
export async function stopAllScreencasts(): Promise<void> {
  const keys = Array.from(activeSessions.keys());
  for (const key of keys) {
    const session = activeSessions.get(key);
    if (session) {
      await stopScreencast({ cdpUrl: session.cdpUrl, targetId: session.targetId });
    }
  }
}
