cmd_config_help() {
    cat <<_EOF
    config
        Run configuration scripts inside the container.

_EOF
}

cmd_config() {
    ds inject ubuntu-fixes.sh
    ds inject set_prompt.sh

    ds inject postfix.sh
    ds inject spf-policy.sh
    ds inject opendkim.sh

    for domain in $(cat config/virtual_alias_domains | xargs); do
        ds dkimkey add $domain
    done

    ds inject update.sh
}
