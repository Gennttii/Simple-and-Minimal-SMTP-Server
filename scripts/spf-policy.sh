#!/bin/bash -x

sed -i /etc/postfix/master.cf \
    -e '/^policyd-spf/,+1 d'
cat <<EOF >> /etc/postfix/master.cf
policyd-spf  unix  -  n  n  -  0  spawn
    user=policyd-spf
    argv=/usr/bin/policyd-spf
EOF

postconf \
    "policyd-spf_time_limit = 3600" \
    "smtpd_recipient_restrictions = check_policy_service unix:private/policyd-spf"

sed -i /etc/postfix-policyd-spf-python/policyd-spf.conf \
    -e '/skip_addresses/ c skip_addresses = 127.0.0.0/8,172.16.0.0/12'
