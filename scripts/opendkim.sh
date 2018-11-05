#!/bin/bash -x

# config file
sed -i /etc/opendkim.conf \
    -e '/^Canonicalization/,$ d'
cat <<EOF >> /etc/opendkim.conf
Canonicalization    relaxed/simple
AutoRestart         yes
AutoRestartRate     10/1M
Background          yes
DNSTimeout          5
SignatureAlgorithm  rsa-sha256

# Map domains in From addresses to keys used to sign messages
KeyTable           /etc/opendkim/KeyTable
SigningTable       refile:/etc/opendkim/SigningTable

# Hosts to ignore when verifying signatures
ExternalIgnoreList  /etc/opendkim/TrustedHosts
InternalHosts       /etc/opendkim/TrustedHosts
EOF

# configure the socket
sed -i /etc/default/opendkim \
    -e '/^SOCKET/ c SOCKET="local:/var/spool/postfix/opendkim/opendkim.sock"'
sed -i /etc/opendkim.conf \
    -e '/^Socket/ c Socket local:/var/spool/postfix/opendkim/opendkim.sock'
mkdir /var/spool/postfix/opendkim
chown opendkim:opendkim /var/spool/postfix/opendkim
adduser postfix opendkim

# connect postfix to opendkim
postconf \
    'milter_default_action = accept' \
    'milter_protocol = 2' \
    'smtpd_milters = local:/opendkim/opendkim.sock' \
    'non_smtpd_milters = local:/opendkim/opendkim.sock'

# Hosts to ignore when verifying signatures
mkdir /etc/opendkim
cat <<EOF > /etc/opendkim/TrustedHosts
127.0.0.1/8
172.16.0.0/12
EOF
