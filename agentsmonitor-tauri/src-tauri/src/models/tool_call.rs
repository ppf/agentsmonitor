use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolCall {
    pub id: Uuid,
    pub name: String,
    pub input: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output: Option<String>,
    pub started_at: DateTime<Utc>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub completed_at: Option<DateTime<Utc>>,
    pub status: ToolCallStatus,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl ToolCall {
    pub fn new(name: String, input: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            name,
            input,
            output: None,
            started_at: Utc::now(),
            completed_at: None,
            status: ToolCallStatus::Running,
            error: None,
        }
    }

    pub fn complete(&mut self, output: String) {
        self.output = Some(output);
        self.completed_at = Some(Utc::now());
        self.status = ToolCallStatus::Completed;
    }

    pub fn fail(&mut self, error: String) {
        self.error = Some(error);
        self.completed_at = Some(Utc::now());
        self.status = ToolCallStatus::Failed;
    }

    pub fn duration_ms(&self) -> Option<i64> {
        self.completed_at
            .map(|end| (end - self.started_at).num_milliseconds())
    }

    pub fn formatted_duration(&self) -> String {
        match self.duration_ms() {
            Some(ms) if ms < 1000 => format!("{}ms", ms),
            Some(ms) => format!("{:.2}s", ms as f64 / 1000.0),
            None => "...".to_string(),
        }
    }

    pub fn tool_icon(&self) -> &'static str {
        let name = self.name.to_lowercase();
        if name.contains("read") {
            "file-text"
        } else if name.contains("write") {
            "pencil"
        } else if name.contains("edit") {
            "edit"
        } else if name.contains("bash") || name.contains("shell") {
            "terminal"
        } else if name.contains("search") || name.contains("grep") {
            "search"
        } else if name.contains("web") || name.contains("fetch") {
            "globe"
        } else if name.contains("git") {
            "git-branch"
        } else if name.contains("task") || name.contains("agent") {
            "cpu"
        } else {
            "tool"
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ToolCallStatus {
    Pending,
    Running,
    Completed,
    Failed,
}

impl ToolCallStatus {
    pub fn icon(&self) -> &'static str {
        match self {
            Self::Pending => "clock",
            Self::Running => "play",
            Self::Completed => "check",
            Self::Failed => "x",
        }
    }

    pub fn color(&self) -> &'static str {
        match self {
            Self::Pending => "gray",
            Self::Running => "blue",
            Self::Completed => "green",
            Self::Failed => "red",
        }
    }
}
