import type { Session, SessionMetrics } from '../../types';
import { formatTokens, formatDuration } from '../../types';
import './MetricsView.css';

interface MetricsViewProps {
  metrics: SessionMetrics;
  session: Session;
}

interface MetricCardProps {
  label: string;
  value: string | number;
  subValue?: string;
  color?: string;
}

function MetricCard({ label, value, subValue, color }: MetricCardProps) {
  return (
    <div className="metric-card">
      <div className="metric-label">{label}</div>
      <div className="metric-value" style={color ? { color } : undefined}>
        {value}
      </div>
      {subValue && <div className="metric-subvalue">{subValue}</div>}
    </div>
  );
}

export function MetricsView({ metrics, session }: MetricsViewProps) {
  const cacheHitRate =
    metrics.totalTokens > 0
      ? ((metrics.cacheReadTokens / metrics.totalTokens) * 100).toFixed(1)
      : '0.0';

  return (
    <div className="metrics-view">
      <section className="metrics-section">
        <h3>Token Usage</h3>
        <div className="metrics-grid">
          <MetricCard
            label="Total Tokens"
            value={formatTokens(metrics.totalTokens)}
            subValue={`${metrics.totalTokens.toLocaleString()} exact`}
          />
          <MetricCard
            label="Input Tokens"
            value={formatTokens(metrics.inputTokens)}
            color="var(--color-blue)"
          />
          <MetricCard
            label="Output Tokens"
            value={formatTokens(metrics.outputTokens)}
            color="var(--color-green)"
          />
        </div>
      </section>

      <section className="metrics-section">
        <h3>Cache Statistics</h3>
        <div className="metrics-grid">
          <MetricCard
            label="Cache Read"
            value={formatTokens(metrics.cacheReadTokens)}
            color="var(--color-teal)"
          />
          <MetricCard
            label="Cache Write"
            value={formatTokens(metrics.cacheWriteTokens)}
            color="var(--color-peach)"
          />
          <MetricCard
            label="Cache Hit Rate"
            value={`${cacheHitRate}%`}
            color="var(--color-mauve)"
          />
        </div>
      </section>

      <section className="metrics-section">
        <h3>Activity</h3>
        <div className="metrics-grid">
          <MetricCard
            label="API Calls"
            value={metrics.apiCalls}
            color="var(--color-blue)"
          />
          <MetricCard
            label="Tool Calls"
            value={metrics.toolCallCount}
            color="var(--color-yellow)"
          />
          <MetricCard
            label="Errors"
            value={metrics.errorCount}
            color={metrics.errorCount > 0 ? 'var(--color-red)' : undefined}
          />
        </div>
      </section>

      <section className="metrics-section">
        <h3>Session Info</h3>
        <div className="metrics-grid">
          <MetricCard
            label="Duration"
            value={formatDuration(session.startedAt, session.endedAt)}
          />
          <MetricCard label="Status" value={session.status} />
          <MetricCard
            label="Process ID"
            value={session.processId ?? 'N/A'}
          />
        </div>
      </section>

      {session.errorMessage && (
        <section className="metrics-section error">
          <h3>Error Message</h3>
          <div className="error-message">
            <pre>{session.errorMessage}</pre>
          </div>
        </section>
      )}
    </div>
  );
}
