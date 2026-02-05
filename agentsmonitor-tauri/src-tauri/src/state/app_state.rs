use crate::pty::PtyManager;
use crate::services::SessionPersistence;

pub struct AppState {
    pub persistence: SessionPersistence,
    pub pty_manager: PtyManager,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            persistence: SessionPersistence::default(),
            pty_manager: PtyManager::new(),
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}
