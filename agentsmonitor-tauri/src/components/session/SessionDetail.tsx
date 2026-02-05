import { useMemo } from 'react';
import { useSessionStore } from '../../stores/sessionStore';
import { useAppStore } from '../../stores/appStore';
import { TerminalView } from '../terminal/TerminalView';
import { ToolCallsList } from '../tools/ToolCallsList';
import { MetricsView } from '../metrics/MetricsView';
import {
  getStatusColor,
  getStatusIcon,
  getAgentTypeDisplayName,
  formatDuration,
  formatTime,
} from '../../types';
import type { DetailTab } from '../../types';
import './SessionDetail.css';

const tabs: { id: DetailTab; label: string }[] = [
  { id: 'terminal', label: 'Terminal' },
  { id: 'toolCalls', label: 'Tool Calls' },
  { id: 'metrics', label: 'Metrics' },
];

export function SessionDetail() {
  const { sessions, selectedSessionId } = useSessionStore();
  const { selectedDetailTab, setDetailTab, settings } = useAppStore();

  const session = useMemo(
    () => sessions.find((s) => s.id === selectedSessionId),
    [sessions, selectedSessionId]
  );

  if (!session) {
    return (
      <div className="session-detail empty">
        <div className="empty-detail-state">
          <p>Select a session to view details</p>
        </div>
      </div>
    );
  }

  return (
    <div className="session-detail">
      <div className="detail-header">
        <div className="detail-title">
          <h2>{session.name}</h2>
          <span
            className="detail-status"
            style={{ color: getStatusColor(session.status) }}
          >
            {getStatusIcon(session.status)} {session.status}
          </span>
        </div>
        <div className="detail-meta">
          <span className="meta-item">
            {getAgentTypeDisplayName(session.agentType)}
          </span>
          <span className="meta-item">
            Started: {formatTime(session.startedAt)}
          </span>
          <span className="meta-item">
            Duration: {formatDuration(session.startedAt, session.endedAt)}
          </span>
          {session.workingDirectory && (
            <span className="meta-item mono" title={session.workingDirectory}>
              📁 {session.workingDirectory.split('/').slice(-2).join('/')}
            </span>
          )}
        </div>
      </div>

      <div className="detail-tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={`tab-btn ${selectedDetailTab === tab.id ? 'active' : ''}`}
            onClick={() => setDetailTab(tab.id)}
            aria-selected={selectedDetailTab === tab.id}
          >
            {tab.label}
            {tab.id === 'toolCalls' && session.toolCalls.length > 0 && (
              <span className="tab-badge">{session.toolCalls.length}</span>
            )}
          </button>
        ))}
      </div>

      <div className="detail-content">
        {/* Keep terminal mounted but hidden to preserve state */}
        <div
          className="tab-panel"
          style={{ display: selectedDetailTab === 'terminal' ? 'flex' : 'none' }}
        >
          <TerminalView
            sessionId={session.id}
            settings={settings.terminalSettings}
            isVisible={selectedDetailTab === 'terminal'}
            storedOutput={session.terminalOutput}
            isActiveSession={session.status === 'Running' || session.status === 'Waiting'}
          />
        </div>
        <div
          className="tab-panel"
          style={{ display: selectedDetailTab === 'toolCalls' ? 'flex' : 'none' }}
        >
          <ToolCallsList toolCalls={session.toolCalls} />
        </div>
        <div
          className="tab-panel"
          style={{ display: selectedDetailTab === 'metrics' ? 'flex' : 'none' }}
        >
          <MetricsView metrics={session.metrics} session={session} />
        </div>
      </div>
    </div>
  );
}
