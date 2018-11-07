cmd_get-ssl-cert_help() {
    cat <<_EOF
    get-ssl-cert [-t,--test]
         Get a free SSL certificate from letsencrypt.org

_EOF
}

cmd_get-ssl-cert() {
    ds @wsproxy get-ssl-cert $FORWARD_ADDRESS $DOMAIN $1
    [[ $? != 0 ]] && return
    [[ $1 == '-t' || $1 == '--test' ]] && return
    ds exec postconf "smtpd_tls_cert_file = /etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    ds exec postconf "smtpd_tls_key_file = /etc/letsencrypt/live/$DOMAIN/privkey.pem"
    ds exec postfix reload
}
