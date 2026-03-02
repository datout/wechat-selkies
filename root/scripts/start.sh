\
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

    # Create a "button" (desktop shortcut + right-click menu entry) to toggle Fcitx5
    TOGGLE_DESKTOP="$HOME/Desktop/切换输入法（Fcitx5）.desktop"
    if [ ! -f "$TOGGLE_DESKTOP" ]; then
        cat > "$TOGGLE_DESKTOP" <<'EOD'
    [Desktop Entry]
    Type=Application
    Name=切换输入法（Fcitx5）
    Comment=启用/停用容器内 Fcitx5（需要用本机输入法时先停用）
    Exec=/usr/local/bin/toggle-fcitx5
    Icon=input-keyboard
    Terminal=false
    Categories=Utility;
    EOD
        chmod 644 "$TOGGLE_DESKTOP" || true
        /scripts/refresh-menu.sh || true
    fi

    # Optional: start/stop fcitx5 based on persisted state
    #  - default: ENABLE_FCITX5 env var (true/false)
    #  - override: /config/.config/fcitx5/enabled (1/0)
    STATE_FILE="/config/.config/fcitx5/enabled"
    ENABLE="${ENABLE_FCITX5:-true}"
    if [ -f "$STATE_FILE" ]; then
        v="$(tr -d '\r\n\t ' < "$STATE_FILE" | tr 'A-Z' 'a-z' || true)"
        if [ "$v" = "0" ] || [ "$v" = "false" ] || [ "$v" = "off" ] || [ "$v" = "disable" ] || [ "$v" = "disabled" ]; then
            ENABLE="false"
        elif [ "$v" = "1" ] || [ "$v" = "true" ] || [ "$v" = "on" ] || [ "$v" = "enable" ] || [ "$v" = "enabled" ]; then
            ENABLE="true"
        fi
    fi

    if command -v fcitx5 >/dev/null 2>&1; then
        if [ "$ENABLE" = "true" ] || [ "$ENABLE" = "1" ]; then
            # IME env (helps apps launched after this point)
            export GTK_IM_MODULE=fcitx
            export QT_IM_MODULE=fcitx
            export XMODIFIERS=@im=fcitx
            export SDL_IM_MODULE=fcitx

            nohup fcitx5 -d -r > /dev/null 2>&1 &
            echo "1" > "$STATE_FILE" 2>/dev/null || true
        else
            pkill -x fcitx5 > /dev/null 2>&1 || true
            echo "0" > "$STATE_FILE" 2>/dev/null || true
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
