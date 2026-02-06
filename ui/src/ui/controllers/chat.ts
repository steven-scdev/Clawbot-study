import type { GatewayBrowserClient } from "../gateway";
import type { ChatAttachment } from "../ui-types";
import { extractText } from "../chat/message-extract";
import { generateUUID } from "../uuid";

export type ChatState = {
  client: GatewayBrowserClient | null;
  connected: boolean;
  sessionKey: string;
  chatLoading: boolean;
  chatMessages: unknown[];
  chatThinkingLevel: string | null;
  chatSending: boolean;
  chatMessage: string;
  chatAttachments: ChatAttachment[];
  chatRunId: string | null;
  chatStream: string | null;
  chatStreamStartedAt: number | null;
  lastError: string | null;
};

export type ChatEventPayload = {
  runId: string;
  sessionKey: string;
  state: "delta" | "final" | "aborted" | "error";
  message?: unknown;
  errorMessage?: string;
};

export async function loadChatHistory(state: ChatState) {
  if (!state.client || !state.connected) return;
  state.chatLoading = true;
  state.lastError = null;
  try {
    const res = (await state.client.request("chat.history", {
      sessionKey: state.sessionKey,
      limit: 200,
    })) as { messages?: unknown[]; thinkingLevel?: string | null };
    state.chatMessages = Array.isArray(res.messages) ? res.messages : [];
    state.chatThinkingLevel = res.thinkingLevel ?? null;
  } catch (err) {
    state.lastError = String(err);
  } finally {
    state.chatLoading = false;
  }
}

function dataUrlToBase64(dataUrl: string): { content: string; mimeType: string } | null {
  const match = /^data:([^;]+);base64,(.+)$/.exec(dataUrl);
  if (!match) return null;
  return { mimeType: match[1], content: match[2] };
}

function isImageMimeType(mimeType: string): boolean {
  return mimeType.startsWith("image/");
}

function isTextBasedDocument(mimeType: string): boolean {
  const textTypes = [
    "text/plain",
    "text/markdown",
    "text/csv",
    "application/json",
    "application/xml",
    "text/xml",
    "text/html",
  ];
  return textTypes.includes(mimeType);
}

function base64ToText(base64: string): string {
  try {
    return decodeURIComponent(escape(atob(base64)));
  } catch {
    // Fallback for non-UTF8 encoded content
    return atob(base64);
  }
}

export async function sendChatMessage(
  state: ChatState,
  message: string,
  attachments?: ChatAttachment[],
): Promise<string | null> {
  if (!state.client || !state.connected) return null;
  const msg = message.trim();
  const hasAttachments = attachments && attachments.length > 0;
  if (!msg && !hasAttachments) return null;

  const now = Date.now();

  // Build user message content blocks
  const contentBlocks: Array<{ type: string; text?: string; source?: unknown }> = [];
  if (msg) {
    contentBlocks.push({ type: "text", text: msg });
  }
  // Add attachment previews to the message for display
  if (hasAttachments) {
    for (const att of attachments) {
      if (isImageMimeType(att.mimeType)) {
        contentBlocks.push({
          type: "image",
          source: { type: "base64", media_type: att.mimeType, data: att.dataUrl },
        });
      } else {
        // For documents, show filename in the message
        const filename = att.filename ?? "document";
        contentBlocks.push({
          type: "text",
          text: `📎 ${filename}`,
        });
      }
    }
  }

  state.chatMessages = [
    ...state.chatMessages,
    {
      role: "user",
      content: contentBlocks,
      timestamp: now,
    },
  ];

  state.chatSending = true;
  state.lastError = null;
  const runId = generateUUID();
  state.chatRunId = runId;
  state.chatStream = "";
  state.chatStreamStartedAt = now;

  // Build the final message with document content embedded
  let finalMessage = msg;
  const imageAttachments: Array<{ type: string; mimeType: string; content: string }> = [];
  const documentAttachments: Array<{ type: string; mimeType: string; content: string; filename?: string }> = [];

  if (hasAttachments) {
    for (const att of attachments) {
      const parsed = dataUrlToBase64(att.dataUrl);
      if (!parsed) continue;

      if (isImageMimeType(att.mimeType)) {
        // Images are sent as attachments
        imageAttachments.push({
          type: "image",
          mimeType: parsed.mimeType,
          content: parsed.content,
        });
      } else if (isTextBasedDocument(att.mimeType)) {
        // Text documents: decode and append to message
        const textContent = base64ToText(parsed.content);
        const filename = att.filename ?? "document";
        const separator = finalMessage ? "\n\n" : "";
        finalMessage += `${separator}--- Document: ${filename} ---\n${textContent}`;
      } else {
        // Binary documents (PDF, Word, Excel): send as document attachment
        documentAttachments.push({
          type: "document",
          mimeType: parsed.mimeType,
          content: parsed.content,
          filename: att.filename,
        });
      }
    }
  }

  // Combine all attachments
  const apiAttachments = [...imageAttachments, ...documentAttachments];

  try {
    await state.client.request("chat.send", {
      sessionKey: state.sessionKey,
      message: finalMessage,
      deliver: false,
      idempotencyKey: runId,
      attachments: apiAttachments.length > 0 ? apiAttachments : undefined,
    });
    return runId;
  } catch (err) {
    const error = String(err);
    state.chatRunId = null;
    state.chatStream = null;
    state.chatStreamStartedAt = null;
    state.lastError = error;
    state.chatMessages = [
      ...state.chatMessages,
      {
        role: "assistant",
        content: [{ type: "text", text: "Error: " + error }],
        timestamp: Date.now(),
      },
    ];
    return null;
  } finally {
    state.chatSending = false;
  }
}

export async function abortChatRun(state: ChatState): Promise<boolean> {
  if (!state.client || !state.connected) return false;
  const runId = state.chatRunId;
  try {
    await state.client.request(
      "chat.abort",
      runId ? { sessionKey: state.sessionKey, runId } : { sessionKey: state.sessionKey },
    );
    return true;
  } catch (err) {
    state.lastError = String(err);
    return false;
  }
}

export function handleChatEvent(state: ChatState, payload?: ChatEventPayload) {
  if (!payload) return null;
  if (payload.sessionKey !== state.sessionKey) return null;

  // Final from another run (e.g. sub-agent announce): refresh history to show new message.
  // See https://github.com/openclaw/openclaw/issues/1909
  if (payload.runId && state.chatRunId && payload.runId !== state.chatRunId) {
    if (payload.state === "final") return "final";
    return null;
  }

  if (payload.state === "delta") {
    const next = extractText(payload.message);
    if (typeof next === "string") {
      const current = state.chatStream ?? "";
      if (!current || next.length >= current.length) {
        state.chatStream = next;
      }
    }
  } else if (payload.state === "final") {
    state.chatStream = null;
    state.chatRunId = null;
    state.chatStreamStartedAt = null;
  } else if (payload.state === "aborted") {
    state.chatStream = null;
    state.chatRunId = null;
    state.chatStreamStartedAt = null;
  } else if (payload.state === "error") {
    state.chatStream = null;
    state.chatRunId = null;
    state.chatStreamStartedAt = null;
    state.lastError = payload.errorMessage ?? "chat error";
  }
  return payload.state;
}
