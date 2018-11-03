include(bionic)

# install postfix
RUN DEBIAN_FRONTEND=noninteractive \
    apt install --yes \
        dnsutils \
        postfix \
        postfix-policyd-spf-python \
        opendkim \
        opendkim-tools
