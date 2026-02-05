import { Type } from "@sinclair/typebox";
import { stringEnum } from "../schema/typebox.js";
import { type AnyAgentTool, jsonResult, readStringParam } from "./common.js";
import { callGatewayTool, type GatewayCallOptions } from "./gateway.js";

const PREVIEW_ACTIONS = ["present", "refresh"] as const;

const PreviewToolSchema = Type.Object({
  action: stringEnum(PREVIEW_ACTIONS),
  // Gateway connection (optional - defaults to local gateway)
  gatewayUrl: Type.Optional(Type.String()),
  gatewayToken: Type.Optional(Type.String()),
  timeoutMs: Type.Optional(Type.Number()),
  // Task context (provide taskId or sessionKey - sessionKey is auto-resolved)
  taskId: Type.Optional(Type.String()),
  sessionKey: Type.Optional(Type.String()),
  // present action
  path: Type.Optional(Type.String()),
  title: Type.Optional(Type.String()),
});

/**
 * Creates a preview tool for Workforce AI employees.
 *
 * The preview tool allows agents to explicitly present outputs to users
 * in the Workforce app's preview panel. This gives agents control over
 * what the user sees, rather than relying on passive regex-based detection.
 *
 * Actions:
 * - present: Show a file or URL in the preview panel
 * - refresh: Reload the currently displayed content
 */
export function createPreviewTool(opts?: { taskId?: string; sessionKey?: string }): AnyAgentTool {
  return {
    label: "Preview",
    name: "preview",
    description:
      "Present outputs to the user in the Workforce app preview panel. Use 'present' to show a file or URL after creating/updating it. Use 'refresh' to reload the current view after making changes to an already-displayed file.",
    parameters: PreviewToolSchema,
    execute: async (_toolCallId, args) => {
      const params = args as Record<string, unknown>;
      const action = readStringParam(params, "action", { required: true });

      const gatewayOpts: GatewayCallOptions = {
        gatewayUrl: readStringParam(params, "gatewayUrl", { trim: false }),
        gatewayToken: readStringParam(params, "gatewayToken", { trim: false }),
        timeoutMs: typeof params.timeoutMs === "number" ? params.timeoutMs : undefined,
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
        case "present": {
          const path = readStringParam(params, "path", { required: true });
          const title = readStringParam(params, "title");

          // Determine if it's a URL or file path
          const isUrl = path.startsWith("http://") || path.startsWith("https://");

          const result = await callGatewayTool("workforce.output.present", gatewayOpts, {
            taskId,
            sessionKey,
            filePath: isUrl ? undefined : path,
            url: isUrl ? path : undefined,
            title,
          });

          return jsonResult({
            ok: true,
            message: `Presented ${title ?? path} in preview panel`,
            result,
          });
        }

        case "refresh": {
          const result = await callGatewayTool("workforce.output.refresh", gatewayOpts, {
            taskId,
            sessionKey,
          });

          return jsonResult({
            ok: true,
            message: "Preview panel refreshed",
            result,
          });
        }

        default:
          throw new Error(`Unknown action: ${action}`);
      }
    },
  };
}
