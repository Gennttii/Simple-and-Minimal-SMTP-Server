cmd_dkimkey_help() {
    cat <<_EOF
    dkimkey [add | del] <domain>
        Add or delete the necessary configurations of opendkim key for
        the given domain.  When adding, it generates the opendkim key
        as well, if the key for this domain does not exist.

_EOF
}

cmd_dkimkey() {
    ds inject dkimkey.sh "$@"
}
