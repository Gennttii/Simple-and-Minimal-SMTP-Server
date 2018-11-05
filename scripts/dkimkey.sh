#!/bin/bash

usage() {
    cat <<EOF
Usage: $0 [add | del] <domain>

Add or delete the necessary configurations of opendkim key for the
given domain.  When adding, it generates the opendkim key as well,
if the key for this domain does not exist.

EOF
    exit 1
}

main() {
    [[ $# != 2 ]] && usage
    local cmd=$1
    local domain=$2
    case $cmd in
        add) add_key_config $domain ;;
        del) del_key_config $domain ;;
        *)   usage ;;
    esac
}

del_key_config() {
    touch /etc/opendkim/SigningTable
    sed -i /etc/opendkim/SigningTable \
	-e "/mail\._domainkey\.$domain/d"

    touch /etc/opendkim/KeyTable
    sed -i /etc/opendkim/KeyTable \
	-e "/mail\._domainkey\.$domain/d"
}

add_key_config() {
    local domain=$1
    local keydir=/host/config/dkim-keys/$domain

    # create the keys for the given domain
    if [[ -d $keydir ]]; then
        echo "Using the existing key on 'config/dkim-keys/$domain/'"
    else
	mkdir -p $keydir
	opendkim-genkey -b 2048 -d $domain -D $keydir -s mail -v
	chown opendkim: $keydir/mail.private
        echo "Generated new key on 'config/dkim-keys/$domain/'"
    fi
    echo "Don't forget to add to the DNS the contents of the file"
    echo "'config/dkim-keys/$domain/mail.txt':"
    echo "======================================================="
    cat $keydir/mail.txt
    echo "======================================================="

    # update the config files
    del_key_config
    echo "*@$domain mail._domainkey.$domain" \
         >> /etc/opendkim/SigningTable
    echo "mail._domainkey.$domain   $domain:mail:$keydir/mail.private" \
         >> /etc/opendkim/KeyTable
}

# call the main function
main "$@"
