APP=postfix

IMAGE=postfix
CONTAINER=postfix
PORTS="25:25"

# Make sure that you have records like this on the DNS
# ; mail for example.org
# smtp.example.org.    IN    A           10.11.12.13
# example.org.         IN    MX    1     smtp.example.org.
# example.org.         IN    TXT         "v=spf1 mx -all"
DOMAIN="smtp.example.org"
MAIL_DOMAIN="example.org"

# All the received mail will be forwarded to this address.
# This can be customized on 'config/virtual_alias_maps.cf'
FORWARD_ADDRESS="user@mail.com"
