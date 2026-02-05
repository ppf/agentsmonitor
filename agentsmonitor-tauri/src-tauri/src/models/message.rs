use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Message {
    pub id: Uuid,
    pub role: MessageRole,
    pub content: String,
    pub timestamp: DateTime<Utc>,
    #[serde(default)]
    pub is_streaming: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tool_use_id: Option<Uuid>,
}

impl Message {
    pub fn new(role: MessageRole, content: String) -> Self {
        Self {
            id: Uuid::new_v4(),
            role,
            content,
            timestamp: Utc::now(),
            is_streaming: false,
            tool_use_id: None,
        }
    }

    pub fn user(content: String) -> Self {
        Self::new(MessageRole::User, content)
    }

    pub fn assistant(content: String) -> Self {
        Self::new(MessageRole::Assistant, content)
    }

    pub fn system(content: String) -> Self {
        Self::new(MessageRole::System, content)
    }

    pub fn tool(content: String, tool_use_id: Uuid) -> Self {
        Self {
            id: Uuid::new_v4(),
            role: MessageRole::Tool,
            content,
            timestamp: Utc::now(),
            is_streaming: false,
            tool_use_id: Some(tool_use_id),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum MessageRole {
    User,
    Assistant,
    System,
    Tool,
}

impl MessageRole {
    pub fn icon(&self) -> &'static str {
        match self {
            Self::User => "user",
            Self::Assistant => "brain",
            Self::System => "settings",
            Self::Tool => "wrench",
        }
    }

    pub fn color(&self) -> &'static str {
        match self {
            Self::User => "blue",
            Self::Assistant => "purple",
            Self::System => "gray",
            Self::Tool => "orange",
        }
    }
}
