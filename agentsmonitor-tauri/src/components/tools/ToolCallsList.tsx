import { useState, useCallback } from 'react';
import type { ToolCall } from '../../types';
import { getToolCallStatusColor, formatTime } from '../../types';
import './ToolCallsList.css';

interface ToolCallsListProps {
  toolCalls: ToolCall[];
}

const toolIcons: Record<string, string> = {
  read: '📄',
  write: '✏️',
  edit: '📝',
  bash: '💻',
  shell: '💻',
  search: '🔍',
  grep: '🔍',
  web: '🌐',
  fetch: '🌐',
  git: '🔀',
  task: '⚙️',
  agent: '🤖',
};

function getToolIcon(name: string): string {
  const lower = name.toLowerCase();
  for (const [key, icon] of Object.entries(toolIcons)) {
    if (lower.includes(key)) {
      return icon;
    }
  }
  return '🔧';
}

interface ToolCallItemProps {
  toolCall: ToolCall;
}

function ToolCallItem({ toolCall }: ToolCallItemProps) {
  const [isExpanded, setIsExpanded] = useState(false);

  const toggleExpand = useCallback(() => {
    setIsExpanded((prev) => !prev);
  }, []);

  const durationMs = toolCall.completedAt
    ? new Date(toolCall.completedAt).getTime() -
      new Date(toolCall.startedAt).getTime()
    : null;

  const formattedDuration =
    durationMs !== null
      ? durationMs < 1000
        ? `${durationMs}ms`
        : `${(durationMs / 1000).toFixed(2)}s`
      : '...';

  return (
    <div className={`tool-call-item ${toolCall.status.toLowerCase()}`}>
      <div
        className="tool-call-header"
        onClick={toggleExpand}
        role="button"
        tabIndex={0}
        aria-expanded={isExpanded}
      >
        <span className="tool-icon">{getToolIcon(toolCall.name)}</span>
        <span className="tool-name">{toolCall.name}</span>
        <span
          className="tool-status"
          style={{ color: getToolCallStatusColor(toolCall.status) }}
        >
          {toolCall.status}
        </span>
        <span className="tool-duration">{formattedDuration}</span>
        <span className="tool-time">{formatTime(toolCall.startedAt)}</span>
        <span className="expand-icon">{isExpanded ? '▼' : '▶'}</span>
      </div>

      {isExpanded && (
        <div className="tool-call-body">
          <div className="tool-section">
            <h4>Input</h4>
            <pre className="tool-content">{toolCall.input || '(empty)'}</pre>
          </div>

          {toolCall.output && (
            <div className="tool-section">
              <h4>Output</h4>
              <pre className="tool-content">{toolCall.output}</pre>
            </div>
          )}

          {toolCall.error && (
            <div className="tool-section error">
              <h4>Error</h4>
              <pre className="tool-content error">{toolCall.error}</pre>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export function ToolCallsList({ toolCalls }: ToolCallsListProps) {
  if (toolCalls.length === 0) {
    return (
      <div className="tool-calls-empty">
        <p>No tool calls in this session</p>
      </div>
    );
  }

  return (
    <div className="tool-calls-list">
      {toolCalls.map((toolCall) => (
        <ToolCallItem key={toolCall.id} toolCall={toolCall} />
      ))}
    </div>
  );
}
