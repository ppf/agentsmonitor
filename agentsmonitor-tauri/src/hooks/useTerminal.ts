import { useEffect, useRef, useCallback } from 'react';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { invoke } from '@tauri-apps/api/core';
import { listen, UnlistenFn } from '@tauri-apps/api/event';
import type { TerminalSettings } from '../types';

// Catppuccin Mocha xterm theme
const catppuccinTheme = {
  background: '#1e1e2e',
  foreground: '#cdd6f4',
  cursor: '#f5e0dc',
  cursorAccent: '#1e1e2e',
  selectionBackground: '#45475a',
  black: '#45475a',
  red: '#f38ba8',
  green: '#a6e3a1',
  yellow: '#f9e2af',
  blue: '#89b4fa',
  magenta: '#cba6f7',
  cyan: '#94e2d5',
  white: '#bac2de',
  brightBlack: '#585b70',
  brightRed: '#f38ba8',
  brightGreen: '#a6e3a1',
  brightYellow: '#f9e2af',
  brightBlue: '#89b4fa',
  brightMagenta: '#cba6f7',
  brightCyan: '#94e2d5',
  brightWhite: '#a6adc8',
};

interface UseTerminalOptions {
  sessionId: string;
  settings: TerminalSettings;
  onData?: (data: string) => void;
  onResize?: (rows: number, cols: number) => void;
}

export function useTerminal({
  sessionId,
  settings,
  onData,
  onResize,
}: UseTerminalOptions) {
  const terminalRef = useRef<HTMLDivElement | null>(null);
  const xtermRef = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);

  const writeToTerminal = useCallback((data: Uint8Array | string) => {
    if (xtermRef.current) {
      xtermRef.current.write(data);
    }
  }, []);

  const fitTerminal = useCallback(() => {
    if (fitAddonRef.current) {
      fitAddonRef.current.fit();
    }
  }, []);

  const focusTerminal = useCallback(() => {
    if (xtermRef.current) {
      xtermRef.current.focus();
    }
  }, []);

  const clearTerminal = useCallback(() => {
    if (xtermRef.current) {
      xtermRef.current.clear();
    }
  }, []);

  useEffect(() => {
    if (!terminalRef.current) return;

    // Create terminal instance
    const terminal = new Terminal({
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
      scrollback: settings.scrollback,
      theme: catppuccinTheme,
      cursorBlink: true,
      cursorStyle: 'block',
      allowTransparency: true,
      convertEol: true,
    });

    // Create addons
    const fitAddon = new FitAddon();
    const webLinksAddon = new WebLinksAddon();

    terminal.loadAddon(fitAddon);
    terminal.loadAddon(webLinksAddon);

    // Open terminal
    terminal.open(terminalRef.current);
    fitAddon.fit();

    // Store refs
    xtermRef.current = terminal;
    fitAddonRef.current = fitAddon;

    // Handle input
    terminal.onData((data) => {
      onData?.(data);
      // Send to Rust PTY
      invoke('terminal_input', { sessionId, data }).catch(console.error);
    });

    // Handle resize
    terminal.onResize(({ rows, cols }) => {
      onResize?.(rows, cols);
      // Send to Rust PTY
      invoke('terminal_resize', { sessionId, rows, cols }).catch(console.error);
    });

    // Listen for PTY output
    let unlistenOutput: UnlistenFn | null = null;
    let unlistenEnded: UnlistenFn | null = null;

    listen<number[]>(`terminal_output_${sessionId}`, (event) => {
      terminal.write(new Uint8Array(event.payload));
    }).then((fn) => {
      unlistenOutput = fn;
    });

    listen(`terminal_ended_${sessionId}`, () => {
      terminal.write('\r\n\x1b[90m[Process ended]\x1b[0m\r\n');
    }).then((fn) => {
      unlistenEnded = fn;
    });

    // Handle window resize
    const handleResize = () => {
      fitAddon.fit();
    };
    window.addEventListener('resize', handleResize);

    // Cleanup
    return () => {
      window.removeEventListener('resize', handleResize);
      if (unlistenOutput) unlistenOutput();
      if (unlistenEnded) unlistenEnded();
      terminal.dispose();
      xtermRef.current = null;
      fitAddonRef.current = null;
    };
  }, [sessionId, settings.fontFamily, settings.fontSize, settings.scrollback]);

  return {
    terminalRef,
    writeToTerminal,
    fitTerminal,
    focusTerminal,
    clearTerminal,
  };
}
