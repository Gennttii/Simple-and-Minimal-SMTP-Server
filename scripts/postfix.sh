#!/bin/bash -x

source /host/settings.sh

### config variables
mydomain=${MAIL_DOMAIN:-localdomain}
myhostname=$(dig -x $(dig $MAIL_DOMAIN +short) +short)
myhostname=${myhostname%.}

### config files that can be customized further by the user
config_dir=/etc/postfix/config
mynetworks_file=$config_dir/mynetworks
domains_file=$config_dir/virtual_alias_domains
aliases_file=$config_dir/virtual_alias_maps.cf

### customize main configuration
sed -E -i /etc/postfix/main.cf \
    -e '/^(mydomain|myorigin|myhostname|mydestination)/d' \
    -e '/^(mynetworks|virtual_alias_domains|virtual_alias_maps)/d' \
    -e '/### customized config/,$d'
cat <<EOF >> /etc/postfix/main.cf
### customized config
mydomain = $mydomain
myorigin = $mydomain
myhostname = $myhostname
mydestination = localhost
mynetworks = $mynetworks_file
virtual_alias_domains = $domains_file
virtual_alias_maps = hash:$aliases_file
EOF

### mynetworks
[[ -f $mynetworks_file ]] || cat <<EOF > $mynetworks_file
127.0.0.0/8
172.16.0.0/12
EOF

### virtual_alias_domains
[[ -f $domains_file ]] || cat <<EOF > $domains_file
$MAIL_DOMAIN
EOF

### virtual_alias_maps
[[ -f $aliases_file ]] || cat <<EOF > $aliases_file
root@$MAIL_DOMAIN    $FORWARD_ADDRESS
info@$MAIL_DOMAIN    $FORWARD_ADDRESS
admin@$MAIL_DOMAIN   $FORWARD_ADDRESS

### Uncomment this to catch all email addresses of this domain.
#@$MAIL_DOMAIN    $FORWARD_ADDRESS
EOF
postmap $aliases_file

postfix reload
