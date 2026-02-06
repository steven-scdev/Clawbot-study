import { Type } from "@sinclair/typebox";
import { stringEnum } from "../schema/typebox.js";
import { type AnyAgentTool, jsonResult, readStringParam } from "./common.js";
import { callGatewayTool, type GatewayCallOptions } from "./gateway.js";

const BROWSER_ACTIONS = ["execute", "observe", "navigate"] as const;

const BrowserToolSchema = Type.Object({
  action: stringEnum(BROWSER_ACTIONS),
  // Gateway connection (optional - defaults to local gateway)
  gatewayUrl: Type.Optional(Type.String()),
  gatewayToken: Type.Optional(Type.String()),
  timeoutMs: Type.Optional(Type.Number()),
  // Task context (provide taskId or sessionKey - sessionKey is auto-resolved)
  taskId: Type.Optional(Type.String()),
  sessionKey: Type.Optional(Type.String()),
  // execute action
  script: Type.Optional(Type.String()),
  // navigate action
  url: Type.Optional(Type.String()),
});

/**
 * Creates a browser control tool for Workforce AI employees.
 *
 * This tool gives agents FULL JavaScript execution capability in the preview
 * panel's WebView. Instead of predefined actions (click, type, scroll), it
 * provides three foundational primitives ("meta-keys") that allow agents to
 * do anything possible in a browser:
 *
 * Actions:
 * - execute: Run arbitrary JavaScript in the WebView and return the result
 * - observe: Capture current state (DOM + screenshot + URL + title)
 * - navigate: Load a URL in the WebView
 *
 * @example
 * // Click a button
 * browser({ action: "execute", script: "document.querySelector('button').click()" })
 *
 * // Fill a form field
 * browser({ action: "execute", script: "document.querySelector('input[name=email]').value = 'test@example.com'" })
 *
 * // Get page state
 * browser({ action: "observe" }) // Returns { dom, screenshot, url, title }
 *
 * // Navigate to a URL
 * browser({ action: "navigate", url: "https://example.com" })
 */
export function createWorkforceBrowserTool(opts?: {
  taskId?: string;
  sessionKey?: string;
}): AnyAgentTool {
  return {
    label: "WebView",
    name: "webview",
    description: `Control the app's preview panel WebView with full JavaScript execution capability. This is the embedded browser in the Workforce app - use this instead of external browser tools.

Actions:
- execute: Run arbitrary JavaScript in the WebView. Pass 'script' parameter with JavaScript code.
- observe: Capture current state. Returns { dom, screenshot (base64 PNG), url, title }.
- navigate: Load a URL. Pass 'url' parameter.

Examples:
- Click: webview(action="execute", script="document.querySelector('button').click()")
- Fill form: webview(action="execute", script="document.querySelector('input').value = 'text'")
- Get DOM: webview(action="observe")
- Go to page: webview(action="navigate", url="https://example.com")

Use this tool for browser automation within the Workforce app. No Chrome extension needed.`,
    parameters: BrowserToolSchema,
    execute: async (_toolCallId, args) => {
      const params = args as Record<string, unknown>;
      const action = readStringParam(params, "action", { required: true });

      const gatewayOpts: GatewayCallOptions = {
        gatewayUrl: readStringParam(params, "gatewayUrl", { trim: false }),
        gatewayToken: readStringParam(params, "gatewayToken", { trim: false }),
        // Browser operations can be slow, use longer timeout
        timeoutMs: typeof params.timeoutMs === "number" ? params.timeoutMs : 30000,
      };

      // Use provided taskId/sessionKey or fall back to ones from tool creation context
      const taskId = readStringParam(params, "taskId") ?? opts?.taskId;
      const sessionKey = readStringParam(params, "sessionKey") ?? opts?.sessionKey;

      if (!taskId && !sessionKey) {
        throw new Error(
          "taskId or sessionKey is required - either provide in params or via tool context",
        );
      }

      switch (action) {
        case "execute": {
          const script = readStringParam(params, "script", { required: true });

          const result = await callGatewayTool("workforce.browser.execute", gatewayOpts, {
            taskId,
            sessionKey,
            script,
          });

          return jsonResult({
            ok: true,
            message: "JavaScript executed successfully",
            result,
          });
        }

        case "observe": {
          const result = await callGatewayTool("workforce.browser.observe", gatewayOpts, {
            taskId,
            sessionKey,
          });

          // The result contains { dom, screenshot, url, title }
          return jsonResult({
            ok: true,
            message: "Browser state captured",
            ...((result as Record<string, unknown>) ?? {}),
          });
        }

        case "navigate": {
          const url = readStringParam(params, "url", { required: true });

          const result = await callGatewayTool("workforce.browser.navigate", gatewayOpts, {
            taskId,
            sessionKey,
            url,
          });

          return jsonResult({
            ok: true,
            message: `Navigated to ${url}`,
            result,
          });
        }

        default:
          throw new Error(`Unknown action: ${action}`);
      }
    },
  };
}
