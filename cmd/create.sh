cmd_create_help() {
    cat <<_EOF
    create
        Create the container '$CONTAINER'.

_EOF
}

rename_function cmd_create orig_cmd_create
cmd_create() {
    orig_cmd_create \
        --mount type=bind,src=/var/ds/wsproxy/letsencrypt/,dst=/etc/letsencrypt/,readonly
}
