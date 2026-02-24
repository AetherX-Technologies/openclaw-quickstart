/**
 * Converts OpenAI chat request format to Claude CLI input
 */
const MODEL_MAP = {
    // Direct model names
    "claude-opus-4": "opus",
    "claude-sonnet-4": "sonnet",
    "claude-haiku-4": "haiku",
    // With provider prefix
    "claude-code-cli/claude-opus-4": "opus",
    "claude-code-cli/claude-sonnet-4": "sonnet",
    "claude-code-cli/claude-haiku-4": "haiku",
    // Aliases
    "opus": "opus",
    "sonnet": "sonnet",
    "haiku": "haiku",
};
/**
 * Extract Claude model alias from request model string
 */
export function extractModel(model) {
    // Try direct lookup
    if (MODEL_MAP[model]) {
        return MODEL_MAP[model];
    }
    // Try stripping provider prefix
    const stripped = model.replace(/^claude-code-cli\//, "");
    if (MODEL_MAP[stripped]) {
        return MODEL_MAP[stripped];
    }
    // Default to opus (Claude Max subscription)
    return "opus";
}
/**
 * Format OpenAI tool definitions into a system prompt section
 */
function toolsToSystemPrompt(tools) {
    if (!tools || tools.length === 0) return "";
    const defs = tools.map(t => {
        const fn = t.function || t;
        const params = fn.parameters ? JSON.stringify(fn.parameters, null, 2) : "{}";
        return `### ${fn.name}\n${fn.description || ""}\nParameters: ${params}`;
    }).join("\n\n");
    return `<tool_instructions>
IMPORTANT: You are an AI assistant with access to tools listed below. You do NOT execute tools yourself — you simply output a <tool_call> JSON block and the system will execute it and return the result to you.

When you want to use a tool, output ONLY this format (nothing else in that response):
<tool_call>
{"name": "tool_name", "arguments": {"param": "value"}}
</tool_call>

The system will run the tool and send you back a <tool_result>. Then you can respond normally.

DO NOT say you are sandboxed or unable to run commands. You have full access through these tools.
DO NOT explain what you would do — just output the <tool_call> block directly.
DO NOT use the exec tool to spawn Claude Code or any subagent for browser tasks. Use the browser tool directly.
DO NOT use the coding-agent skill or subagents skill for browser/web navigation tasks. Call browser tool yourself.

Available tools:
${defs}
</tool_instructions>`;
}
/**
 * Convert OpenAI messages array to a single prompt string for Claude CLI
 *
 * Claude Code CLI in --print mode expects a single prompt, not a conversation.
 * We format the messages into a readable format that preserves context.
 */
// Tools that spawn subagents/Claude Code — strip them so the LLM must handle requests directly
const BLOCKED_TOOLS = new Set(['exec', 'subagents', 'session_status', 'sessions_spawn']);

export function messagesToPrompt(messages, tools) {
    const parts = [];
    // Filter out subagent-spawning tools before injecting
    const filteredTools = tools ? tools.filter(t => {
        const name = (t.function || t).name;
        return !BLOCKED_TOOLS.has(name);
    }) : tools;
    // Inject tool definitions at the top if present
    const toolsPrompt = toolsToSystemPrompt(filteredTools);
    if (toolsPrompt) {
        parts.push(toolsPrompt + "\n");
    }
    for (const msg of messages) {
        switch (msg.role) {
            case "system":
                // System messages become context instructions
                parts.push(`<system>\n${msg.content}\n</system>\n`);
                break;
            case "user": {
                // content can be a string or an array of content blocks (OpenAI structured format)
                const userText = Array.isArray(msg.content)
                    ? msg.content.filter(b => b.type === "text").map(b => b.text).join("\n")
                    : msg.content;
                parts.push(userText);
                break;
            }
            case "assistant": {
                const assistantText = Array.isArray(msg.content)
                    ? msg.content.filter(b => b.type === "text").map(b => b.text).join("\n")
                    : msg.content;
                parts.push(`<previous_response>\n${assistantText}\n</previous_response>\n`);
                break;
            }
            case "tool": {
                // Tool result — inject back as context
                const toolContent = Array.isArray(msg.content)
                    ? msg.content.map(b => b.text || b.content || "").join("\n")
                    : String(msg.content);
                parts.push(`<tool_result tool_call_id="${msg.tool_call_id}">\n${toolContent}\n</tool_result>\n`);
                break;
            }
        }
    }
    return parts.join("\n").trim();
}
/**
 * Convert OpenAI chat request to CLI input format
 */
export function openaiToCli(request) {
    return {
        prompt: messagesToPrompt(request.messages, request.tools),
        model: extractModel(request.model),
        sessionId: request.user, // Use OpenAI's user field for session mapping
    };
}
//# sourceMappingURL=openai-to-cli.js.map
