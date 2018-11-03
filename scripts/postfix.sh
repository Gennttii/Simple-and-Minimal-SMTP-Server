#!/bin/bash -x

main() {
    source /host/settings.sh

    config_postfix
    config_spf_policy_agent
    config_opendkim
    config_opendkim_key $MAIL_DOMAIN

    systemctl restart opendkim postfix
}

config_postfix() {
    # configuration variables
    mydomain=${MAIL_DOMAIN:-localdomain}
    myhostname=$(dig -x $(dig $MAIL_DOMAIN +short) +short)
    myhostname=${myhostname%.}

    # configuration files that can be customized further by the user
    config_dir=/etc/postfix/config
    mynetworks_file=$config_dir/mynetworks
    domains_file=$config_dir/virtual_alias_domains
    aliases_file=$config_dir/virtual_alias_maps.cf

    # customize main configuration
    sed -E -i /etc/postfix/main.cf \
	-e '/^(mydomain|myorigin|myhostname|mydestination)/d' \
	-e '/^(mynetworks|virtual_alias_domains|virtual_alias_maps)/d' \
	-e '/### customized config/,$d'
    cat <<-EOF >> /etc/postfix/main.cf
	### customized config
	mydomain = $mydomain
	myorigin = $mydomain
	myhostname = $myhostname
	mydestination = localhost
	mynetworks = $mynetworks_file
	virtual_alias_domains = $domains_file
	virtual_alias_maps = hash:$aliases_file
	EOF

    # mynetworks
    [[ -f $mynetworks_file ]] || cat <<-EOF > $mynetworks_file
	127.0.0.0/8
	172.16.0.0/12
	EOF

    # virtual_alias_domains
    [[ -f $domains_file ]] || cat <<-EOF > $domains_file
	$MAIL_DOMAIN
	EOF

    # virtual_alias_maps
    [[ -f $aliases_file ]] || cat <<-EOF > $aliases_file
	root@$MAIL_DOMAIN    $FORWARD_ADDRESS
	info@$MAIL_DOMAIN    $FORWARD_ADDRESS
	admin@$MAIL_DOMAIN   $FORWARD_ADDRESS
	
	### Uncomment this to catch all email addresses of this domain.
	#@$MAIL_DOMAIN    $FORWARD_ADDRESS
	EOF
    postmap $aliases_file

    postfix reload
}

config_spf_policy_agent() {
    sed -i /etc/postfix/master.cf \
	-e '/^policyd-spf/,$ d'
    cat <<-EOF >> /etc/postfix/master.cf
	policyd-spf  unix  -       n       n       -       0       spawn
	    user=policyd-spf argv=/usr/bin/policyd-spf
	EOF

    sed -i /etc/postfix/main.cf \
	-e '/^policyd-spf_time_limit/,+1 d'
    cat <<-EOF >> /etc/postfix/main.cf
	policyd-spf_time_limit = 3600
	smtpd_recipient_restrictions = check_policy_service unix:private/policyd-spf
	EOF

    sed -i /etc/postfix-policyd-spf-python/policyd-spf.conf \
	-e '/skip_addresses/ c skip_addresses = 127.0.0.0/8,172.16.0.0/12'

    systemctl restart postfix
}

config_opendkim() {
    # opendkim configuration
    sed -i /etc/opendkim.conf \
	-e '/^Canonicalization/,$ d'
    cat <<-EOF >> /etc/opendkim.conf
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

    # connect postfix with opendkim
    sed -i /etc/postfix/main.cf \
	-e '/^# Milter/,+5 d'
    cat <<-EOF >> /etc/postfix/main.cf
	# Milter configuration
	# OpenDKIM
	milter_default_action = accept
	milter_protocol = 2
	smtpd_milters = local:/opendkim/opendkim.sock
	non_smtpd_milters = local:/opendkim/opendkim.sock
	EOF

    # Hosts to ignore when verifying signatures
    mkdir /etc/opendkim
    cat <<-EOF > /etc/opendkim/TrustedHosts
	127.0.0.1/8
	172.16.0.0/12
	EOF
}

config_opendkim_key() {
    local domain=$1

    # create the keys for the given domain
    local keydir=/host/config/dkim-keys/$domain
    if [[ ! -d $keydir ]]; then
	mkdir -p $keydir
	opendkim-genkey -b 2048 -d $domain -D $keydir -s mail -v
	chown opendkim: $keydir/mail.private
	cat $keydir/mail.txt
    fi

    # update the signing table
    touch /etc/opendkim/SigningTable
    sed -i /etc/opendkim/SigningTable \
	-e "/mail\._domainkey\.$domain/d"
    cat <<-EOF >> /etc/opendkim/SigningTable
	*@$domain mail._domainkey.$domain
	EOF

    # update the key table
    touch /etc/opendkim/KeyTable
    sed -i /etc/opendkim/KeyTable \
	-e "/mail\._domainkey\.$domain/d"
    cat <<-EOF >> /etc/opendkim/KeyTable
	mail._domainkey.$domain   $domain:mail:$keydir/mail.private
	EOF
}

# call the main function
main
