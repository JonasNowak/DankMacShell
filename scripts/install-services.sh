#!/bin/sh
# Install or uninstall launchd LaunchAgents for DankMacShell, dms-gop, and dank-theme-engine.
set -eu

ACTION="install"
LOAD_AGENTS=1

for arg in "$@"; do
    case "$arg" in
        --install)
            ACTION="install"
            ;;
        --uninstall)
            ACTION="uninstall"
            ;;
        --no-load)
            LOAD_AGENTS=0
            ;;
        -h|--help)
            echo "Usage: $0 [--install|--uninstall] [--no-load]"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs"
DMS_SUPPORT="$HOME/Library/Application Support/DMS"
UID_VAL=$(id -u)

DMS_PLIST="$AGENTS_DIR/io.github.jonasnowak.dms.plist"
GOP_PLIST="$AGENTS_DIR/io.github.jonasnowak.dms-gop.plist"
DTE_PLIST="$AGENTS_DIR/io.github.jonasnowak.dank-theme-engine.plist"

unload_agent() {
    plist="$1"
    if [ "$LOAD_AGENTS" -eq 1 ] && [ -f "$plist" ]; then
        launchctl bootout "gui/$UID_VAL" "$plist" 2>/dev/null || launchctl unload "$plist" 2>/dev/null || true
    fi
}

load_agent() {
    plist="$1"
    if [ "$LOAD_AGENTS" -eq 1 ] && [ -f "$plist" ]; then
        launchctl bootout "gui/$UID_VAL" "$plist" 2>/dev/null || true
        launchctl bootstrap "gui/$UID_VAL" "$plist" 2>/dev/null || launchctl load -w "$plist" 2>/dev/null || true
    fi
}

if [ "$ACTION" = "uninstall" ]; then
    for p in "$DMS_PLIST" "$GOP_PLIST" "$DTE_PLIST"; do
        if [ -f "$p" ]; then
            unload_agent "$p"
            rm -f "$p"
            echo "==> Removed LaunchAgent: $p"
        fi
    done
    exit 0
fi

mkdir -p "$AGENTS_DIR" "$LOG_DIR" "$DMS_SUPPORT"

AGENT_PATH="$HOME/.local/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Resolve DankMacShell executable
DMS_APP="$HOME/Applications/DankMacShell.app"
if [ ! -d "$DMS_APP" ] && [ -d "/Applications/DankMacShell.app" ]; then
    DMS_APP="/Applications/DankMacShell.app"
fi
DMS_BIN="$DMS_APP/Contents/MacOS/DankMaterialShell"

if [ -x "$DMS_BIN" ]; then
    cat > "$DMS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>io.github.jonasnowak.dms</string>
	<key>ProgramArguments</key>
	<array>
		<string>$DMS_BIN</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$AGENT_PATH</string>
	</dict>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<dict>
		<key>SuccessfulExit</key>
		<false/>
	</dict>
	<key>ProcessType</key>
	<string>Interactive</string>
	<key>StandardOutPath</key>
	<string>$LOG_DIR/DankMacShell.log</string>
	<key>StandardErrorPath</key>
	<string>$LOG_DIR/DankMacShell.err.log</string>
</dict>
</plist>
EOF
    load_agent "$DMS_PLIST"
    echo "==> Installed LaunchAgent: $DMS_PLIST"
fi

# Resolve dms-gop binary if available
GOP_BIN=""
for candidate in "$HOME/.local/bin/dms-gop" "/opt/homebrew/bin/dms-gop" "/usr/local/bin/dms-gop" "$(command -v dms-gop 2>/dev/null || true)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        GOP_BIN="$candidate"
        break
    fi
done

if [ -n "$GOP_BIN" ]; then
    cat > "$GOP_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>io.github.jonasnowak.dms-gop</string>
	<key>ProgramArguments</key>
	<array>
		<string>$GOP_BIN</string>
		<string>server</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>API_PORT</key>
		<string>127.0.0.1:63484</string>
		<key>PATH</key>
		<string>$AGENT_PATH</string>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ProcessType</key>
	<string>Background</string>
	<key>StandardOutPath</key>
	<string>$LOG_DIR/dms-gop.log</string>
	<key>StandardErrorPath</key>
	<string>$LOG_DIR/dms-gop.err.log</string>
</dict>
</plist>
EOF
    load_agent "$GOP_PLIST"
    echo "==> Installed LaunchAgent: $GOP_PLIST"
fi

# Resolve dte binary if available
DTE_BIN=""
for candidate in "$HOME/.local/bin/dte" "/opt/homebrew/bin/dte" "/usr/local/bin/dte" "$(command -v dte 2>/dev/null || true)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        DTE_BIN="$candidate"
        break
    fi
done

if [ -n "$DTE_BIN" ]; then
    cat > "$DTE_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>io.github.jonasnowak.dank-theme-engine</string>
	<key>ProgramArguments</key>
	<array>
		<string>$DTE_BIN</string>
		<string>watch</string>
		<string>--doc</string>
		<string>$DMS_SUPPORT/theme.json</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$AGENT_PATH</string>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ProcessType</key>
	<string>Background</string>
	<key>StandardOutPath</key>
	<string>$LOG_DIR/dank-theme-engine.log</string>
	<key>StandardErrorPath</key>
	<string>$LOG_DIR/dank-theme-engine.err.log</string>
</dict>
</plist>
EOF
    load_agent "$DTE_PLIST"
    echo "==> Installed LaunchAgent: $DTE_PLIST"
fi
