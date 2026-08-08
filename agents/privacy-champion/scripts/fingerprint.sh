#!/usr/bin/env bash
# ── Privacy Champion: System Fingerprint ──────────────────────────────
# Detects OS, version, browsers, privilege level, and available tools.
# Output: JSON to stdout. Errors to stderr.
# Usage: ./fingerprint.sh [--json] [--pretty]

set -euo pipefail

OUTPUT_FORMAT="${1:-json}"  # json or json-pretty

# ── OS Detection ──────────────────────────────────────────────────────

detect_os() {
    local os_name="unknown"
    local os_version="unknown"
    local os_family="unknown"
    local desktop_env="unknown"
    local package_manager="unknown"

    case "$(uname -s)" in
        Darwin)
            os_name="macOS"
            os_family="macos"
            os_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
            # Detect package manager
            if command -v brew &>/dev/null; then
                package_manager="homebrew"
            elif command -v port &>/dev/null; then
                package_manager="macports"
            fi
            # Detect desktop (macOS only has Aqua, but check for third-party)
            desktop_env="Aqua"
            ;;
        Linux)
            os_family="linux"
            package_manager="unknown"

            # Detect distribution
            if [ -f /etc/os-release ]; then
                os_name=$(grep -E '^NAME=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')
                os_version=$(grep -E '^VERSION_ID=' /etc/os-release | head -1 | cut -d= -f2 | tr -d '"')
            elif [ -f /etc/lsb-release ]; then
                os_name=$(grep DISTRIB_ID /etc/lsb-release | cut -d= -f2)
                os_version=$(grep DISTRIB_RELEASE /etc/lsb-release | cut -d= -f2)
            else
                os_name="Linux"
                os_version=$(uname -r)
            fi

            # Detect package manager
            if command -v apt &>/dev/null; then package_manager="apt";
            elif command -v dnf &>/dev/null; then package_manager="dnf";
            elif command -v yum &>/dev/null; then package_manager="yum";
            elif command -v pacman &>/dev/null; then package_manager="pacman";
            elif command -v zypper &>/dev/null; then package_manager="zypper";
            elif command -v apk &>/dev/null; then package_manager="apk";
            fi

            # Detect desktop environment
            if [ -n "${XDG_CURRENT_DESKTOP:-}" ]; then
                desktop_env="$XDG_CURRENT_DESKTOP"
            elif [ -n "${DESKTOP_SESSION:-}" ]; then
                desktop_env="$DESKTOP_SESSION"
            elif pgrep -x gnome-shell &>/dev/null; then desktop_env="GNOME";
            elif pgrep -x plasmashell &>/dev/null; then desktop_env="KDE";
            elif pgrep -x xfdesktop &>/dev/null; then desktop_env="XFCE";
            elif pgrep -x cinnamon &>/dev/null; then desktop_env="Cinnamon";
            elif pgrep -x mate-panel &>/dev/null; then desktop_env="MATE";
            elif pgrep -x lxqt-panel &>/dev/null; then desktop_env="LXQt";
            fi
            ;;
        CYGWIN*|MINGW*|MSYS*)
            os_family="windows"
            os_name="Windows"
            # Try to get version from various sources
            if command -v powershell &>/dev/null; then
                os_version=$(powershell -Command "[System.Environment]::OSVersion.Version.ToString()" 2>/dev/null || echo "unknown")
            elif command -v systeminfo &>/dev/null; then
                os_version=$(systeminfo | grep -E '^OS Version' | sed 's/.*: //' || echo "unknown")
            else
                os_version="unknown"
            fi
            package_manager="winget"
            desktop_env="Windows Shell"
            ;;
        *)
            os_name=$(uname -s)
            os_version=$(uname -r)
            os_family="unknown"
            ;;
    esac

    echo "  \"os_name\": \"$os_name\","
    echo "  \"os_family\": \"$os_family\","
    echo "  \"os_version\": \"$os_version\","
    echo "  \"desktop_environment\": \"$desktop_env\","
    echo "  \"package_manager\": \"$package_manager\","
}

# ── Browser Detection ─────────────────────────────────────────────────

detect_browsers() {
    echo "  \"browsers\": ["

    local first=true
    local browsers=""

    # Chrome
    if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null || command -v chromium &>/dev/null || command -v chromium-browser &>/dev/null; then
        local chrome_path=""
        local chrome_ver="unknown"
        for p in google-chrome google-chrome-stable chromium chromium-browser; do
            if command -v "$p" &>/dev/null; then chrome_path=$(command -v "$p"); break; fi
        done
        if [ -n "$chrome_path" ]; then
            chrome_ver=$("$chrome_path" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        fi
        # Also check Windows paths
        if [ "$chrome_ver" = "unknown" ]; then
            for p in "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" "/c/Program Files/Google/Chrome/Application/chrome.exe"; do
                if [ -f "$p" ]; then chrome_ver="detected (version unavailable)"; break; fi
            done
        fi
        browsers="${browsers}{\"name\":\"Chrome\",\"version\":\"$chrome_ver\",\"path\":\"${chrome_path:-unknown}\"}"
        first=false
    fi

    # Firefox
    if command -v firefox &>/dev/null || [ -f "/mnt/c/Program Files/Mozilla Firefox/firefox.exe" ] || [ -f "/c/Program Files/Mozilla Firefox/firefox.exe" ]; then
        local ff_ver="unknown"
        if command -v firefox &>/dev/null; then
            ff_ver=$(firefox --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown")
        fi
        [ "$first" = false ] && browsers="${browsers},"
        browsers="${browsers}{\"name\":\"Firefox\",\"version\":\"$ff_ver\",\"path\":\"$(command -v firefox 2>/dev/null || echo "unknown")\"}"
        first=false
    fi

    # Edge
    if command -v microsoft-edge &>/dev/null; then
        local edge_ver=$("microsoft-edge" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        [ "$first" = false ] && browsers="${browsers},"
        browsers="${browsers}{\"name\":\"Edge\",\"version\":\"$edge_ver\",\"path\":\"$(command -v microsoft-edge)\"}"
        first=false
    elif [ -f "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" ] || [ -f "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" ]; then
        [ "$first" = false ] && browsers="${browsers},"
        browsers="${browsers}{\"name\":\"Edge\",\"version\":\"detected (version unavailable)\",\"path\":\"unknown\"}"
        first=false
    fi

    # Brave
    if command -v brave-browser &>/dev/null || command -v brave &>/dev/null; then
        local brave_path=$(command -v brave-browser 2>/dev/null || command -v brave 2>/dev/null || echo "unknown")
        local brave_ver="unknown"
        if [ "$brave_path" != "unknown" ]; then
            brave_ver=$("$brave_path" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        fi
        [ "$first" = false ] && browsers="${browsers},"
        browsers="${browsers}{\"name\":\"Brave\",\"version\":\"$brave_ver\",\"path\":\"$brave_path\"}"
        first=false
    fi

    # Safari (macOS only)
    if [ "$(uname -s)" = "Darwin" ] && [ -d "/Applications/Safari.app" ]; then
        local safari_ver=$(defaults read /Applications/Safari.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "unknown")
        [ "$first" = false ] && browsers="${browsers},"
        browsers="${browsers}{\"name\":\"Safari\",\"version\":\"$safari_ver\",\"path\":\"/Applications/Safari.app\"}"
        first=false
    fi

    echo "    $browsers"
    echo "  ],"
}

# ── Privilege Detection ────────────────────────────────────────────────

detect_privileges() {
    local level="standard"
    local can_sudo="false"
    local is_admin="false"

    if [ "$(id -u)" -eq 0 ]; then
        level="root"
        can_sudo="true"
        is_admin="true"
    elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        level="admin"
        can_sudo="true"
        is_admin="true"
    elif [ "$(uname -s)" = "Darwin" ] && groups 2>/dev/null | grep -q admin; then
        level="admin"
        can_sudo="true"
        is_admin="true"
    fi

    echo "  \"privilege_level\": \"$level\","
    echo "  \"can_sudo\": $can_sudo,"
    echo "  \"is_admin\": $is_admin,"
}

# ── Tool Detection ─────────────────────────────────────────────────────

detect_tools() {
    echo "  \"available_tools\": {"

    local tools=("bash" "curl" "wget" "jq" "python3" "python" "perl" "powershell" "reg" "systemctl" "launchctl" "defaults" "apt" "dnf" "winget" "brew" "git")
    local first=true

    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            local tool_path
            tool_path=$(command -v "$tool" 2>/dev/null)
            [ "$first" = false ] && echo ","
            printf '    "%s": "%s"' "$tool" "$tool_path"
            first=false
        fi
    done

    echo ""
    echo "  }"
}

# ── Main ───────────────────────────────────────────────────────────────

echo "{"
echo "  \"fingerprint_version\": \"1.0\","
echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
echo "  \"hostname\": \"$(hostname 2>/dev/null || echo "unknown")\","
detect_os
detect_browsers
detect_privileges
detect_tools
echo "}"