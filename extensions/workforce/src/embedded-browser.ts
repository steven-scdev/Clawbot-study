/**
 * Embedded Browser Streaming for Workforce Extension.
 *
 * Uses CDP Screencast to stream Chromium frames to the macOS app's preview panel.
 * This is the Atlas/OWL-inspired architecture where:
 * - Chromium runs as an isolated process (via Playwright)
 * - Frames are streamed via CDP Page.screencastFrame
 * - Input is injected via CDP Input.dispatch* (renderer-scoped, not OS-level)
 */

type ScreencastFrame = {
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

type ScreencastOptions = {
  format?: "jpeg" | "png";
  quality?: number;
  maxWidth?: number;
  maxHeight?: number;
  everyNthFrame?: number;
};

type EmbeddedSession = {
  taskId: string;
  cdpUrl: string;
  targetId: string;
  screencastKey: string;
  url: string;
  streaming: boolean;
};

// Active embedded browser sessions by taskId
const activeSessions = new Map<string, EmbeddedSession>();

// Dynamically imported modules (lazy loaded)
let cdpScreencastModule: typeof import("../../../src/browser/cdp-screencast.js") | null = null;
let browserControlModule: typeof import("../../../src/browser/control-service.js") | null = null;

// Shared broadcast function reference (set by caller, used for frame broadcasting)
let sharedBroadcastFn: ((event: string, payload: unknown) => void) | null = null;

/**
 * Update the shared broadcast function.
 * Called from index.ts to keep the broadcast function current.
 */
export function setEmbeddedBroadcast(broadcast: (event: string, payload: unknown) => void): void {
  sharedBroadcastFn = broadcast;
}

async function loadModules() {
  if (!cdpScreencastModule) {
    cdpScreencastModule = await import("../../../src/browser/cdp-screencast.js");
  }
  if (!browserControlModule) {
    browserControlModule = await import("../../../src/browser/control-service.js");
  }
  return { cdpScreencast: cdpScreencastModule, browserControl: browserControlModule };
}

/**
 * Start embedded browser streaming for a task.
 * Returns the session info.
 *
 * If a session already exists for this task:
 * - Same URL: Returns existing session (no-op)
 * - Different URL: Navigates existing tab to new URL (preserves session)
 */
export async function startEmbeddedBrowser(opts: {
  taskId: string;
  url: string;
  broadcast: (event: string, payload: unknown) => void;
  screencastOptions?: ScreencastOptions;
}): Promise<EmbeddedSession> {
  const { cdpScreencast, browserControl } = await loadModules();

  // Check for existing session
  const existing = activeSessions.get(opts.taskId);
  if (existing?.streaming) {
    // If same URL, just return existing session
    if (existing.url === opts.url) {
      console.log(`[embedded-browser] Reusing existing session for task ${opts.taskId}, same URL`);
      return existing;
    }

    // Different URL - navigate existing tab instead of creating new one
    console.log(`[embedded-browser] Navigating existing session for task ${opts.taskId} to new URL: ${opts.url}`);
    try {
      await cdpScreencast.navigateTab({
        cdpUrl: existing.cdpUrl,
        targetId: existing.targetId,
        url: opts.url,
      });
      existing.url = opts.url;
      return existing;
    } catch (err) {
      // If navigation fails, fall through to create new session
      console.warn(`[embedded-browser] Navigation failed, creating new session: ${err}`);
      await stopEmbeddedBrowser({ taskId: opts.taskId });
    }
  }

  // Ensure browser is available
  const state = await browserControl.startBrowserControlServiceFromConfig();
  if (!state) {
    throw new Error("Browser control is disabled");
  }

  // Get the browser context and ensure browser is running
  // Use "openclaw" profile explicitly for Playwright-managed browser (not Chrome extension)
  const ctx = browserControl.createBrowserControlContext();
  const profileCtx = ctx.forProfile("openclaw");
  await profileCtx.ensureBrowserAvailable();

  // Open a new tab with the URL
  const tab = await profileCtx.openTab(opts.url);
  const cdpUrl = profileCtx.profile.cdpUrl;

  console.log(`[embedded-browser] Created new session for task ${opts.taskId}, targetId: ${tab.targetId}`);

  // Start screencast streaming
  const { sessionKey } = await cdpScreencast.startScreencast({
    cdpUrl,
    targetId: tab.targetId,
    options: {
      format: opts.screencastOptions?.format ?? "jpeg",
      quality: opts.screencastOptions?.quality ?? 80,
      maxWidth: opts.screencastOptions?.maxWidth ?? 1280,
      maxHeight: opts.screencastOptions?.maxHeight ?? 720,
      everyNthFrame: opts.screencastOptions?.everyNthFrame ?? 2, // Every 2nd frame for lower bandwidth
    },
    onFrame: (frame: ScreencastFrame) => {
      // Log every 30th frame to confirm callback is being invoked
      const frameNum = Math.random() < 0.033 ? 1 : 0; // ~1 in 30
      if (frameNum === 1) {
        console.log(`[embedded-browser] onFrame callback invoked for task ${opts.taskId}, dataSize=${frame.data.length}`);
      }

      // Use the shared broadcast function (kept current by index.ts)
      // This ensures frames are broadcast even after the initial request completes
      const broadcast = sharedBroadcastFn ?? opts.broadcast;
      if (!broadcast) {
        console.warn(`[embedded-browser] No broadcast function available for frame`);
        return;
      }

      try {
        broadcast("workforce.embedded.frame", {
          taskId: opts.taskId,
          frame: {
            data: frame.data,
            metadata: frame.metadata,
          },
        });
      } catch (err) {
        console.error(`[embedded-browser] broadcast failed: ${err}`);
      }
    },
  });

  const session: EmbeddedSession = {
    taskId: opts.taskId,
    cdpUrl,
    targetId: tab.targetId,
    screencastKey: sessionKey,
    url: opts.url,
    streaming: true,
  };

  activeSessions.set(opts.taskId, session);

  return session;
}

/**
 * Stop embedded browser streaming for a task.
 */
export async function stopEmbeddedBrowser(opts: { taskId: string }): Promise<void> {
  const session = activeSessions.get(opts.taskId);
  if (!session) {
    return;
  }

  const { cdpScreencast } = await loadModules();

  session.streaming = false;
  await cdpScreencast.stopScreencast({
    cdpUrl: session.cdpUrl,
    targetId: session.targetId,
  });

  activeSessions.delete(opts.taskId);
}

/**
 * Dispatch a mouse event to the embedded browser.
 */
export async function dispatchMouseEvent(opts: {
  taskId: string;
  type: "mousePressed" | "mouseReleased" | "mouseMoved" | "mouseWheel";
  x: number;
  y: number;
  button?: "none" | "left" | "middle" | "right";
  clickCount?: number;
  deltaX?: number;
  deltaY?: number;
  modifiers?: number;
}): Promise<void> {
  const session = activeSessions.get(opts.taskId);
  if (!session) {
    throw new Error(`No embedded browser session for task: ${opts.taskId}`);
  }

  const { cdpScreencast } = await loadModules();

  await cdpScreencast.dispatchMouseEvent({
    cdpUrl: session.cdpUrl,
    targetId: session.targetId,
    type: opts.type,
    x: opts.x,
    y: opts.y,
    button: opts.button,
    clickCount: opts.clickCount,
    deltaX: opts.deltaX,
    deltaY: opts.deltaY,
    modifiers: opts.modifiers,
  });
}

/**
 * Dispatch a keyboard event to the embedded browser.
 */
export async function dispatchKeyEvent(opts: {
  taskId: string;
  type: "keyDown" | "keyUp" | "char";
  key?: string;
  code?: string;
  text?: string;
  modifiers?: number;
}): Promise<void> {
  const session = activeSessions.get(opts.taskId);
  if (!session) {
    throw new Error(`No embedded browser session for task: ${opts.taskId}`);
  }

  const { cdpScreencast } = await loadModules();

  await cdpScreencast.dispatchKeyEvent({
    cdpUrl: session.cdpUrl,
    targetId: session.targetId,
    type: opts.type,
    key: opts.key,
    code: opts.code,
    text: opts.text,
    modifiers: opts.modifiers,
  });
}

/**
 * Get the current embedded session for a task.
 */
export function getEmbeddedSession(taskId: string): EmbeddedSession | undefined {
  return activeSessions.get(taskId);
}

/**
 * Stop all embedded browser sessions.
 */
export async function stopAllEmbeddedSessions(): Promise<void> {
  const taskIds = Array.from(activeSessions.keys());
  for (const taskId of taskIds) {
    await stopEmbeddedBrowser({ taskId });
  }
}

/**
 * Capture a screenshot of the embedded browser via CDP.
 * Returns base64-encoded image data.
 *
 * Uses JPEG format by default with low quality to minimize token usage.
 * A 1280x720 PNG at quality 90 can be 500KB-1MB (150K-300K tokens).
 * JPEG at quality 40 is typically 30-50KB (~10K-15K tokens).
 */
export async function captureScreenshot(opts: {
  taskId: string;
  format?: "jpeg" | "png";
  quality?: number;
}): Promise<string> {
  const session = activeSessions.get(opts.taskId);
  if (!session) {
    throw new Error(`No embedded browser session for task: ${opts.taskId}`);
  }

  const { cdpScreencast } = await loadModules();
  const screencastSession = cdpScreencast.getScreencastSession({
    cdpUrl: session.cdpUrl,
    targetId: session.targetId,
  });

  if (!screencastSession) {
    throw new Error(`No screencast session for task: ${opts.taskId}`);
  }

  // Use CDP Page.captureScreenshot with optimized settings for token efficiency
  const result = await screencastSession.session.send("Page.captureScreenshot", {
    format: opts.format ?? "jpeg", // JPEG is much smaller than PNG
    quality: opts.quality ?? 40, // Lower quality = smaller file, still readable
  });

  return result.data;
}

/**
 * Evaluate JavaScript in the embedded browser via CDP.
 * Returns the result of the evaluation.
 */
export async function evaluateScript(opts: {
  taskId: string;
  script: string;
}): Promise<unknown> {
  const session = activeSessions.get(opts.taskId);
  if (!session) {
    throw new Error(`No embedded browser session for task: ${opts.taskId}`);
  }

  const { cdpScreencast } = await loadModules();
  const screencastSession = cdpScreencast.getScreencastSession({
    cdpUrl: session.cdpUrl,
    targetId: session.targetId,
  });

  if (!screencastSession) {
    throw new Error(`No screencast session for task: ${opts.taskId}`);
  }

  // Use CDP Runtime.evaluate
  const result = await screencastSession.session.send("Runtime.evaluate", {
    expression: opts.script,
    returnByValue: true,
    awaitPromise: true,
  });

  if (result.exceptionDetails) {
    // Extract more detailed error information
    const exception = result.exceptionDetails;
    const errorText = exception.text || "Unknown error";
    const errorDescription = exception.exception?.description || "";
    const lineNumber = exception.lineNumber ?? "";
    const columnNumber = exception.columnNumber ?? "";

    let fullError = `Script evaluation error: ${errorText}`;
    if (errorDescription) {
      fullError += ` - ${errorDescription}`;
    }
    if (lineNumber !== "") {
      fullError += ` at line ${lineNumber}:${columnNumber}`;
    }

    throw new Error(fullError);
  }

  return result.result?.value;
}

/**
 * Get page information (URL, title, simplified DOM) from the embedded browser via CDP.
 * Returns a simplified representation to avoid token overflow.
 *
 * Default maxDomLength is 15KB (~4K tokens) to stay well under token limits.
 * The DOM includes only interactive elements with their bounds for clicking.
 */
export async function getPageInfo(opts: { taskId: string; maxDomLength?: number }): Promise<{
  url: string;
  title: string;
  dom?: string;
}> {
  const session = activeSessions.get(opts.taskId);
  if (!session) {
    throw new Error(`No embedded browser session for task: ${opts.taskId}`);
  }

  const { cdpScreencast } = await loadModules();
  const screencastSession = cdpScreencast.getScreencastSession({
    cdpUrl: session.cdpUrl,
    targetId: session.targetId,
  });

  if (!screencastSession) {
    throw new Error(`No screencast session for task: ${opts.taskId}`);
  }

  // Get page URL and title via Runtime.evaluate
  const urlResult = await screencastSession.session.send("Runtime.evaluate", {
    expression: "window.location.href",
    returnByValue: true,
  });

  const titleResult = await screencastSession.session.send("Runtime.evaluate", {
    expression: "document.title",
    returnByValue: true,
  });

  // Get simplified DOM structure - extract interactive elements and visible text
  // This is much smaller than full HTML and more useful for agents
  const simplifiedDomScript = `
    (function() {
      const maxLength = ${opts.maxDomLength || 15000};
      const elements = [];

      // Get all interactive and semantic elements
      const selectors = [
        'a[href]', 'button', 'input', 'select', 'textarea',
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        '[role="button"]', '[role="link"]', '[role="textbox"]',
        '[role="checkbox"]', '[role="radio"]', '[role="menuitem"]',
        '[aria-label]', '[data-testid]',
        'label', 'nav', 'main', 'article', 'section'
      ];

      const seen = new Set();
      for (const selector of selectors) {
        const nodes = document.querySelectorAll(selector);
        for (const node of nodes) {
          if (seen.has(node)) continue;
          seen.add(node);

          const rect = node.getBoundingClientRect();
          // Skip invisible elements
          if (rect.width === 0 || rect.height === 0) continue;

          const tag = node.tagName.toLowerCase();
          const text = (node.innerText || node.value || '').trim().substring(0, 100);
          const attrs = [];

          if (node.id) attrs.push('id="' + node.id + '"');
          if (node.className && typeof node.className === 'string') {
            attrs.push('class="' + node.className.split(' ').slice(0, 3).join(' ') + '"');
          }
          if (node.name) attrs.push('name="' + node.name + '"');
          if (node.type) attrs.push('type="' + node.type + '"');
          if (node.href) attrs.push('href="' + node.href.substring(0, 100) + '"');
          if (node.placeholder) attrs.push('placeholder="' + node.placeholder + '"');
          if (node.ariaLabel) attrs.push('aria-label="' + node.ariaLabel + '"');
          if (node.dataset.testid) attrs.push('data-testid="' + node.dataset.testid + '"');

          const attrStr = attrs.length ? ' ' + attrs.join(' ') : '';
          const bounds = '[' + Math.round(rect.x) + ',' + Math.round(rect.y) + ',' + Math.round(rect.width) + ',' + Math.round(rect.height) + ']';

          if (text) {
            elements.push('<' + tag + attrStr + ' bounds=' + bounds + '>' + text + '</' + tag + '>');
          } else {
            elements.push('<' + tag + attrStr + ' bounds=' + bounds + '/>');
          }
        }
      }

      let result = elements.join('\\n');
      if (result.length > maxLength) {
        result = result.substring(0, maxLength) + '\\n... (truncated)';
      }
      return result;
    })()
  `;

  const domResult = await screencastSession.session.send("Runtime.evaluate", {
    expression: simplifiedDomScript,
    returnByValue: true,
  });

  return {
    url: urlResult.result?.value as string || session.url,
    title: titleResult.result?.value as string || "",
    dom: domResult.result?.value as string,
  };
}
