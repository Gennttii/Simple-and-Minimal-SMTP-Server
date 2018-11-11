#!/bin/bash -x

source /host/settings.sh

mydomain=${MAIL_DOMAIN:-localdomain}
myhostname=$(dig -x $(dig $MAIL_DOMAIN +short) +short)
myhostname=${myhostname%.}
postconf \
    "mydomain = $mydomain" \
    "myorigin = $mydomain" \
    "mydestination = localhost" \
    "myhostname = $myhostname" \
    "disable_vrfy_command = yes"

# TLS settings
postconf \
    "smtp_tls_security_level = may" \
    "smtpd_tls_security_level = may" \
    "smtp_tls_note_starttls_offer = yes" \
    "smtp_tls_loglevel = 1" \
    "smtpd_tls_loglevel = 1" \
    "smtpd_tls_received_header = yes"

# configuration files that can be customized further by the user
config_dir=/host/config
mynetworks_file=$config_dir/trusted_hosts
domains_file=$config_dir/virtual_alias_domains
aliases_file=$config_dir/virtual_alias_maps.cf

postconf \
    "mynetworks = $mynetworks_file"
postconf \
    "virtual_alias_domains = $domains_file" \
    "virtual_alias_maps = hash:$aliases_file"

# mynetworks
[[ -f $mynetworks_file ]] || cat <<EOF > $mynetworks_file
127.0.0.0/8
172.16.0.0/12
EOF

# virtual_alias_domains
[[ -f $domains_file ]] || cat <<EOF > $domains_file
$MAIL_DOMAIN
EOF

# virtual_alias_maps
[[ -f $aliases_file ]] || cat <<EOF > $aliases_file
postmaster@$MAIL_DOMAIN    $FORWARD_ADDRESS
abuse@$MAIL_DOMAIN         $FORWARD_ADDRESS
root@$MAIL_DOMAIN          $FORWARD_ADDRESS
admin@$MAIL_DOMAIN         $FORWARD_ADDRESS
info@$MAIL_DOMAIN          $FORWARD_ADDRESS

### Uncomment this to catch all email addresses of this domain.
#@$MAIL_DOMAIN    $FORWARD_ADDRESS
EOF
postmap $aliases_file
