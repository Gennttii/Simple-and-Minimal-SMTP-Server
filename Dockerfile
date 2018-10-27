include(bionic)

# install postfix
RUN DEBIAN_FRONTEND=noninteractive \
        apt install --yes postfix dnsutils
