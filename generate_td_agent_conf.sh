#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${TARGET_HOST:-}"

if [[ -z "$TARGET_HOST" ]]; then
    echo "Error: TARGET_HOST environment variable is not set." >&2
    exit 1
fi

lower_host=$(printf '%s' "$TARGET_HOST" | tr '[:upper:]' '[:lower:]')

role=""
if [[ "$lower_host" =~ -lb[0-9]+[a-z]*$ ]]; then
    role="lb"
elif [[ "$lower_host" =~ -ap[0-9]+[a-z]*$ ]]; then
    role="ap"
elif [[ "$lower_host" =~ -db[0-9]+[a-z]*$ ]]; then
    role="db"
else
    role="all"
    echo "Warning: Unable to infer role from TARGET_HOST='${TARGET_HOST}'. Generating combined configuration." >&2
fi

infer_service_slug() {
    local host_prefix slug
    host_prefix="${1%%-*}"
    if [[ -n "${SERVICE_SLUG_OVERRIDE:-}" ]]; then
        printf '%s' "$SERVICE_SLUG_OVERRIDE"
        return
    fi
    slug=$(printf '%s' "$host_prefix" | tr '[:upper:]' '[:lower:]')
    slug=${slug//_/-}
    if [[ "$slug" =~ name$ ]] && [[ "$slug" != *"-name" ]]; then
        slug="${slug%name}-name"
    fi
    printf '%s' "$slug"
}

service_slug=$(infer_service_slug "$lower_host")

generate_system_section() {
    cat <<EOF
# System Log
<match ${TARGET_HOST}.syslog.messages>
    @type file
    path /data/log/${TARGET_HOST}/01_system/messages
    buffer_path /data/log/${TARGET_HOST}/_buffer/messages
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.syslog.cron>
    @type file
    path /data/log/${TARGET_HOST}/01_system/cron
    buffer_path /data/log/${TARGET_HOST}/_buffer/cron
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.syslog.secure>
    @type file
    path /data/log/${TARGET_HOST}/01_system/secure
    buffer_path /data/log/${TARGET_HOST}/_buffer/secure
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.syslog.maillog>
    @type file
    path /data/log/${TARGET_HOST}/01_system/maillog
    buffer_path /data/log/${TARGET_HOST}/_buffer/maillog
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>
EOF
}

generate_lb_section() {
    cat <<EOF

# Access Log
<match ${TARGET_HOST}.nginx.access>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/access.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/nginx-access
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.nginx.access.default>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/default.access.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/nginx-default-access
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.nginx.access.${service_slug}>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/com.ipet-ins.${service_slug}.ssl.access.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/nginx-access-${service_slug}
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

# Error Log
<match ${TARGET_HOST}.nginx.error>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/error.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/nginx-error
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.nginx.error.default>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/default.error.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/nginx-default-error
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.nginx.error.${service_slug}>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/com.ipet-ins.${service_slug}.ssl.error.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/nginx-error-${service_slug}
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>
EOF
}

generate_ap_section() {
    cat <<EOF
# Access Log
<match ${TARGET_HOST}.apache.access>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/access_log
    buffer_path /data/log/${TARGET_HOST}/_buffer/apache-access
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.apache.access.${service_slug}-admin>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/com.ipet-ins.${service_slug}-admin.access.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/apache-access-${service_slug}-admin
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.apache.access.${service_slug}>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/com.ipet-ins.${service_slug}.access.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/apache-access-${service_slug}
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

# Error Log
<match ${TARGET_HOST}.apache.error>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/error_log
    buffer_path /data/log/${TARGET_HOST}/_buffer/apache-error
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.apache.error.${service_slug}-admin>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/com.ipet-ins.${service_slug}-admin.error.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/apache-error-${service_slug}-admin
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.apache.error.${service_slug}>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/com.ipet-ins.${service_slug}.error.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/apache-error-${service_slug}
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

# Application Log
<match ${TARGET_HOST}.laravel.${service_slug}-admin>
    @type file
    path /data/log/${TARGET_HOST}/03_app/${service_slug}-admin-laravel.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/app-${service_slug}-admin
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.laravel.${service_slug}>
    @type file
    path /data/log/${TARGET_HOST}/03_app/${service_slug}-laravel.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/app-${service_slug}
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>
EOF
}

generate_db_section() {
    cat <<EOF
# MySQL Log
<match ${TARGET_HOST}.mysql.error>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/error.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/mysql-error
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

<match ${TARGET_HOST}.mysql.slow>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/slow.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/mysql-slow
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>

# Redis Log
<match ${TARGET_HOST}.redis.general>
    @type file
    path /data/log/${TARGET_HOST}/02_middleware/redis.log
    buffer_path /data/log/${TARGET_HOST}/_buffer/redis-general
    time_slice_format %Y%m%d
    time_slice_wait 10m
</match>
EOF
}

config_content=""
case "$role" in
    lb)
        config_content="$(generate_system_section)

$(generate_lb_section)"
        ;;
    ap)
        config_content="$(generate_system_section)

$(generate_ap_section)"
        ;;
    db)
        config_content="$(generate_system_section)

$(generate_db_section)"
        ;;
    all)
        config_content="$(generate_system_section)

$(generate_lb_section)

$(generate_ap_section)

$(generate_db_section)"
        ;;
    *)
        echo "Internal error: unsupported role '$role'." >&2
        exit 1
        ;;
esac

local_conf="./td-agent_${TARGET_HOST}.conf"

printf '%s\n' "$config_content" > "$local_conf"
chmod 600 "$local_conf"

echo "Generated ${local_conf} for role '${role}' (service slug: ${service_slug})."
