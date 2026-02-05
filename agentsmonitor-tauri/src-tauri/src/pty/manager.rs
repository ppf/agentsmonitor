use portable_pty::{native_pty_system, CommandBuilder, PtySize, PtySystem};
use std::collections::HashMap;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::sync::Arc;
use tauri::{AppHandle, Emitter};
use tokio::sync::Mutex;
use tokio::task::JoinHandle;
use uuid::Uuid;

use crate::models::AgentType;
use crate::services::AgentResolver;

const BATCH_SIZE: usize = 4096;
const BATCH_INTERVAL_MS: u64 = 16; // ~60fps

#[derive(Debug, thiserror::Error)]
pub enum PtyError {
    #[error("PTY error: {0}")]
    Pty(String),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Session not found: {0}")]
    NotFound(Uuid),
    #[error("Executable not found for agent type")]
    ExecutableNotFound,
    #[error("Process spawn failed: {0}")]
    SpawnFailed(String),
}

struct TerminalSession {
    #[allow(dead_code)]
    session_id: Uuid,
    writer: Box<dyn Write + Send>,
    reader_task: JoinHandle<()>,
    child: Box<dyn portable_pty::Child + Send + Sync>,
    master_pty: Box<dyn portable_pty::MasterPty + Send>,
}

pub struct PtyManager {
    sessions: Arc<Mutex<HashMap<Uuid, TerminalSession>>>,
}

impl PtyManager {
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub async fn spawn(
        &self,
        session_id: Uuid,
        agent_type: AgentType,
        working_directory: PathBuf,
        override_executable: Option<&str>,
        app: AppHandle,
    ) -> Result<i32, PtyError> {
        // Resolve executable path
        let executable = AgentResolver::resolve(agent_type, override_executable)
            .ok_or(PtyError::ExecutableNotFound)?;

        // Create PTY pair
        let pty_system = native_pty_system();
        let pair = pty_system
            .openpty(PtySize {
                rows: 24,
                cols: 80,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| PtyError::Pty(e.to_string()))?;

        // Build command
        let mut cmd = CommandBuilder::new(&executable);
        cmd.cwd(&working_directory);
        cmd.env("TERM", "xterm-256color");
        cmd.env("COLORTERM", "truecolor");
        cmd.env("LANG", "en_US.UTF-8");
        cmd.env("TERM_PROGRAM", "AgentsMonitor");
        cmd.env("TERM_PROGRAM_VERSION", "1.0.0");

        // For Codex: disable terminal capability detection that causes issues
        if matches!(agent_type, AgentType::Codex) {
            cmd.env("NO_COLOR", "0"); // Keep colors but signal we're in a special environment
            cmd.env("CODEX_DISABLE_CURSOR_QUERY", "1"); // Custom env in case Codex checks this
        }

        // Add default args
        for arg in agent_type.default_args() {
            cmd.arg(arg);
        }

        // Spawn process
        let child = pair
            .slave
            .spawn_command(cmd)
            .map_err(|e| PtyError::SpawnFailed(e.to_string()))?;

        let process_id = child.process_id().unwrap_or(0) as i32;

        // Get reader and writer
        let mut reader = pair.master.try_clone_reader()
            .map_err(|e| PtyError::Pty(e.to_string()))?;
        let writer = pair.master.take_writer()
            .map_err(|e| PtyError::Pty(e.to_string()))?;

        // Spawn reader task with batched output
        let event_name = format!("terminal_output_{}", session_id);
        let reader_task = tokio::task::spawn_blocking(move || {
            let mut buffer = vec![0u8; BATCH_SIZE];
            let mut batch = Vec::with_capacity(BATCH_SIZE * 2);
            let mut last_emit = std::time::Instant::now();

            loop {
                match reader.read(&mut buffer) {
                    Ok(0) => break, // EOF
                    Ok(n) => {
                        batch.extend_from_slice(&buffer[..n]);

                        let elapsed = last_emit.elapsed().as_millis() as u64;
                        if batch.len() >= BATCH_SIZE || elapsed >= BATCH_INTERVAL_MS {
                            let data = std::mem::take(&mut batch);
                            let _ = app.emit(&event_name, data);
                            last_emit = std::time::Instant::now();
                        }
                    }
                    Err(e) => {
                        eprintln!("PTY read error: {}", e);
                        break;
                    }
                }
            }

            // Emit remaining data
            if !batch.is_empty() {
                let _ = app.emit(&event_name, batch);
            }

            // Emit session ended event
            let _ = app.emit(&format!("terminal_ended_{}", session_id), ());
        });

        // Store session
        let terminal_session = TerminalSession {
            session_id,
            writer,
            reader_task,
            child,
            master_pty: pair.master,
        };

        self.sessions.lock().await.insert(session_id, terminal_session);

        // For Codex: send a pre-emptive cursor position response to handle early DSR queries
        // DSR query is \x1b[6n, response format is \x1b[<row>;<col>R
        if matches!(agent_type, AgentType::Codex) {
            // Give a small delay for process to start, then send cursor position
            tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
            let _ = self.write(session_id, b"\x1b[1;1R").await;
        }

        Ok(process_id)
    }

    pub async fn write(&self, session_id: Uuid, data: &[u8]) -> Result<(), PtyError> {
        let mut sessions = self.sessions.lock().await;
        let session = sessions
            .get_mut(&session_id)
            .ok_or(PtyError::NotFound(session_id))?;

        session.writer.write_all(data)?;
        session.writer.flush()?;
        Ok(())
    }

    pub async fn resize(&self, session_id: Uuid, rows: u16, cols: u16) -> Result<(), PtyError> {
        let sessions = self.sessions.lock().await;
        let session = sessions
            .get(&session_id)
            .ok_or(PtyError::NotFound(session_id))?;

        session.master_pty
            .resize(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| PtyError::Pty(e.to_string()))?;

        Ok(())
    }

    pub async fn terminate(&self, session_id: Uuid) -> Result<(), PtyError> {
        let mut sessions = self.sessions.lock().await;

        if let Some(mut session) = sessions.remove(&session_id) {
            // Try graceful termination first (SIGTERM)
            #[cfg(unix)]
            if let Some(pid) = session.child.process_id() {
                unsafe {
                    libc::kill(pid as i32, libc::SIGTERM);
                }
            }

            // Wait a bit for graceful shutdown
            tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

            // Force kill if still running
            if session.child.try_wait().map_err(|e| PtyError::Pty(e.to_string()))?.is_none() {
                #[cfg(unix)]
                if let Some(pid) = session.child.process_id() {
                    unsafe {
                        libc::kill(pid as i32, libc::SIGKILL);
                    }
                }
                let _ = session.child.kill();
            }

            // Cancel reader task
            session.reader_task.abort();
        }

        Ok(())
    }

    pub async fn is_running(&self, session_id: Uuid) -> bool {
        let mut sessions = self.sessions.lock().await;
        if let Some(session) = sessions.get_mut(&session_id) {
            session.child
                .try_wait()
                .map(|status| status.is_none())
                .unwrap_or(false)
        } else {
            false
        }
    }

    pub async fn cleanup_finished(&self) -> Vec<Uuid> {
        let mut sessions = self.sessions.lock().await;
        let mut finished = Vec::new();

        sessions.retain(|id, session| {
            match session.child.try_wait() {
                Ok(Some(_)) => {
                    finished.push(*id);
                    session.reader_task.abort();
                    false
                }
                _ => true,
            }
        });

        finished
    }
}

impl Default for PtyManager {
    fn default() -> Self {
        Self::new()
    }
}
