use std::path::PathBuf;
use tauri::{AppHandle, State};
use uuid::Uuid;

use crate::models::AgentType;
use crate::state::AppState;

#[tauri::command]
pub async fn spawn_terminal(
    session_id: String,
    agent_type: AgentType,
    working_directory: String,
    override_executable: Option<String>,
    app: AppHandle,
    state: State<'_, AppState>,
) -> Result<i32, String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;
    let cwd = PathBuf::from(working_directory);

    state
        .pty_manager
        .spawn(id, agent_type, cwd, override_executable.as_deref(), app)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn terminal_input(
    session_id: String,
    data: String,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;

    state
        .pty_manager
        .write(id, data.as_bytes())
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn terminal_input_bytes(
    session_id: String,
    data: Vec<u8>,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;

    state
        .pty_manager
        .write(id, &data)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn terminal_resize(
    session_id: String,
    rows: u16,
    cols: u16,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;

    state
        .pty_manager
        .resize(id, rows, cols)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn terminal_terminate(
    session_id: String,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;

    state
        .pty_manager
        .terminate(id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn terminal_is_running(
    session_id: String,
    state: State<'_, AppState>,
) -> Result<bool, String> {
    let id = Uuid::parse_str(&session_id).map_err(|e| e.to_string())?;
    Ok(state.pty_manager.is_running(id).await)
}

#[tauri::command]
pub fn resolve_agent_executable(
    agent_type: AgentType,
    override_path: Option<String>,
) -> Result<Option<String>, String> {
    use crate::services::AgentResolver;

    let path = AgentResolver::resolve(agent_type, override_path.as_deref());
    Ok(path.map(|p| p.to_string_lossy().to_string()))
}
