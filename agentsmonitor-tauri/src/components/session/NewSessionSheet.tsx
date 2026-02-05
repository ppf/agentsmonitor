import { useState, useCallback, useEffect } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { open } from '@tauri-apps/plugin-dialog';
import { useAppStore } from '../../stores/appStore';
import { useSessionStore } from '../../stores/sessionStore';
import type { AgentType } from '../../types';
import { getAgentTypeIcon, getAgentTypeDisplayName } from '../../types';
import './NewSessionSheet.css';

const agentTypes: AgentType[] = ['ClaudeCode', 'Codex', 'Custom'];

export function NewSessionSheet() {
  const { setNewSessionOpen, settings } = useAppStore();
  const { createSession, selectSession } = useSessionStore();

  const [agentType, setAgentType] = useState<AgentType>('ClaudeCode');
  const [sessionName, setSessionName] = useState('');
  const [workingDirectory, setWorkingDirectory] = useState(
    settings.defaultWorkingDirectory || ''
  );
  const [executablePath, setExecutablePath] = useState<string | null>(null);
  const [isResolving, setIsResolving] = useState(false);
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Resolve executable path when agent type changes
  useEffect(() => {
    setIsResolving(true);
    setError(null);

    invoke<string | null>('resolve_agent_executable', {
      agentType,
      overridePath: null,
    })
      .then((path) => {
        setExecutablePath(path);
        if (!path) {
          setError(`${getAgentTypeDisplayName(agentType)} executable not found`);
        }
      })
      .catch((err) => {
        setError(String(err));
        setExecutablePath(null);
      })
      .finally(() => {
        setIsResolving(false);
      });
  }, [agentType]);

  // Generate default session name
  useEffect(() => {
    const dirName = workingDirectory.split('/').pop() || 'Session';
    const timestamp = new Date().toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    });
    setSessionName(`${dirName} - ${timestamp}`);
  }, [workingDirectory]);

  const handleSelectDirectory = useCallback(async () => {
    try {
      const selected = await open({
        directory: true,
        multiple: false,
        defaultPath: workingDirectory || undefined,
      });

      if (selected) {
        setWorkingDirectory(selected as string);
      }
    } catch (err) {
      console.error('Failed to select directory:', err);
    }
  }, [workingDirectory]);

  const handleCreate = useCallback(async () => {
    if (!sessionName || !workingDirectory) {
      setError('Please fill in all required fields');
      return;
    }

    if (!executablePath) {
      setError('Agent executable not found');
      return;
    }

    setIsCreating(true);
    setError(null);

    try {
      const session = await createSession(
        sessionName,
        agentType,
        workingDirectory
      );

      // Spawn terminal process
      await invoke('spawn_terminal', {
        sessionId: session.id,
        agentType,
        workingDirectory,
        overrideExecutable: null,
      });

      selectSession(session.id);
      setNewSessionOpen(false);
    } catch (err) {
      setError(String(err));
    } finally {
      setIsCreating(false);
    }
  }, [
    sessionName,
    workingDirectory,
    agentType,
    executablePath,
    createSession,
    selectSession,
    setNewSessionOpen,
  ]);

  const handleClose = useCallback(() => {
    setNewSessionOpen(false);
  }, [setNewSessionOpen]);

  return (
    <div className="new-session-overlay" onClick={handleClose}>
      <div className="new-session-modal" onClick={(e) => e.stopPropagation()}>
        <div className="new-session-header">
          <h2>New Session</h2>
          <button
            className="close-btn"
            onClick={handleClose}
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        <div className="new-session-content">
          <div className="form-group">
            <label>Agent Type</label>
            <div className="agent-type-selector">
              {agentTypes.map((type) => (
                <button
                  key={type}
                  className={`agent-type-btn ${
                    agentType === type ? 'selected' : ''
                  }`}
                  onClick={() => setAgentType(type)}
                >
                  <span className="agent-icon">{getAgentTypeIcon(type)}</span>
                  <span className="agent-name">
                    {getAgentTypeDisplayName(type)}
                  </span>
                </button>
              ))}
            </div>
          </div>

          <div className="form-group">
            <label htmlFor="sessionName">Session Name</label>
            <input
              type="text"
              id="sessionName"
              value={sessionName}
              onChange={(e) => setSessionName(e.target.value)}
              placeholder="My Session"
            />
          </div>

          <div className="form-group">
            <label htmlFor="workingDirectory">Working Directory</label>
            <div className="directory-input">
              <input
                type="text"
                id="workingDirectory"
                value={workingDirectory}
                onChange={(e) => setWorkingDirectory(e.target.value)}
                placeholder="/path/to/project"
              />
              <button
                className="browse-btn"
                onClick={handleSelectDirectory}
                type="button"
              >
                Browse...
              </button>
            </div>
          </div>

          <div className="executable-status">
            {isResolving ? (
              <span className="status-resolving">Checking executable...</span>
            ) : executablePath ? (
              <span className="status-found">
                ✓ Found: <code>{executablePath}</code>
              </span>
            ) : (
              <span className="status-not-found">
                ✗ Executable not found
              </span>
            )}
          </div>

          {error && <div className="error-message">{error}</div>}
        </div>

        <div className="new-session-footer">
          <button className="cancel-btn" onClick={handleClose}>
            Cancel
          </button>
          <button
            className="create-btn"
            onClick={handleCreate}
            disabled={
              isCreating || isResolving || !executablePath || !workingDirectory
            }
          >
            {isCreating ? 'Creating...' : 'Start Session'}
          </button>
        </div>
      </div>
    </div>
  );
}
