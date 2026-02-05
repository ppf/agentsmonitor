import { useState } from 'react';
import { useAppStore } from '../../stores/appStore';
import type { Appearance, TerminalTheme, AppSettings, TerminalSettings as TerminalSettingsType } from '../../types';
import './SettingsView.css';

type SettingsTab = 'general' | 'appearance' | 'terminal' | 'connection' | 'shortcuts';

const tabs: { id: SettingsTab; label: string }[] = [
  { id: 'general', label: 'General' },
  { id: 'appearance', label: 'Appearance' },
  { id: 'terminal', label: 'Terminal' },
  { id: 'connection', label: 'Connection' },
  { id: 'shortcuts', label: 'Shortcuts' },
];

export function SettingsView() {
  const { settings, updateSettings, updateTerminalSettings, setSettingsOpen } =
    useAppStore();
  const [activeTab, setActiveTab] = useState<SettingsTab>('general');

  return (
    <div className="settings-overlay" onClick={() => setSettingsOpen(false)}>
      <div className="settings-modal" onClick={(e) => e.stopPropagation()}>
        <div className="settings-header">
          <h2>Settings</h2>
          <button
            className="close-btn"
            onClick={() => setSettingsOpen(false)}
            aria-label="Close settings"
          >
            ✕
          </button>
        </div>

        <div className="settings-content">
          <nav className="settings-nav">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                className={`nav-btn ${activeTab === tab.id ? 'active' : ''}`}
                onClick={() => setActiveTab(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </nav>

          <div className="settings-panel">
            {activeTab === 'general' && (
              <GeneralSettings
                settings={settings}
                updateSettings={updateSettings}
              />
            )}
            {activeTab === 'appearance' && (
              <AppearanceSettings
                settings={settings}
                updateSettings={updateSettings}
              />
            )}
            {activeTab === 'terminal' && (
              <TerminalSettings
                settings={settings.terminalSettings}
                updateSettings={updateTerminalSettings}
              />
            )}
            {activeTab === 'connection' && <ConnectionSettings />}
            {activeTab === 'shortcuts' && <ShortcutsSettings />}
          </div>
        </div>
      </div>
    </div>
  );
}

interface GeneralSettingsProps {
  settings: AppSettings;
  updateSettings: (updates: Partial<AppSettings>) => void;
}

function GeneralSettings({ settings, updateSettings }: GeneralSettingsProps) {
  return (
    <div className="settings-section">
      <h3>General</h3>

      <div className="setting-item">
        <label htmlFor="defaultDirectory">Default Working Directory</label>
        <input
          type="text"
          id="defaultDirectory"
          value={settings.defaultWorkingDirectory}
          onChange={(e) =>
            updateSettings({ defaultWorkingDirectory: e.target.value })
          }
          placeholder="~/Projects"
        />
        <p className="setting-description">
          Default directory for new sessions. Leave empty to use home directory.
        </p>
      </div>

      <div className="setting-item">
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={settings.showMenuBarExtra}
            onChange={(e) =>
              updateSettings({ showMenuBarExtra: e.target.checked })
            }
          />
          <span>Show Menu Bar Extra</span>
        </label>
        <p className="setting-description">
          Show quick access icon in the menu bar.
        </p>
      </div>
    </div>
  );
}

function AppearanceSettings({
  settings,
  updateSettings,
}: GeneralSettingsProps) {
  return (
    <div className="settings-section">
      <h3>Appearance</h3>

      <div className="setting-item">
        <label htmlFor="appearance">Theme</label>
        <select
          id="appearance"
          value={settings.appearance}
          onChange={(e) =>
            updateSettings({ appearance: e.target.value as Appearance })
          }
        >
          <option value="system">System</option>
          <option value="light">Light</option>
          <option value="dark">Dark</option>
        </select>
        <p className="setting-description">
          Choose your preferred color scheme.
        </p>
      </div>

      <div className="setting-item">
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={settings.compactMode}
            onChange={(e) => updateSettings({ compactMode: e.target.checked })}
          />
          <span>Compact Mode</span>
        </label>
        <p className="setting-description">
          Reduce padding and spacing for more content density.
        </p>
      </div>
    </div>
  );
}

interface TerminalSettingsProps {
  settings: TerminalSettingsType;
  updateSettings: (updates: Partial<TerminalSettingsType>) => void;
}

function TerminalSettings({ settings, updateSettings }: TerminalSettingsProps) {
  return (
    <div className="settings-section">
      <h3>Terminal</h3>

      <div className="setting-item">
        <label htmlFor="terminalTheme">Terminal Theme</label>
        <select
          id="terminalTheme"
          value={settings.theme}
          onChange={(e) =>
            updateSettings({ theme: e.target.value as TerminalTheme })
          }
        >
          <option value="auto">Auto</option>
          <option value="dark">Dark (Catppuccin Mocha)</option>
          <option value="light">Light</option>
        </select>
      </div>

      <div className="setting-item">
        <label htmlFor="fontFamily">Font Family</label>
        <input
          type="text"
          id="fontFamily"
          value={settings.fontFamily}
          onChange={(e) => updateSettings({ fontFamily: e.target.value })}
        />
        <p className="setting-description">
          Monospace font for terminal display.
        </p>
      </div>

      <div className="setting-item">
        <label htmlFor="fontSize">Font Size</label>
        <input
          type="number"
          id="fontSize"
          value={settings.fontSize}
          onChange={(e) =>
            updateSettings({ fontSize: parseInt(e.target.value, 10) || 13 })
          }
          min={8}
          max={24}
        />
      </div>

      <div className="setting-item">
        <label htmlFor="scrollback">Scrollback Lines</label>
        <input
          type="number"
          id="scrollback"
          value={settings.scrollback}
          onChange={(e) =>
            updateSettings({ scrollback: parseInt(e.target.value, 10) || 1000 })
          }
          min={100}
          max={10000}
          step={100}
        />
        <p className="setting-description">
          Number of lines to keep in terminal history.
        </p>
      </div>
    </div>
  );
}

function ConnectionSettings() {
  return (
    <div className="settings-section">
      <h3>Connection</h3>

      <div className="setting-item">
        <label htmlFor="wsHost">WebSocket Host</label>
        <input
          type="text"
          id="wsHost"
          defaultValue="localhost"
          placeholder="localhost"
          disabled
        />
        <p className="setting-description">
          WebSocket server host for agent communication. (Coming soon)
        </p>
      </div>

      <div className="setting-item">
        <label htmlFor="wsPort">WebSocket Port</label>
        <input
          type="number"
          id="wsPort"
          defaultValue={8080}
          placeholder="8080"
          disabled
        />
        <p className="setting-description">
          WebSocket server port. (Coming soon)
        </p>
      </div>
    </div>
  );
}

function ShortcutsSettings() {
  const shortcuts = [
    { key: '⌘ N', action: 'New Session' },
    { key: '⌘ F', action: 'Search Sessions' },
    { key: '⌘ 1', action: 'Terminal Tab' },
    { key: '⌘ 2', action: 'Tool Calls Tab' },
    { key: '⌘ 3', action: 'Metrics Tab' },
    { key: '⌘ ,', action: 'Settings' },
    { key: '⌘ W', action: 'Close Window' },
    { key: '⌘ Q', action: 'Quit' },
  ];

  return (
    <div className="settings-section">
      <h3>Keyboard Shortcuts</h3>

      <div className="shortcuts-list">
        {shortcuts.map((shortcut) => (
          <div key={shortcut.key} className="shortcut-item">
            <span className="shortcut-action">{shortcut.action}</span>
            <kbd className="shortcut-key">{shortcut.key}</kbd>
          </div>
        ))}
      </div>
    </div>
  );
}
