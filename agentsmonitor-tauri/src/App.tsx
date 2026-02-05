import { useEffect, useCallback } from 'react';
import { listen } from '@tauri-apps/api/event';
import { Sidebar } from './components/layout/Sidebar';
import { SessionDetail } from './components/session/SessionDetail';
import { SettingsView } from './components/settings/SettingsView';
import { NewSessionSheet } from './components/session/NewSessionSheet';
import { useSessionStore, setupSessionEventListeners } from './stores/sessionStore';
import { useAppStore } from './stores/appStore';
import './styles/theme.css';
import './App.css';

function App() {
  const { loadSessions } = useSessionStore();
  const { isSettingsOpen, isNewSessionOpen, setSettingsOpen, setNewSessionOpen, setDetailTab } =
    useAppStore();

  // Load sessions on mount and setup event listeners
  useEffect(() => {
    loadSessions();
    setupSessionEventListeners();

    // Listen for tray menu events
    const unlistenNewSession = listen('open_new_session', () => {
      setNewSessionOpen(true);
    });

    return () => {
      unlistenNewSession.then((fn) => fn());
    };
  }, [loadSessions, setNewSessionOpen]);

  // Keyboard shortcuts
  const handleKeyDown = useCallback(
    (e: KeyboardEvent) => {
      // Cmd+N: New session
      if (e.metaKey && e.key === 'n') {
        e.preventDefault();
        setNewSessionOpen(true);
      }
      // Cmd+,: Settings
      if (e.metaKey && e.key === ',') {
        e.preventDefault();
        setSettingsOpen(true);
      }
      // Cmd+1/2/3: Switch tabs
      if (e.metaKey && e.key === '1') {
        e.preventDefault();
        setDetailTab('terminal');
      }
      if (e.metaKey && e.key === '2') {
        e.preventDefault();
        setDetailTab('toolCalls');
      }
      if (e.metaKey && e.key === '3') {
        e.preventDefault();
        setDetailTab('metrics');
      }
      // Escape: Close modals
      if (e.key === 'Escape') {
        if (isSettingsOpen) {
          setSettingsOpen(false);
        } else if (isNewSessionOpen) {
          setNewSessionOpen(false);
        }
      }
    },
    [isSettingsOpen, isNewSessionOpen, setSettingsOpen, setNewSessionOpen, setDetailTab]
  );

  useEffect(() => {
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  return (
    <div className="app">
      <div className="app-layout">
        <Sidebar />
        <main className="main-content">
          <SessionDetail />
        </main>
      </div>

      {isSettingsOpen && <SettingsView />}
      {isNewSessionOpen && <NewSessionSheet />}
    </div>
  );
}

export default App;
