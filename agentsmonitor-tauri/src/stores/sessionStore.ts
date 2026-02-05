import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import type { Session, SessionStatus, AgentType, SortOrder } from '../types';

interface SessionState {
  sessions: Session[];
  selectedSessionId: string | null;
  isLoading: boolean;
  error: string | null;
  searchText: string;
  filterStatus: SessionStatus | null;
  sortOrder: SortOrder;

  // Actions
  loadSessions: () => Promise<void>;
  createSession: (
    name: string,
    agentType: AgentType,
    workingDirectory?: string
  ) => Promise<Session>;
  updateSession: (
    sessionId: string,
    status?: SessionStatus,
    errorMessage?: string
  ) => Promise<void>;
  deleteSession: (sessionId: string) => Promise<void>;
  selectSession: (sessionId: string | null) => void;
  setSearchText: (text: string) => void;
  setFilterStatus: (status: SessionStatus | null) => void;
  setSortOrder: (order: SortOrder) => void;

  // Derived getters
  getFilteredSessions: () => Session[];
  getActiveSessions: () => Session[];
  getCompletedSessions: () => Session[];
}

export const useSessionStore = create<SessionState>((set, get) => ({
  sessions: [],
  selectedSessionId: null,
  isLoading: false,
  error: null,
  searchText: '',
  filterStatus: null,
  sortOrder: 'newest',

  loadSessions: async () => {
    set({ isLoading: true, error: null });
    try {
      const sessions = await invoke<Session[]>('get_sessions');
      set({ sessions, isLoading: false });
    } catch (err) {
      set({ error: String(err), isLoading: false });
    }
  },

  createSession: async (name, agentType, workingDirectory) => {
    try {
      const session = await invoke<Session>('create_session', {
        name,
        agentType,
        workingDirectory,
      });
      set((state) => ({
        sessions: [session, ...state.sessions],
        selectedSessionId: session.id,
      }));
      return session;
    } catch (err) {
      set({ error: String(err) });
      throw err;
    }
  },

  updateSession: async (sessionId, status, errorMessage) => {
    try {
      const session = await invoke<Session>('update_session', {
        sessionId,
        status,
        errorMessage,
      });
      set((state) => ({
        sessions: state.sessions.map((s) =>
          s.id === sessionId ? session : s
        ),
      }));
    } catch (err) {
      set({ error: String(err) });
      throw err;
    }
  },

  deleteSession: async (sessionId) => {
    try {
      await invoke('delete_session', { sessionId });
      set((state) => ({
        sessions: state.sessions.filter((s) => s.id !== sessionId),
        selectedSessionId:
          state.selectedSessionId === sessionId
            ? null
            : state.selectedSessionId,
      }));
    } catch (err) {
      set({ error: String(err) });
      throw err;
    }
  },

  selectSession: (sessionId) => {
    set({ selectedSessionId: sessionId });
  },

  setSearchText: (text) => {
    set({ searchText: text });
  },

  setFilterStatus: (status) => {
    set({ filterStatus: status });
  },

  setSortOrder: (order) => {
    set({ sortOrder: order });
  },

  getFilteredSessions: () => {
    const { sessions, searchText, filterStatus, sortOrder } = get();

    let filtered = [...sessions];

    // Apply search filter
    if (searchText) {
      const lower = searchText.toLowerCase();
      filtered = filtered.filter(
        (s) =>
          s.name.toLowerCase().includes(lower) ||
          s.workingDirectory?.toLowerCase().includes(lower)
      );
    }

    // Apply status filter
    if (filterStatus) {
      filtered = filtered.filter((s) => s.status === filterStatus);
    }

    // Apply sorting
    switch (sortOrder) {
      case 'newest':
        filtered.sort(
          (a, b) =>
            new Date(b.startedAt).getTime() - new Date(a.startedAt).getTime()
        );
        break;
      case 'oldest':
        filtered.sort(
          (a, b) =>
            new Date(a.startedAt).getTime() - new Date(b.startedAt).getTime()
        );
        break;
      case 'name':
        filtered.sort((a, b) => a.name.localeCompare(b.name));
        break;
      case 'status':
        filtered.sort((a, b) => a.status.localeCompare(b.status));
        break;
    }

    return filtered;
  },

  getActiveSessions: () => {
    const { sessions } = get();
    return sessions.filter(
      (s) => s.status === 'Running' || s.status === 'Waiting'
    );
  },

  getCompletedSessions: () => {
    const { sessions } = get();
    return sessions.filter(
      (s) =>
        s.status === 'Completed' ||
        s.status === 'Failed' ||
        s.status === 'Cancelled'
    );
  },
}));

// Setup event listeners for real-time updates
export function setupSessionEventListeners() {
  listen<Session>('session_started', (event) => {
    useSessionStore.setState((state) => ({
      sessions: [event.payload, ...state.sessions],
    }));
  });

  listen<Session>('session_updated', (event) => {
    useSessionStore.setState((state) => ({
      sessions: state.sessions.map((s) =>
        s.id === event.payload.id ? event.payload : s
      ),
    }));
  });

  listen<string>('session_ended', (event) => {
    useSessionStore.setState((state) => ({
      sessions: state.sessions.map((s) =>
        s.id === event.payload ? { ...s, status: 'Completed' as SessionStatus } : s
      ),
    }));
  });
}
