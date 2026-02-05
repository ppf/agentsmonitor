use std::path::PathBuf;
use tokio::fs;
use uuid::Uuid;

use crate::models::{Session, SessionSummary};

#[derive(Debug, thiserror::Error)]
pub enum PersistenceError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("Session not found: {0}")]
    NotFound(Uuid),
}

pub struct SessionPersistence {
    sessions_dir: PathBuf,
}

impl SessionPersistence {
    pub fn new() -> Result<Self, PersistenceError> {
        let base_dir = directories::BaseDirs::new()
            .map(|d| d.data_dir().to_path_buf())
            .unwrap_or_else(|| PathBuf::from("."));

        let sessions_dir = base_dir.join("AgentsMonitor").join("Sessions");
        Ok(Self { sessions_dir })
    }

    pub fn with_path(sessions_dir: PathBuf) -> Self {
        Self { sessions_dir }
    }

    async fn ensure_dir(&self) -> Result<(), PersistenceError> {
        fs::create_dir_all(&self.sessions_dir).await?;
        Ok(())
    }

    fn session_path(&self, id: Uuid) -> PathBuf {
        // Use uppercase UUID to match Swift app's naming convention
        self.sessions_dir.join(format!("{}.json", id.to_string().to_uppercase()))
    }

    pub async fn save(&self, session: &Session) -> Result<(), PersistenceError> {
        self.ensure_dir().await?;
        let path = self.session_path(session.id);
        let json = serde_json::to_string_pretty(session)?;
        fs::write(path, json).await?;
        Ok(())
    }

    pub async fn load(&self, id: Uuid) -> Result<Session, PersistenceError> {
        let path = self.session_path(id);
        if !path.exists() {
            return Err(PersistenceError::NotFound(id));
        }
        let json = fs::read_to_string(path).await?;
        let session: Session = serde_json::from_str(&json)?;
        Ok(session)
    }

    pub async fn load_summary(&self, id: Uuid) -> Result<SessionSummary, PersistenceError> {
        let path = self.session_path(id);
        if !path.exists() {
            return Err(PersistenceError::NotFound(id));
        }
        let json = fs::read_to_string(path).await?;
        let summary: SessionSummary = serde_json::from_str(&json)?;
        Ok(summary)
    }

    pub async fn load_all(&self) -> Result<Vec<Session>, PersistenceError> {
        self.ensure_dir().await?;

        let mut sessions = Vec::new();
        let mut entries = fs::read_dir(&self.sessions_dir).await?;

        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().map_or(false, |e| e == "json") {
                match fs::read_to_string(&path).await {
                    Ok(json) => match serde_json::from_str::<Session>(&json) {
                        Ok(session) => sessions.push(session),
                        Err(e) => {
                            eprintln!("Failed to parse session {}: {}", path.display(), e);
                        }
                    },
                    Err(e) => {
                        eprintln!("Failed to read session {}: {}", path.display(), e);
                    }
                }
            }
        }

        // Sort by started_at descending (newest first)
        sessions.sort_by(|a, b| b.started_at.cmp(&a.started_at));
        Ok(sessions)
    }

    pub async fn load_all_summaries(&self) -> Result<Vec<SessionSummary>, PersistenceError> {
        self.ensure_dir().await?;

        let mut summaries = Vec::new();
        let mut entries = fs::read_dir(&self.sessions_dir).await?;

        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().map_or(false, |e| e == "json") {
                match fs::read_to_string(&path).await {
                    Ok(json) => match serde_json::from_str::<SessionSummary>(&json) {
                        Ok(summary) => summaries.push(summary),
                        Err(e) => {
                            eprintln!("Failed to parse session summary {}: {}", path.display(), e);
                        }
                    },
                    Err(e) => {
                        eprintln!("Failed to read session {}: {}", path.display(), e);
                    }
                }
            }
        }

        // Sort by started_at descending (newest first)
        summaries.sort_by(|a, b| b.started_at.cmp(&a.started_at));
        Ok(summaries)
    }

    pub async fn delete(&self, id: Uuid) -> Result<(), PersistenceError> {
        let path = self.session_path(id);
        if path.exists() {
            fs::remove_file(path).await?;
        }
        Ok(())
    }

    pub async fn exists(&self, id: Uuid) -> bool {
        self.session_path(id).exists()
    }
}

impl Default for SessionPersistence {
    fn default() -> Self {
        Self::new().expect("Failed to create persistence")
    }
}
