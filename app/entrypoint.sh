#!/bin/sh
set -eu

generate_salt() {
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 48
    printf '\n'
}

MM_CONFIG="${MM_CONFIG:-/mattermost/config/config.json}"

if [ "$#" -eq 0 ]; then
    set -- mattermost --config "$MM_CONFIG"
elif [ "${1#-}" != "$1" ]; then
    set -- mattermost "$@"
fi

if [ "$1" = "mattermost" ]; then
    # Detect -config and -config=... arguments
    for arg in "$@"; do
        case "$arg" in
            -config=*)
                MM_CONFIG="${arg#*=}"
                ;;
            -config)
                # The next argument is handled by Mattermost itself.
                ;;
        esac
    done

    CONFIG_DIR=$(dirname "$MM_CONFIG")
    mkdir -p "$CONFIG_DIR"

    if [ ! -f "$MM_CONFIG" ]; then
        echo "Creating Mattermost configuration at $MM_CONFIG"

        cp /config.json.save "$MM_CONFIG"

        jq '.ServiceSettings.ListenAddress = ":8065"' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.LogSettings.EnableConsole = true' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.LogSettings.ConsoleLevel = "ERROR"' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.FileSettings.Directory = "/mattermost/data/"' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.FileSettings.EnablePublicLink = true' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq --arg salt "$(generate_salt)" \
            '.FileSettings.PublicLinkSalt = $salt' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.EmailSettings.SendEmailNotifications = false' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.EmailSettings.FeedbackEmail = ""' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.EmailSettings.SMTPServer = ""' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.EmailSettings.SMTPPort = ""' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq --arg salt "$(generate_salt)" \
            '.EmailSettings.InviteSalt = $salt' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq --arg salt "$(generate_salt)" \
            '.EmailSettings.PasswordResetSalt = $salt' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.RateLimitSettings.Enable = true' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.SqlSettings.DriverName = "postgres"' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq --arg key "$(generate_salt)" \
            '.SqlSettings.AtRestEncryptKey = $key' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"

        jq '.PluginSettings.Directory = "/mattermost/plugins/"' \
            "$MM_CONFIG" > "$MM_CONFIG.tmp" && mv "$MM_CONFIG.tmp" "$MM_CONFIG"
    else
        echo "Using existing Mattermost configuration at $MM_CONFIG"
    fi

    # Build the database URL only when a complete datasource was not supplied.
    if [ -z "${MM_SQLSETTINGS_DATASOURCE:-}" ]; then
        if [ -n "${MM_USERNAME:-}" ] && [ -n "${MM_PASSWORD:-}" ]; then
            DB_HOST="${DB_HOST:-db}"
            DB_PORT_NUMBER="${DB_PORT_NUMBER:-5432}"
            MM_DBNAME="${MM_DBNAME:-mattermost}"

            ENCODED_PASSWORD=$(printf '%s' "$MM_PASSWORD" | jq -s -R -r @uri)

            export MM_SQLSETTINGS_DATASOURCE="postgres://${MM_USERNAME}:${ENCODED_PASSWORD}@${DB_HOST}:${DB_PORT_NUMBER}/${MM_DBNAME}?sslmode=disable&connect_timeout=10"

            echo "Configured database connection from component variables"
        else
            echo "ERROR: MM_SQLSETTINGS_DATASOURCE is not set"
            echo "Set MM_SQLSETTINGS_DATASOURCE or set MM_USERNAME and MM_PASSWORD"
            exit 1
        fi
    else
        echo "Using MM_SQLSETTINGS_DATASOURCE"
    fi

    # Configure MinIO when S3 storage is enabled.
    if [ "${MM_FILESETTINGS_DRIVERNAME:-}" = "amazons3" ]; then
        : "${MM_FILESETTINGS_AMAZONS3ENDPOINT:?MM_FILESETTINGS_AMAZONS3ENDPOINT is required}"
        : "${MM_FILESETTINGS_AMAZONS3ACCESSKEYID:?MM_FILESETTINGS_AMAZONS3ACCESSKEYID is required}"
        : "${MM_FILESETTINGS_AMAZONS3SECRETACCESSKEY:?MM_FILESETTINGS_AMAZONS3SECRETACCESSKEY is required}"
        : "${MM_FILESETTINGS_AMAZONS3BUCKET:?MM_FILESETTINGS_AMAZONS3BUCKET is required}"

        echo "Configuring MinIO"

        mc alias set minio \
            "http://${MM_FILESETTINGS_AMAZONS3ENDPOINT}" \
            "$MM_FILESETTINGS_AMAZONS3ACCESSKEYID" \
            "$MM_FILESETTINGS_AMAZONS3SECRETACCESSKEY"

        echo "Creating MinIO bucket if necessary"

        mc mb --ignore-existing \
            "minio/${MM_FILESETTINGS_AMAZONS3BUCKET}"
    fi

    echo "Starting Mattermost"
fi

exec "$@"
