import { useEffect } from 'react';
import { listen, UnlistenFn } from '@tauri-apps/api/event';

export function useTauriEvent<T>(
  eventName: string,
  handler: (payload: T) => void
) {
  useEffect(() => {
    let unlisten: UnlistenFn | null = null;

    listen<T>(eventName, (event) => {
      handler(event.payload);
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      if (unlisten) {
        unlisten();
      }
    };
  }, [eventName, handler]);
}

export function useTerminalOutput(
  sessionId: string | null,
  onData: (data: Uint8Array) => void
) {
  useEffect(() => {
    if (!sessionId) return;

    let unlisten: UnlistenFn | null = null;

    listen<number[]>(`terminal_output_${sessionId}`, (event) => {
      onData(new Uint8Array(event.payload));
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      if (unlisten) {
        unlisten();
      }
    };
  }, [sessionId, onData]);
}

export function useTerminalEnded(
  sessionId: string | null,
  onEnded: () => void
) {
  useEffect(() => {
    if (!sessionId) return;

    let unlisten: UnlistenFn | null = null;

    listen(`terminal_ended_${sessionId}`, () => {
      onEnded();
    }).then((fn) => {
      unlisten = fn;
    });

    return () => {
      if (unlisten) {
        unlisten();
      }
    };
  }, [sessionId, onEnded]);
}
