import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import type {
  DetailTab,
  TerminalSettings,
  AppSettings,
} from '../types';

interface AppState {
  // UI state
  isSidebarVisible: boolean;
  selectedDetailTab: DetailTab;
  isSettingsOpen: boolean;
  isNewSessionOpen: boolean;

  // Settings
  settings: AppSettings;

  // Actions
  toggleSidebar: () => void;
  setSidebarVisible: (visible: boolean) => void;
  setDetailTab: (tab: DetailTab) => void;
  setSettingsOpen: (open: boolean) => void;
  setNewSessionOpen: (open: boolean) => void;
  updateSettings: (updates: Partial<AppSettings>) => void;
  updateTerminalSettings: (updates: Partial<TerminalSettings>) => void;
}

const defaultSettings: AppSettings = {
  terminalSettings: {
    theme: 'dark',
    fontFamily: 'SF Mono, Menlo, Monaco, monospace',
    fontSize: 13,
    scrollback: 1000,
  },
  defaultWorkingDirectory: '',
  showMenuBarExtra: true,
  compactMode: false,
  appearance: 'system',
};

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      // Initial UI state
      isSidebarVisible: true,
      selectedDetailTab: 'terminal',
      isSettingsOpen: false,
      isNewSessionOpen: false,

      // Initial settings
      settings: defaultSettings,

      // Actions
      toggleSidebar: () =>
        set((state) => ({ isSidebarVisible: !state.isSidebarVisible })),

      setSidebarVisible: (visible) => set({ isSidebarVisible: visible }),

      setDetailTab: (tab) => set({ selectedDetailTab: tab }),

      setSettingsOpen: (open) => set({ isSettingsOpen: open }),

      setNewSessionOpen: (open) => set({ isNewSessionOpen: open }),

      updateSettings: (updates) =>
        set((state) => ({
          settings: { ...state.settings, ...updates },
        })),

      updateTerminalSettings: (updates) =>
        set((state) => ({
          settings: {
            ...state.settings,
            terminalSettings: {
              ...state.settings.terminalSettings,
              ...updates,
            },
          },
        })),
    }),
    {
      name: 'agentsmonitor-app-storage',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        settings: state.settings,
        isSidebarVisible: state.isSidebarVisible,
        selectedDetailTab: state.selectedDetailTab,
      }),
    }
  )
);
