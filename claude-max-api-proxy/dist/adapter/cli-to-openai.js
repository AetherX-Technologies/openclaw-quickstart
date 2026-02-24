/**
 * Converts Claude CLI output to OpenAI-compatible response format
 */
/**
 * Parse <tool_call>...</tool_call> blocks from text.
 * Returns { toolCalls, remainingText }
 */
function parseToolCalls(text) {
    const toolCalls = [];
    const regex = /<tool_call>\s*([\s\S]*?)\s*<\/tool_call>/g;
    let match;
    let remainingText = text;
    let idx = 0;
    while ((match = regex.exec(text)) !== null) {
        try {
            const parsed = JSON.parse(match[1]);
            toolCalls.push({
                id: `call_${Date.now()}_${idx++}`,
                type: "function",
                function: {
                    name: parsed.name,
                    arguments: JSON.stringify(parsed.arguments ?? {}),
                },
            });
        } catch {
            // malformed tool_call block — ignore
        }
    }
    if (toolCalls.length > 0) {
        remainingText = text.replace(/<tool_call>[\s\S]*?<\/tool_call>/g, "").trim();
    }
    return { toolCalls, remainingText };
}
/**
 * Extract text content from Claude CLI assistant message
 */
export function extractTextContent(message) {
    return message.message.content
        .filter((c) => c.type === "text")
        .map((c) => c.text)
        .join("");
}
/**
 * Convert Claude CLI assistant message to OpenAI streaming chunk
 */
export function cliToOpenaiChunk(message, requestId, isFirst = false) {
    const text = extractTextContent(message);
    return {
        id: `chatcmpl-${requestId}`,
        object: "chat.completion.chunk",
        created: Math.floor(Date.now() / 1000),
        model: normalizeModelName(message.message.model),
        choices: [
            {
                index: 0,
                delta: {
                    role: isFirst ? "assistant" : undefined,
                    content: text,
                },
                finish_reason: message.message.stop_reason ? "stop" : null,
            },
        ],
    };
}
/**
 * Create a final "done" chunk for streaming
 * fullText: the complete response text, used to detect tool_calls
 */
export function createDoneChunk(requestId, model, fullText) {
    const { toolCalls } = fullText ? parseToolCalls(fullText) : { toolCalls: [] };
    const delta = toolCalls?.length
        ? { tool_calls: toolCalls }
        : {};
    return {
        id: `chatcmpl-${requestId}`,
        object: "chat.completion.chunk",
        created: Math.floor(Date.now() / 1000),
        model: normalizeModelName(model),
        choices: [
            {
                index: 0,
                delta,
                finish_reason: toolCalls?.length ? "tool_calls" : "stop",
            },
        ],
    };
}
/**
 * Convert Claude CLI result to OpenAI non-streaming response
 */
export function cliResultToOpenai(result, requestId) {
    // Get model from modelUsage or default
    const modelName = result.modelUsage
        ? Object.keys(result.modelUsage)[0]
        : "claude-sonnet-4";
    const rawText = result.result || "";
    const { toolCalls, remainingText } = parseToolCalls(rawText);
    const message = toolCalls.length
        ? { role: "assistant", content: remainingText || null, tool_calls: toolCalls }
        : { role: "assistant", content: rawText };
    return {
        id: `chatcmpl-${requestId}`,
        object: "chat.completion",
        created: Math.floor(Date.now() / 1000),
        model: normalizeModelName(modelName),
        choices: [
            {
                index: 0,
                message,
                finish_reason: toolCalls.length ? "tool_calls" : "stop",
            },
        ],
        usage: {
            prompt_tokens: result.usage?.input_tokens || 0,
            completion_tokens: result.usage?.output_tokens || 0,
            total_tokens: (result.usage?.input_tokens || 0) + (result.usage?.output_tokens || 0),
        },
    };
}
/**
 * Normalize Claude model names to a consistent format
 * e.g., "claude-sonnet-4-5-20250929" -> "claude-sonnet-4"
 */
function normalizeModelName(model) {
    if (model.includes("opus"))
        return "claude-opus-4";
    if (model.includes("sonnet"))
        return "claude-sonnet-4";
    if (model.includes("haiku"))
        return "claude-haiku-4";
    return model;
}
//# sourceMappingURL=cli-to-openai.js.map
