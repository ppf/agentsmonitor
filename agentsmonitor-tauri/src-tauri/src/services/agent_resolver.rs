use std::path::PathBuf;
use std::process::Command;

use crate::models::AgentType;

/// Resolves the executable path for an agent type
pub struct AgentResolver;

impl AgentResolver {
    /// Resolve the executable path for an agent type
    /// Checks in order: user override, common paths, which command
    pub fn resolve(agent_type: AgentType, override_path: Option<&str>) -> Option<PathBuf> {
        // Check user override first
        if let Some(path) = override_path {
            let path = PathBuf::from(path);
            if Self::is_executable(&path) {
                return Some(path);
            }
        }

        // Check candidate paths
        for path in Self::candidate_paths(agent_type) {
            if Self::is_executable(&path) {
                return Some(path);
            }
        }

        // Fallback to which command
        for name in agent_type.executable_names() {
            if let Some(path) = Self::which(name) {
                return Some(path);
            }
        }

        None
    }

    fn candidate_paths(agent_type: AgentType) -> Vec<PathBuf> {
        let home = dirs::home_dir().unwrap_or_default();
        let mut paths = Vec::new();

        let names = agent_type.executable_names();

        // Common installation directories
        let dirs = vec![
            home.join(".local/bin"),
            home.join("bin"),
            home.join(".npm-global/bin"),
            home.join(".npm/bin"),
            home.join(".volta/bin"),
            PathBuf::from("/opt/homebrew/bin"),
            PathBuf::from("/usr/local/bin"),
            PathBuf::from("/usr/bin"),
            PathBuf::from("/bin"),
            PathBuf::from("/opt/local/bin"),
        ];

        for dir in dirs {
            for name in &names {
                paths.push(dir.join(name));
            }
        }

        // Handle nvm paths
        let nvm_dir = home.join(".nvm/versions/node");
        if nvm_dir.exists() {
            if let Ok(entries) = std::fs::read_dir(&nvm_dir) {
                for entry in entries.flatten() {
                    let bin_dir = entry.path().join("bin");
                    for name in &names {
                        paths.push(bin_dir.join(name));
                    }
                }
            }
        }

        // Handle fnm paths
        let fnm_dir = home.join(".fnm/node-versions");
        if fnm_dir.exists() {
            if let Ok(entries) = std::fs::read_dir(&fnm_dir) {
                for entry in entries.flatten() {
                    let bin_dir = entry.path().join("installation/bin");
                    for name in &names {
                        paths.push(bin_dir.join(name));
                    }
                }
            }
        }

        // macOS fnm alternate location
        let fnm_alt = home.join("Library/Application Support/fnm/node-versions");
        if fnm_alt.exists() {
            if let Ok(entries) = std::fs::read_dir(&fnm_alt) {
                for entry in entries.flatten() {
                    let bin_dir = entry.path().join("installation/bin");
                    for name in &names {
                        paths.push(bin_dir.join(name));
                    }
                }
            }
        }

        paths
    }

    fn is_executable(path: &PathBuf) -> bool {
        if !path.exists() {
            return false;
        }

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            if let Ok(metadata) = std::fs::metadata(path) {
                return metadata.permissions().mode() & 0o111 != 0;
            }
        }

        #[cfg(not(unix))]
        {
            path.exists()
        }

        false
    }

    fn which(name: &str) -> Option<PathBuf> {
        let output = Command::new("/usr/bin/which")
            .arg(name)
            .output()
            .ok()?;

        if !output.status.success() {
            return None;
        }

        let path_str = String::from_utf8(output.stdout).ok()?;
        let path = PathBuf::from(path_str.trim());

        if path.exists() {
            Some(path)
        } else {
            None
        }
    }
}
