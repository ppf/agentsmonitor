// Session types matching Rust models

export type SessionStatus =
  | 'Running'
  | 'Paused'
  | 'Completed'
  | 'Failed'
  | 'Waiting'
  | 'Cancelled';

export type AgentType = 'ClaudeCode' | 'Codex' | 'Custom';

export type MessageRole = 'User' | 'Assistant' | 'System' | 'Tool';

export type ToolCallStatus = 'Pending' | 'Running' | 'Completed' | 'Failed';

export interface SessionMetrics {
  totalTokens: number;
  inputTokens: number;
  outputTokens: number;
  toolCallCount: number;
  errorCount: number;
  apiCalls: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
}

export interface Message {
  id: string;
  role: MessageRole;
  content: string;
  timestamp: string;
  isStreaming: boolean;
  toolUseId?: string;
}

export interface ToolCall {
  id: string;
  name: string;
  input: string;
  output?: string;
  startedAt: string;
  completedAt?: string;
  status: ToolCallStatus;
  error?: string;
}

export interface Session {
  id: string;
  name: string;
  status: SessionStatus;
  agentType: AgentType;
  startedAt: string;
  endedAt?: string;
  messages: Message[];
  toolCalls: ToolCall[];
  metrics: SessionMetrics;
  workingDirectory?: string;
  processId?: number;
  errorMessage?: string;
  isExternalProcess: boolean;
  isFullyLoaded: boolean;
  terminalOutput?: number[];
}

export interface SessionSummary {
  id: string;
  name: string;
  status: SessionStatus;
  agentType: AgentType;
  startedAt: string;
  endedAt?: string;
  metrics: SessionMetrics;
  workingDirectory?: string;
  processId?: number;
  errorMessage?: string;
  isExternalProcess: boolean;
}

// UI types

export type DetailTab = 'terminal' | 'toolCalls' | 'metrics';

export type SortOrder = 'newest' | 'oldest' | 'name' | 'status';

export type Appearance = 'system' | 'light' | 'dark';

export type TerminalTheme = 'auto' | 'dark' | 'light';

export interface TerminalSettings {
  theme: TerminalTheme;
  fontFamily: string;
  fontSize: number;
  scrollback: number;
}

export interface AppSettings {
  terminalSettings: TerminalSettings;
  defaultWorkingDirectory: string;
  showMenuBarExtra: boolean;
  compactMode: boolean;
  appearance: Appearance;
}

// Helper functions

export function getStatusColor(status: SessionStatus): string {
  const colors: Record<SessionStatus, string> = {
    Running: 'var(--color-green)',
    Paused: 'var(--color-yellow)',
    Completed: 'var(--color-blue)',
    Failed: 'var(--color-red)',
    Waiting: 'var(--color-peach)',
    Cancelled: 'var(--color-overlay1)',
  };
  return colors[status];
}

export function getStatusIcon(status: SessionStatus): string {
  const icons: Record<SessionStatus, string> = {
    Running: '▶',
    Paused: '⏸',
    Completed: '✓',
    Failed: '✗',
    Waiting: '◷',
    Cancelled: '◼',
  };
  return icons[status];
}

export function getAgentTypeIcon(agentType: AgentType): string {
  const icons: Record<AgentType, string> = {
    ClaudeCode: '🧠',
    Codex: '⌨',
    Custom: '⚙',
  };
  return icons[agentType];
}

export function getAgentTypeDisplayName(agentType: AgentType): string {
  const names: Record<AgentType, string> = {
    ClaudeCode: 'Claude Code',
    Codex: 'Codex',
    Custom: 'Custom Agent',
  };
  return names[agentType];
}

export function getRoleColor(role: MessageRole): string {
  const colors: Record<MessageRole, string> = {
    User: 'var(--color-blue)',
    Assistant: 'var(--color-mauve)',
    System: 'var(--color-overlay1)',
    Tool: 'var(--color-peach)',
  };
  return colors[role];
}

export function getToolCallStatusColor(status: ToolCallStatus): string {
  const colors: Record<ToolCallStatus, string> = {
    Pending: 'var(--color-overlay1)',
    Running: 'var(--color-blue)',
    Completed: 'var(--color-green)',
    Failed: 'var(--color-red)',
  };
  return colors[status];
}

export function formatDuration(startedAt: string, endedAt?: string): string {
  const start = new Date(startedAt).getTime();
  const end = endedAt ? new Date(endedAt).getTime() : Date.now();
  const secs = (end - start) / 1000;

  if (secs < 60) {
    return `${Math.floor(secs)}s`;
  } else if (secs < 3600) {
    return `${Math.floor(secs / 60)}m ${Math.floor(secs % 60)}s`;
  } else {
    const hours = Math.floor(secs / 3600);
    const mins = Math.floor((secs % 3600) / 60);
    return `${hours}h ${mins}m`;
  }
}

export function formatTokens(tokens: number): string {
  if (tokens >= 1_000_000) {
    return `${(tokens / 1_000_000).toFixed(1)}M`;
  } else if (tokens >= 1_000) {
    return `${(tokens / 1_000).toFixed(1)}K`;
  }
  return tokens.toString();
}

export function formatTime(timestamp: string): string {
  return new Date(timestamp).toLocaleTimeString();
}

export function formatDate(timestamp: string): string {
  return new Date(timestamp).toLocaleDateString();
}
