import { useCallback } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { useSessionStore } from '../../stores/sessionStore';
import {
  Session,
  getStatusColor,
  getStatusIcon,
  getAgentTypeIcon,
  formatDuration,
  formatTokens,
} from '../../types';
import './SessionItem.css';

interface SessionItemProps {
  session: Session;
  isSelected: boolean;
  onSelect: () => void;
}

export function SessionItem({ session, isSelected, onSelect }: SessionItemProps) {
  const { deleteSession, updateSession } = useSessionStore();

  const handleDelete = useCallback(
    async (e: React.MouseEvent) => {
      e.stopPropagation();
      if (confirm(`Delete session "${session.name}"?`)) {
        await deleteSession(session.id);
      }
    },
    [deleteSession, session.id, session.name]
  );

  const handlePause = useCallback(
    async (e: React.MouseEvent) => {
      e.stopPropagation();
      await updateSession(session.id, 'Paused');
    },
    [updateSession, session.id]
  );

  const handleResume = useCallback(
    async (e: React.MouseEvent) => {
      e.stopPropagation();
      await updateSession(session.id, 'Running');
    },
    [updateSession, session.id]
  );

  const handleCancel = useCallback(
    async (e: React.MouseEvent) => {
      e.stopPropagation();
      await invoke('terminal_terminate', { sessionId: session.id });
      await updateSession(session.id, 'Cancelled');
    },
    [updateSession, session.id]
  );

  const handleContextMenu = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      // Context menu could be implemented here
    },
    []
  );

  return (
    <div
      className={`session-item ${isSelected ? 'selected' : ''}`}
      onClick={onSelect}
      onContextMenu={handleContextMenu}
      role="button"
      tabIndex={0}
      aria-selected={isSelected}
    >
      <div className="session-item-header">
        <span className="agent-icon">{getAgentTypeIcon(session.agentType)}</span>
        <span className="session-name">{session.name}</span>
        <span
          className="status-badge"
          style={{ color: getStatusColor(session.status) }}
        >
          {getStatusIcon(session.status)}
        </span>
      </div>

      <div className="session-item-meta">
        <span className="session-duration">
          {formatDuration(session.startedAt, session.endedAt)}
        </span>
        {session.metrics.totalTokens > 0 && (
          <span className="session-tokens">
            {formatTokens(session.metrics.totalTokens)} tokens
          </span>
        )}
        {session.metrics.toolCallCount > 0 && (
          <span className="session-tools">
            {session.metrics.toolCallCount} tools
          </span>
        )}
      </div>

      {session.workingDirectory && (
        <div className="session-item-path" title={session.workingDirectory}>
          {session.workingDirectory.split('/').pop()}
        </div>
      )}

      {isSelected && (
        <div className="session-item-actions">
          {session.status === 'Running' && (
            <>
              <button
                className="action-btn"
                onClick={handlePause}
                aria-label="Pause session"
                title="Pause"
              >
                ⏸
              </button>
              <button
                className="action-btn danger"
                onClick={handleCancel}
                aria-label="Cancel session"
                title="Cancel"
              >
                ◼
              </button>
            </>
          )}
          {session.status === 'Paused' && (
            <button
              className="action-btn"
              onClick={handleResume}
              aria-label="Resume session"
              title="Resume"
            >
              ▶
            </button>
          )}
          <button
            className="action-btn danger"
            onClick={handleDelete}
            aria-label="Delete session"
            title="Delete"
          >
            🗑
          </button>
        </div>
      )}
    </div>
  );
}
