import { useSessionStore } from '../../stores/sessionStore';
import { useAppStore } from '../../stores/appStore';
import { SessionItem } from '../session/SessionItem';
import type { SessionStatus, SortOrder } from '../../types';
import './Sidebar.css';

const statusFilters: { value: SessionStatus | null; label: string }[] = [
  { value: null, label: 'All' },
  { value: 'Running', label: 'Running' },
  { value: 'Paused', label: 'Paused' },
  { value: 'Completed', label: 'Completed' },
  { value: 'Failed', label: 'Failed' },
  { value: 'Waiting', label: 'Waiting' },
];

const sortOptions: { value: SortOrder; label: string }[] = [
  { value: 'newest', label: 'Newest' },
  { value: 'oldest', label: 'Oldest' },
  { value: 'name', label: 'Name' },
  { value: 'status', label: 'Status' },
];

export function Sidebar() {
  const {
    selectedSessionId,
    searchText,
    filterStatus,
    sortOrder,
    setSearchText,
    setFilterStatus,
    setSortOrder,
    selectSession,
    getFilteredSessions,
    getActiveSessions,
  } = useSessionStore();

  const { setNewSessionOpen } = useAppStore();

  const filteredSessions = getFilteredSessions();
  const activeSessions = getActiveSessions();

  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div className="sidebar-title">
          <h2>Sessions</h2>
          <span className="session-count">
            {activeSessions.length > 0 && (
              <span className="active-badge">{activeSessions.length} active</span>
            )}
          </span>
        </div>
        <button
          className="new-session-btn"
          onClick={() => setNewSessionOpen(true)}
          aria-label="New session"
        >
          <span>+</span>
        </button>
      </div>

      <div className="sidebar-filters">
        <input
          type="search"
          className="search-input"
          placeholder="Search sessions..."
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
          aria-label="Search sessions"
        />

        <div className="filter-row">
          <select
            className="filter-select"
            value={filterStatus ?? ''}
            onChange={(e) =>
              setFilterStatus((e.target.value as SessionStatus) || null)
            }
            aria-label="Filter by status"
          >
            {statusFilters.map((filter) => (
              <option key={filter.value ?? 'all'} value={filter.value ?? ''}>
                {filter.label}
              </option>
            ))}
          </select>

          <select
            className="filter-select"
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value as SortOrder)}
            aria-label="Sort order"
          >
            {sortOptions.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div className="session-list">
        {filteredSessions.length === 0 ? (
          <div className="empty-state">
            {searchText || filterStatus ? (
              <p>No sessions match your filters</p>
            ) : (
              <>
                <p>No sessions yet</p>
                <button
                  className="create-first-btn"
                  onClick={() => setNewSessionOpen(true)}
                >
                  Create your first session
                </button>
              </>
            )}
          </div>
        ) : (
          filteredSessions.map((session) => (
            <SessionItem
              key={session.id}
              session={session}
              isSelected={session.id === selectedSessionId}
              onSelect={() => selectSession(session.id)}
            />
          ))
        )}
      </div>
    </aside>
  );
}
