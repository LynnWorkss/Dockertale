#!/bin/bash
set -e

JAR_FILE="/hytale/Server/HytaleServer.jar"
DOWNLOADER_BIN="${DOWNLOADER_BIN:-hytale-downloader}"

echo "Checking for hytale-downloader updates..."
$DOWNLOADER_BIN -check-update

if [ "${ENABLE_AUTO_UPDATE:-true}" = "true" ]; then
    AVAILABLE_VERSION_RAW="$($DOWNLOADER_BIN -print-version 2>&1 | tee /dev/stderr || true)"
    AVAILABLE_VERSION="$(echo "$AVAILABLE_VERSION_RAW" | tr -d '\r' | tail -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    if [ -z "$AVAILABLE_VERSION" ]; then
        echo "ERROR: Could not determine available version from downloader (-print-version). Output was:"
        echo "$AVAILABLE_VERSION_RAW"
        exit 1
    fi

    echo "Available HytaleServer.jar version: $AVAILABLE_VERSION"

    INSTALLED_VERSION=""
    if [ -f "$JAR_FILE" ]; then
        INSTALLED_VERSION_RAW="$(java -jar "$JAR_FILE" --version 2>&1 || true)"
        INSTALLED_VERSION="$(echo "$INSTALLED_VERSION_RAW" | tr -d '\r' | sed -n 's/.*v\([^ ]*\).*/\1/p' | head -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        if [ -z "$INSTALLED_VERSION" ]; then
            echo "WARNING: Could not extract version from installed jar. Treating as outdated."
        else
            echo "Installed HytaleServer.jar version: $INSTALLED_VERSION"
        fi
    else
        echo "HytaleServer.jar not found. Will download..."
    fi

    NEED_DOWNLOAD="false"

    if [ ! -f "$JAR_FILE" ]; then
        NEED_DOWNLOAD="true"
        echo "Server jar missing. Downloading..."
    elif [ -z "$INSTALLED_VERSION" ] || [ "$INSTALLED_VERSION" != "$AVAILABLE_VERSION" ]; then
        NEED_DOWNLOAD="true"
        echo "Version mismatch detected. Downloading update..."
    else
        echo "HytaleServer.jar is up to date."
    fi

    if [ "$NEED_DOWNLOAD" = "true" ]; then
        DOWNLOAD_ZIP="/hytale/game.zip"

        set +e
        $DOWNLOADER_BIN -download-path "$DOWNLOAD_ZIP"
        EXIT_CODE=$?
        set -e

        if [ $EXIT_CODE -ne 0 ]; then
            echo "Downloader error: $EXIT_CODE"

            if $DOWNLOADER_BIN -print-version 2>&1 | grep -q "403 Forbidden"; then
                if [ "${SKIP_DELETE_ON_FORBIDDEN:-false}" = "true" ]; then
                    echo "403 Forbidden detected. Keeping downloader credentials."
                else
                    echo "403 Forbidden detected. Clearing downloader credentials..."
                    rm -f ~/.hytale-downloader-credentials.json
                fi
            fi

            exit $EXIT_CODE
        fi

        if [ ! -f "$DOWNLOAD_ZIP" ]; then
            echo "ERROR: Download expected at $DOWNLOAD_ZIP but file not found."
            exit 1
        fi

        echo "Unpacking $DOWNLOAD_ZIP into /hytale..."

        rm -f "$JAR_FILE"
        unzip -o "$DOWNLOAD_ZIP" -d /hytale
        rm -f "$DOWNLOAD_ZIP"

        echo "Update completed."
    fi
else
    echo "Auto-update disabled. Skipping version check and download."
fi

cd /hytale/Server

if [ ! -f "HytaleServer.jar" ]; then
    echo "ERROR: HytaleServer.jar not found!"
    exit 1
fi

JAVA_CMD="java"

JAVA_XMS="${JAVA_XMS:-4G}"
JAVA_XMX="${JAVA_XMX:-4G}"

[ -n "$JAVA_XMS" ] && JAVA_CMD+=" -Xms$JAVA_XMS"
[ -n "$JAVA_XMX" ] && JAVA_CMD+=" -Xmx$JAVA_XMX"
[ -n "$JAVA_CMD_ADDITIONAL_OPTS" ] && JAVA_CMD+=" $JAVA_CMD_ADDITIONAL_OPTS"

if [ "$USE_AOT_CACHE" = "true" ] && [ -f "HytaleServer.aot" ]; then
    JAVA_CMD+=" -XX:AOTCache=HytaleServer.aot"
fi

ARGS="--assets $ASSETS_PATH --auth-mode $AUTH_MODE"

[ -n "$SESSION_TOKEN" ] && ARGS="$ARGS --session-token \"$SESSION_TOKEN\""
[ -n "$IDENTITY_TOKEN" ] && ARGS="$ARGS --identity-token \"$IDENTITY_TOKEN\""
[ -n "$OWNER_UUID" ] && ARGS="$ARGS --owner-uuid \"$OWNER_UUID\""

[ "$ACCEPT_EARLY_PLUGINS" = "true" ] && ARGS="$ARGS --accept-early-plugins"
[ "$ALLOW_OP" = "true" ] && ARGS="$ARGS --allow-op"
[ "$DISABLE_SENTRY" = "true" ] && ARGS="$ARGS --disable-sentry"

if [ "$BACKUP_ENABLED" = "true" ]; then
    ARGS="$ARGS --backup --backup-dir $BACKUP_DIR --backup-frequency $BACKUP_FREQUENCY"
fi

ARGS="$ARGS --bind $BIND_ADDR:$PORT"

HYTALE_ADDITIONAL_OPTS="${HYTALE_ADDITIONAL_OPTS:-}"
[ -n "$HYTALE_ADDITIONAL_OPTS" ] && ARGS="$ARGS $HYTALE_ADDITIONAL_OPTS"

echo "Starting Hytale server:"
echo "$JAVA_CMD -jar HytaleServer.jar $ARGS"

exec $JAVA_CMD -jar HytaleServer.jar $ARGS