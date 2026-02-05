import { useEffect, useRef } from 'react';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { invoke } from '@tauri-apps/api/core';
import { listen, UnlistenFn } from '@tauri-apps/api/event';
import type { TerminalSettings } from '../../types';
import '@xterm/xterm/css/xterm.css';
import './TerminalView.css';

// Dark terminal theme - matching user's terminal colors
const terminalTheme = {
  background: '#0d0d0d',
  foreground: '#d4d4d4',
  cursor: '#c792ea',
  cursorAccent: '#0d0d0d',
  selectionBackground: '#3d3d3d',
  black: '#1e1e1e',
  red: '#ff5370',
  green: '#c3e88d',
  yellow: '#ffcb6b',
  blue: '#82aaff',
  magenta: '#c792ea',
  cyan: '#89ddff',
  white: '#d4d4d4',
  brightBlack: '#545454',
  brightRed: '#ff5370',
  brightGreen: '#c3e88d',
  brightYellow: '#ffcb6b',
  brightBlue: '#82aaff',
  brightMagenta: '#c792ea',
  brightCyan: '#89ddff',
  brightWhite: '#ffffff',
};

interface TerminalViewProps {
  sessionId: string;
  settings: TerminalSettings;
  isVisible?: boolean;
  storedOutput?: number[];
  isActiveSession?: boolean;
}

export function TerminalView({ sessionId, settings, isVisible = true, storedOutput, isActiveSession = false }: TerminalViewProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const terminalRef = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const initializedRef = useRef(false);
  const storedOutputWrittenRef = useRef(false);

  // Initialize terminal once
  useEffect(() => {
    if (!containerRef.current || initializedRef.current) return;

    // Create terminal instance
    const terminal = new Terminal({
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
      scrollback: settings.scrollback,
      theme: terminalTheme,
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
    terminal.open(containerRef.current);

    // Store refs
    terminalRef.current = terminal;
    fitAddonRef.current = fitAddon;
    initializedRef.current = true;

    // Fit after a brief delay to ensure container is sized
    setTimeout(() => {
      if (fitAddonRef.current && containerRef.current?.offsetWidth) {
        fitAddonRef.current.fit();
      }
    }, 50);

    // Handle input - only for active sessions
    if (isActiveSession) {
      terminal.onData((data) => {
        invoke('terminal_input', { sessionId, data }).catch(console.error);
      });
    }

    // Handle resize - only notify backend when dimensions actually change (for active sessions)
    let lastRows = 0;
    let lastCols = 0;
    if (isActiveSession) {
      terminal.onResize(({ rows, cols }) => {
        if (rows !== lastRows || cols !== lastCols) {
          lastRows = rows;
          lastCols = cols;
          invoke('terminal_resize', { sessionId, rows, cols }).catch(console.error);
        }
      });
    }

    // Listen for PTY output - only for active sessions
    let unlistenOutput: UnlistenFn | null = null;
    let unlistenEnded: UnlistenFn | null = null;

    if (isActiveSession) {
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
    }

    // Handle window resize with debounce
    let resizeTimeout: number | null = null;
    const handleResize = () => {
      if (resizeTimeout) clearTimeout(resizeTimeout);
      resizeTimeout = window.setTimeout(() => {
        if (fitAddonRef.current && containerRef.current?.offsetWidth) {
          fitAddonRef.current.fit();
        }
      }, 50);
    };
    window.addEventListener('resize', handleResize);

    // Observe container size changes with debounce
    let observerTimeout: number | null = null;
    const resizeObserver = new ResizeObserver(() => {
      if (observerTimeout) clearTimeout(observerTimeout);
      observerTimeout = window.setTimeout(() => {
        if (fitAddonRef.current && containerRef.current?.offsetWidth) {
          fitAddonRef.current.fit();
        }
      }, 50);
    });
    resizeObserver.observe(containerRef.current);

    // Cleanup
    return () => {
      window.removeEventListener('resize', handleResize);
      if (resizeTimeout) clearTimeout(resizeTimeout);
      if (observerTimeout) clearTimeout(observerTimeout);
      resizeObserver.disconnect();
      if (unlistenOutput) unlistenOutput();
      if (unlistenEnded) unlistenEnded();
      terminal.dispose();
      terminalRef.current = null;
      fitAddonRef.current = null;
      initializedRef.current = false;
      storedOutputWrittenRef.current = false;
    };
  }, [sessionId, isActiveSession]);

  // Update terminal settings when they change
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.options.fontFamily = settings.fontFamily;
      terminalRef.current.options.fontSize = settings.fontSize;
      terminalRef.current.options.scrollback = settings.scrollback;
      if (fitAddonRef.current && containerRef.current?.offsetWidth) {
        fitAddonRef.current.fit();
      }
    }
  }, [settings.fontFamily, settings.fontSize, settings.scrollback]);

  // Write stored output for historical sessions, or show placeholder message
  useEffect(() => {
    if (!terminalRef.current) return;
    if (storedOutputWrittenRef.current) return;
    if (isActiveSession) return; // Don't write stored output for active sessions

    if (storedOutput && storedOutput.length > 0) {
      // Write stored output to terminal
      terminalRef.current.write(new Uint8Array(storedOutput));
    } else {
      // Show placeholder for sessions without stored output
      terminalRef.current.write('\x1b[90m[Terminal history not available for this session]\x1b[0m\r\n');
      terminalRef.current.write('\x1b[90mThis session was created before terminal history storage was enabled.\x1b[0m\r\n');
    }
    storedOutputWrittenRef.current = true;

    // Fit terminal after writing
    setTimeout(() => {
      if (fitAddonRef.current && containerRef.current?.offsetWidth) {
        fitAddonRef.current.fit();
      }
    }, 50);
  }, [storedOutput, isActiveSession]);

  // Refit terminal when becoming visible
  useEffect(() => {
    if (isVisible && fitAddonRef.current && containerRef.current?.offsetWidth) {
      // Use multiple attempts to ensure proper fit after visibility change
      const fit = () => {
        if (fitAddonRef.current && containerRef.current?.offsetWidth) {
          fitAddonRef.current.fit();
        }
      };
      // Immediate fit
      fit();
      // Delayed fits to catch layout changes
      setTimeout(fit, 50);
      setTimeout(fit, 150);
    }
  }, [isVisible]);

  return (
    <div className="terminal-view">
      <div className="terminal-container" ref={containerRef} />
    </div>
  );
}
