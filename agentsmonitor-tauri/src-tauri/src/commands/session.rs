use tauri::State;
use uuid::Uuid;

use crate::models::{AgentType, Session, SessionStatus, SessionSummary};
use crate::state::AppState;

#[tauri::command]
pub async fn get_sessions(state: State<'_, AppState>) -> Result<Vec<Session>, String> {
    state
        .persistence
        .load_all()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_session_summaries(state: State<'_, AppState>) -> Result<Vec<SessionSummary>, String> {
    state
        .persistence
        .load_all_summaries()
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_session(session_id: String, state: State<'_, AppState>) -> Result<Session, String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;
    state
        .persistence
        .load(id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn create_session(
    name: String,
    agent_type: AgentType,
    working_directory: Option<String>,
    state: State<'_, AppState>,
) -> Result<Session, String> {
    let mut session = Session::new(name, agent_type);
    session.working_directory = working_directory;

    state
        .persistence
        .save(&session)
        .await
        .map_err(|e| e.to_string())?;

    Ok(session)
}

#[tauri::command]
pub async fn update_session(
    session_id: String,
    status: Option<SessionStatus>,
    error_message: Option<String>,
    state: State<'_, AppState>,
) -> Result<Session, String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;
    let mut session = state
        .persistence
        .load(id)
        .await
        .map_err(|e| e.to_string())?;

    if let Some(s) = status {
        session.status = s;
        if matches!(s, SessionStatus::Completed | SessionStatus::Failed | SessionStatus::Cancelled) {
            session.ended_at = Some(chrono::Utc::now());
        }
    }

    if let Some(err) = error_message {
        session.error_message = Some(err);
    }

    state
        .persistence
        .save(&session)
        .await
        .map_err(|e| e.to_string())?;

    Ok(session)
}

#[tauri::command]
pub async fn delete_session(session_id: String, state: State<'_, AppState>) -> Result<(), String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;

    // Terminate PTY if running
    let _ = state.pty_manager.terminate(id).await;

    state
        .persistence
        .delete(id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn save_session(session: Session, state: State<'_, AppState>) -> Result<(), String> {
    state
        .persistence
        .save(&session)
        .await
        .map_err(|e| e.to_string())
}
