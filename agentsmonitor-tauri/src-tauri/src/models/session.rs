use base64::{engine::general_purpose::STANDARD, Engine};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use uuid::Uuid;

use super::{Message, ToolCall};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Session {
    pub id: Uuid,
    pub name: String,
    pub status: SessionStatus,
    pub agent_type: AgentType,
    pub started_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ended_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub messages: Vec<Message>,
    #[serde(default)]
    pub tool_calls: Vec<ToolCall>,
    #[serde(default)]
    pub metrics: SessionMetrics,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub working_directory: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub process_id: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
    #[serde(default)]
    pub is_external_process: bool,
    #[serde(default = "default_true")]
    pub is_fully_loaded: bool,
    #[serde(
        skip_serializing_if = "Option::is_none",
        serialize_with = "serialize_terminal_output",
        deserialize_with = "deserialize_terminal_output",
        default
    )]
    pub terminal_output: Option<Vec<u8>>,
}

fn serialize_terminal_output<S>(data: &Option<Vec<u8>>, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    match data {
        Some(bytes) => serializer.serialize_str(&STANDARD.encode(bytes)),
        None => serializer.serialize_none(),
    }
}

fn deserialize_terminal_output<'de, D>(deserializer: D) -> Result<Option<Vec<u8>>, D::Error>
where
    D: Deserializer<'de>,
{
    let opt: Option<String> = Option::deserialize(deserializer)?;
    match opt {
        Some(s) => STANDARD
            .decode(&s)
            .map(Some)
            .map_err(serde::de::Error::custom),
        None => Ok(None),
    }
}

fn default_true() -> bool {
    true
}

impl Session {
    pub fn new(name: String, agent_type: AgentType) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            status: SessionStatus::Running,
            agent_type,
            started_at: Utc::now(),
            ended_at: None,
            messages: Vec::new(),
            tool_calls: Vec::new(),
            metrics: SessionMetrics::default(),
            working_directory: None,
            process_id: None,
            error_message: None,
            is_external_process: false,
            is_fully_loaded: true,
            terminal_output: None,
        }
    }

    pub fn duration_secs(&self) -> f64 {
        let end = self.ended_at.unwrap_or_else(Utc::now);
        (end - self.started_at).num_milliseconds() as f64 / 1000.0
    }

    pub fn formatted_duration(&self) -> String {
        let secs = self.duration_secs();
        if secs < 60.0 {
            format!("{:.0}s", secs)
        } else if secs < 3600.0 {
            format!("{}m {}s", (secs / 60.0) as i32, (secs % 60.0) as i32)
        } else {
            let hours = (secs / 3600.0) as i32;
            let mins = ((secs % 3600.0) / 60.0) as i32;
            format!("{}h {}m", hours, mins)
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionSummary {
    pub id: Uuid,
    pub name: String,
    pub status: SessionStatus,
    pub agent_type: AgentType,
    pub started_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ended_at: Option<DateTime<Utc>>,
    #[serde(default)]
    pub metrics: SessionMetrics,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub working_directory: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub process_id: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
    #[serde(default)]
    pub is_external_process: bool,
}

impl From<&Session> for SessionSummary {
    fn from(session: &Session) -> Self {
        Self {
            id: session.id,
            name: session.name.clone(),
            status: session.status.clone(),
            agent_type: session.agent_type.clone(),
            started_at: session.started_at,
            ended_at: session.ended_at,
            metrics: session.metrics.clone(),
            working_directory: session.working_directory.clone(),
            process_id: session.process_id,
            error_message: session.error_message.clone(),
            is_external_process: session.is_external_process,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SessionStatus {
    Running,
    Paused,
    Completed,
    Failed,
    Waiting,
    Cancelled,
}

impl SessionStatus {
    pub fn color(&self) -> &'static str {
        match self {
            Self::Running => "green",
            Self::Paused => "yellow",
            Self::Completed => "blue",
            Self::Failed => "red",
            Self::Waiting => "orange",
            Self::Cancelled => "gray",
        }
    }

    pub fn icon(&self) -> &'static str {
        match self {
            Self::Running => "play-circle",
            Self::Paused => "pause-circle",
            Self::Completed => "check-circle",
            Self::Failed => "x-circle",
            Self::Waiting => "clock",
            Self::Cancelled => "stop-circle",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AgentType {
    #[serde(alias = "Claude Code", alias = "claudeCode")]
    ClaudeCode,
    #[serde(alias = "codex")]
    Codex,
    #[serde(alias = "Custom Agent", alias = "custom")]
    Custom,
}

impl AgentType {
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::ClaudeCode => "Claude Code",
            Self::Codex => "Codex",
            Self::Custom => "Custom Agent",
        }
    }

    pub fn icon(&self) -> &'static str {
        match self {
            Self::ClaudeCode => "brain",
            Self::Codex => "code",
            Self::Custom => "cpu",
        }
    }

    pub fn color(&self) -> &'static str {
        match self {
            Self::ClaudeCode => "purple",
            Self::Codex => "green",
            Self::Custom => "blue",
        }
    }

    pub fn default_executable(&self) -> &'static str {
        match self {
            Self::ClaudeCode => "claude",
            Self::Codex => "codex",
            Self::Custom => "agent",
        }
    }

    pub fn executable_names(&self) -> Vec<&'static str> {
        match self {
            Self::ClaudeCode => vec!["claude", "claude-code", "claude_code"],
            Self::Codex => vec!["codex", "openai-codex"],
            Self::Custom => vec!["agent"],
        }
    }

    pub fn default_args(&self) -> Vec<&'static str> {
        match self {
            Self::ClaudeCode => vec![],
            Self::Codex => vec!["--no-alt-screen"],
            Self::Custom => vec![],
        }
    }

    pub fn is_terminal_based(&self) -> bool {
        match self {
            Self::ClaudeCode | Self::Codex => true,
            Self::Custom => false,
        }
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionMetrics {
    #[serde(default)]
    pub total_tokens: i64,
    #[serde(default)]
    pub input_tokens: i64,
    #[serde(default)]
    pub output_tokens: i64,
    #[serde(default)]
    pub tool_call_count: i32,
    #[serde(default)]
    pub error_count: i32,
    #[serde(default)]
    pub api_calls: i32,
    #[serde(default)]
    pub cache_read_tokens: i64,
    #[serde(default)]
    pub cache_write_tokens: i64,
}

impl SessionMetrics {
    pub fn formatted_tokens(&self) -> String {
        let total = self.total_tokens;
        if total >= 1_000_000 {
            format!("{:.1}M", total as f64 / 1_000_000.0)
        } else if total >= 1_000 {
            format!("{:.1}K", total as f64 / 1_000.0)
        } else {
            total.to_string()
        }
    }
}
