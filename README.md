# Postfix container

This is a simple and minimal smtp server based on postfix.  The goal
is not to be a full-fledged email server but just to support web
applications (for example Moodle) with sending notifications.  It also
provides simple forward email addresses (for example all emails sent
to info@example.org are forwarded to username@gmail.com). It can
support multiple email domains and multiple email addresses for each
domain.  To prevent spam and abuse from irresponsible people, it
accepts to relay emails only from local networks (including local
docker containers) and from specific ip addresses (where web
applications are installed).


## DNS configuration

To send and receive emails, DNS has to be configured properly. For
each email domain you need something like this on the DNS
configuration:
```
smtp.example.org.    IN    A           10.11.12.13
example.org.         IN    MX    1     smtp.example.org.
example.org.         IN    TXT         "v=spf1 mx -all"
```


## Firewall

Obviously, the port **25** has to be open in the firewall.


## Installation

  - First install `ds` and `wsproxy`:
      + https://gitlab.com/docker-scripts/ds#installation
      + https://gitlab.com/docker-scripts/wsproxy#installation

  - Then get the scripts: `ds pull postfix`

  - Create a directory for the container: `ds init postfix @smtp.example.org`

  - Fix the settings: `cd /var/ds/smtp.example.org/ ; vim settings.sh`

  - Build image, create the container and configure it: `ds make`

  - Get a letsencrypt SSL certificate with: `ds get-ssl-cert`

  - For more details see [INSTALL.md](INSTALL.md)


## Postfix configuration

Configuration files are on the directory 'config/'. There you can add
more email domains, aliases, or allow hosts/networks to use the server
for relaying (sending) emails. You need to run `ds inject update.sh`
after making changes to the config files.

If you add a new email domain, you should also create a new DKIM key
for it and add the corresponding configuration as a TXT record on the
DNS server: `ds dkimkey add <email-domain>`

## Other commands

```
ds stop
ds start
ds shell
ds help
```


## Further readings and info

- https://www.binarytides.com/postfix-mail-forwarding-debian/
- https://www.linuxbabe.com/mail-server/setting-up-dkim-and-spf
- https://blog.edmdesigner.com/send-email-from-linux-command-line/
