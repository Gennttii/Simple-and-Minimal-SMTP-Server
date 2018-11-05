#!/bin/bash -x

cat /host/config/trusted_hosts > /etc/opendkim/TrustedHosts

trusted_hosts=$(cat /host/config/trusted_hosts | xargs | tr ' ' ',')
sed -i /etc/postfix-policyd-spf-python/policyd-spf.conf \
    -e "/skip_addresses/ c skip_addresses = $trusted_hosts"

postmap /host/config/virtual_alias_maps.cf

systemctl restart opendkim postfix
