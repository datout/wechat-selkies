#!/bin/bash

# configure openbox dock mode for stalonetray
if [ ! -f /config/.config/openbox/rc.xml ] || grep -A20 "<dock>" /config/.config/openbox/rc.xml | grep -q "<noStrut>no</noStrut>"; then
    mkdir -p /config/.config/openbox
    [ ! -f /config/.config/openbox/rc.xml ] && cp /etc/xdg/openbox/rc.xml /config/.config/openbox/
    sed -i '/<dock>/,/<\/dock>/s/<noStrut>no<\/noStrut>/<noStrut>yes<\/noStrut>/' /config/.config/openbox/rc.xml
    openbox --reconfigure
fi

# generate openbox menu from defaults + ~/Desktop/*.desktop files
/scripts/refresh-menu.sh

# watch ~/Desktop/ for .desktop file changes and auto-refresh menu
mkdir -p "$HOME/Desktop"
if command -v inotifywait >/dev/null 2>&1; then
    (while inotifywait -q -e create -e delete -e modify "$HOME/Desktop/" --include '\.desktop$'; do
        sleep 1
        /scripts/refresh-menu.sh
    done) >/dev/null 2>&1 &
fi

nohup stalonetray --dockapp-mode simple > /dev/null 2>&1 &

# Start fcitx5 IME inside container.
# Running IME in-container makes candidate window follow the real caret in WeChat/QQ.
if [ "${ENABLE_FCITX5:-true}" = "true" ] || [ "${ENABLE_FCITX5:-true}" = "1" ]; then
    # Avoid conflicts if ibus is running in this base image
    pkill -x ibus-daemon >/dev/null 2>&1 || true

    # Ensure we have a session bus (some minimal images don't)
    if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-launch >/dev/null 2>&1; then
        eval "$(dbus-launch --sh-syntax --exit-with-session)"
    fi

    if command -v fcitx5 >/dev/null 2>&1; then
        mkdir -p /config/.config/fcitx5

        # Seed a sane default profile (English + Pinyin) on first run.
        if [ ! -f /config/.config/fcitx5/profile ]; then
            cat > /config/.config/fcitx5/profile <<'EOP'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=pinyin

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=pinyin
Layout=

[GroupOrder]
0=Default
EOP
        fi

        # Optional: make switching predictable (Ctrl+Space by default).
        if [ ! -f /config/.config/fcitx5/config ]; then
            cat > /config/.config/fcitx5/config <<'EOC'
[Hotkey]
TriggerKeys=CTRL_SPACE
EOC
        fi

        # Start/replace daemon
        nohup fcitx5 -d -r > /dev/null 2>&1 &
    fi
fi

# start WeChat application in the background if exists and auto-start enabled
if [ "$AUTO_START_WECHAT" = "true" ]; then
    if [ -f /usr/bin/wechat ]; then nohup /usr/bin/wechat > /dev/null 2>&1 & fi
fi

# start QQ application in the background if exists and auto-start enabled
if [ "$AUTO_START_QQ" = "true" ]; then
    if [ -f /usr/bin/qq ]; then nohup /usr/bin/qq --no-sandbox > /dev/null 2>&1 & fi
fi
