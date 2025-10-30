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

service_slug_pos=${service_slug//[^[:alnum:]]/-}

forward_host=${FORWARD_HOST:-172.16.161.21}
forward_port=${FORWARD_PORT:-24224}
pos_dir=${POS_DIR:-/var/log/td-agent/pos}
nginx_log_dir=${NGINX_LOG_DIR:-/var/log/nginx}
apache_log_dir=${APACHE_LOG_DIR:-/var/log/httpd}
app_log_dir=${APP_LOG_DIR:-/var/log/app}
mysql_log_dir=${MYSQL_LOG_DIR:-/var/log/mysql}
redis_log_dir=${REDIS_LOG_DIR:-/var/log/redis}

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

generate_sender_system_sources() {
    cat <<EOF
### System Log ###
<source>
  @type tail
  path /var/log/messages
  format none
  pos_file ${pos_dir}/messages.pos
  tag ${TARGET_HOST}.syslog.messages
</source>

<source>
  @type tail
  path /var/log/cron
  format none
  pos_file ${pos_dir}/cron.pos
  tag ${TARGET_HOST}.syslog.cron
</source>

<source>
  @type tail
  path /var/log/secure
  format none
  pos_file ${pos_dir}/secure.pos
  tag ${TARGET_HOST}.syslog.secure
</source>

<source>
  @type tail
  path /var/log/maillog
  format none
  pos_file ${pos_dir}/maillog.pos
  tag ${TARGET_HOST}.syslog.maillog
</source>
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

generate_sender_lb_sources() {
    cat <<EOF
### Access Log ###
<source>
  @type tail
  path ${nginx_log_dir}/access.log
  format none
  pos_file ${pos_dir}/nginx-access.pos
  tag ${TARGET_HOST}.nginx.access
</source>

<source>
  @type tail
  path ${nginx_log_dir}/default.access.log
  format none
  pos_file ${pos_dir}/nginx-default-access.pos
  tag ${TARGET_HOST}.nginx.access.default
</source>

<source>
  @type tail
  path ${nginx_log_dir}/com.ipet-ins.${service_slug}.ssl.access.log
  format none
  pos_file ${pos_dir}/nginx-access-${service_slug_pos}.pos
  tag ${TARGET_HOST}.nginx.access.${service_slug}
</source>

### Error Log ###
<source>
  @type tail
  path ${nginx_log_dir}/error.log
  format none
  pos_file ${pos_dir}/nginx-error.pos
  tag ${TARGET_HOST}.nginx.error
</source>

<source>
  @type tail
  path ${nginx_log_dir}/default.error.log
  format none
  pos_file ${pos_dir}/nginx-default-error.pos
  tag ${TARGET_HOST}.nginx.error.default
</source>

<source>
  @type tail
  path ${nginx_log_dir}/com.ipet-ins.${service_slug}.ssl.error.log
  format none
  pos_file ${pos_dir}/nginx-error-${service_slug_pos}.pos
  tag ${TARGET_HOST}.nginx.error.${service_slug}
</source>
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

generate_sender_ap_sources() {
    cat <<EOF
### Access Log ###
<source>
  @type tail
  path ${apache_log_dir}/access_log
  format none
  pos_file ${pos_dir}/apache-access.pos
  tag ${TARGET_HOST}.apache.access
</source>

<source>
  @type tail
  path ${apache_log_dir}/com.ipet-ins.${service_slug}-admin.access.log
  format none
  pos_file ${pos_dir}/apache-access-${service_slug_pos}-admin.pos
  tag ${TARGET_HOST}.apache.access.${service_slug}-admin
</source>

<source>
  @type tail
  path ${apache_log_dir}/com.ipet-ins.${service_slug}.access.log
  format none
  pos_file ${pos_dir}/apache-access-${service_slug_pos}.pos
  tag ${TARGET_HOST}.apache.access.${service_slug}
</source>

### Error Log ###
<source>
  @type tail
  path ${apache_log_dir}/error_log
  format none
  pos_file ${pos_dir}/apache-error.pos
  tag ${TARGET_HOST}.apache.error
</source>

<source>
  @type tail
  path ${apache_log_dir}/com.ipet-ins.${service_slug}-admin.error.log
  format none
  pos_file ${pos_dir}/apache-error-${service_slug_pos}-admin.pos
  tag ${TARGET_HOST}.apache.error.${service_slug}-admin
</source>

<source>
  @type tail
  path ${apache_log_dir}/com.ipet-ins.${service_slug}.error.log
  format none
  pos_file ${pos_dir}/apache-error-${service_slug_pos}.pos
  tag ${TARGET_HOST}.apache.error.${service_slug}
</source>

### Application Log ###
<source>
  @type tail
  path ${app_log_dir}/${service_slug}-admin-laravel.log
  format none
  pos_file ${pos_dir}/laravel-${service_slug_pos}-admin.pos
  tag ${TARGET_HOST}.laravel.${service_slug}-admin
</source>

<source>
  @type tail
  path ${app_log_dir}/${service_slug}-laravel.log
  format none
  pos_file ${pos_dir}/laravel-${service_slug_pos}.pos
  tag ${TARGET_HOST}.laravel.${service_slug}
</source>
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

generate_sender_db_sources() {
    cat <<EOF
### MySQL Log ###
<source>
  @type tail
  path ${mysql_log_dir}/error.log
  format none
  pos_file ${pos_dir}/mysql-error.pos
  tag ${TARGET_HOST}.mysql.error
</source>

<source>
  @type tail
  path ${mysql_log_dir}/slow.log
  format none
  pos_file ${pos_dir}/mysql-slow.pos
  tag ${TARGET_HOST}.mysql.slow
</source>

### Redis Log ###
<source>
  @type tail
  path ${redis_log_dir}/redis.log
  format none
  pos_file ${pos_dir}/redis-general.pos
  tag ${TARGET_HOST}.redis.general
</source>
EOF
}

generate_forward_match() {
    local pattern="$1"
    cat <<EOF
<match ${pattern}>
  @type forward
  <server>
    host ${forward_host}
    port ${forward_port}
  </server>
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

sender_sections=()
sender_matches=()
declare -A seen_match_patterns=()

sender_sections+=("$(generate_sender_system_sources)")
seen_match_patterns["**.syslog.**"]=1
sender_matches+=("**.syslog.**")

if [[ "$role" == "lb" || "$role" == "all" ]]; then
    sender_sections+=("$(generate_sender_lb_sources)")
    if [[ -z "${seen_match_patterns["**.nginx.**"]+x}" ]]; then
        seen_match_patterns["**.nginx.**"]=1
        sender_matches+=("**.nginx.**")
    fi
fi

if [[ "$role" == "ap" || "$role" == "all" ]]; then
    sender_sections+=("$(generate_sender_ap_sources)")
    if [[ -z "${seen_match_patterns["**.apache.**"]+x}" ]]; then
        seen_match_patterns["**.apache.**"]=1
        sender_matches+=("**.apache.**")
    fi
    if [[ -z "${seen_match_patterns["**.laravel.**"]+x}" ]]; then
        seen_match_patterns["**.laravel.**"]=1
        sender_matches+=("**.laravel.**")
    fi
fi

if [[ "$role" == "db" || "$role" == "all" ]]; then
    sender_sections+=("$(generate_sender_db_sources)")
    if [[ -z "${seen_match_patterns["**.mysql.**"]+x}" ]]; then
        seen_match_patterns["**.mysql.**"]=1
        sender_matches+=("**.mysql.**")
    fi
    if [[ -z "${seen_match_patterns["**.redis.**"]+x}" ]]; then
        seen_match_patterns["**.redis.**"]=1
        sender_matches+=("**.redis.**")
    fi
fi

sender_config=""
for section in "${sender_sections[@]}"; do
    sender_config+="${section}

"
done

for pattern in "${sender_matches[@]}"; do
    sender_config+="$(generate_forward_match "$pattern")

"
done

sender_conf="./td-agent_sender_${TARGET_HOST}.conf"
printf '%s\n' "$sender_config" > "$sender_conf"
chmod 600 "$sender_conf"

echo "Generated ${local_conf} and ${sender_conf} for role '${role}' (service slug: ${service_slug})."
