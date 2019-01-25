
# Simple and Minimal SMTP Server

## 1. Introduction

Quite often web applications need to send email notifications. For
example Moodle needs to notify students and teachers about various
events. Without being able to send notifications, Moodle and many
other web applications loose half of their usefulness. On many web
applications you cannot even finish the registration process and
cannot login, unless you verify your email address (the application
sends you an email with a link that you have to click).

To send emails, an application needs to contact by SMTP a local or
remote mail server. Installing a mail server is not so easy because it
needs also some DNS and other configurations, in order to do it
properly, otherwise the mails that are sent will end up being
classified as spam and most probably will not reach the recipient.

A relatively easy solution is to send emails from GMail SMTP servers,
on behalf of the web application. For this you need a GMail account,
which often needs to be different for each application. Managing lots
of gmail accounts is a bit inconvenient. However the biggest problem
is that gmail accounts have a limit on the number of messages that can
be sent each month. For many applications this limit may be OK, but
for some others it is not. For example Moodle typically needs to send
a message for each course subscriber, for each event of the
course. Even for a small Moodle site that does not have many active
courses, the monthly limit can be reached very quickly.

Another alternative is to install your own mail server, and to
configure it properly.  This article describes how to do it. The aim
of this mail server is not to be a full-fledged system, where users
can have accounts and use it daily, but just to support web
applications (like Moodle) with sending notifications.


## 2. Sending Email From GMail SMTP Servers

Before starting with building a SMTP server, let's see first the easy
solution, in case this is sufficient for your needs.

1. First install *Simple SMTP*: `apt install ssmtp`

2. You can create a new GMail account or use an existing one. In both
   cases you need to enable the two-factor authentication on the
   google account, and then to create a new application-specific
   password on this account, as described here:
   https://www.lifewire.com/get-a-password-to-access-gmail-by-pop-imap-2-1171882

3. Edit `/etc/ssmtp/` and place a content like this:
   ```
   root=username@gmail.com
   mailhub=smtp.gmail.com:587
   AuthUser=username@gmail.com
   AuthPass=xyzxyzxyzxyzxyzxyz
   UseTLS=YES
   UseSTARTTLS=YES
   rewriteDomain=gmail.com
   hostname=localhost
   FromLineOverride=YES
   ```
   Here `AuthPass` is the app-specific password generated on the step above.

4. Add this line on `/etc/ssmtp/revaliases`:
   ```
   root:username@gmail.com:smtp.gmail.com:587
   ```

To test that it works, create and execute a script called `test-ssmtp.sh` with a content like this:
```
#!/bin/bash -x

recipient=${1:-user@example.org}

cat <<EOF | sendmail -v $recipient
To: $recipient
Subject: Testing ssmtp

Line 1
Line 2
EOF
```

**Note:** Replace `user@example.org` with your email address or call
the script with your email address as an argument.


## 3. Minimal DNS Configuration

In order to build a mail server you need to own a domain (say
`example.org`) and be able to customize its DNS records.

For each email domain you need something like this on the DNS
configuration:
```
; mail for example.org
smtp.example.org.    IN    A           10.11.12.13
example.org.         IN    MX    1     smtp.example.org.
example.org.         IN    TXT         "v=spf1 mx -all"
```

The first line shows the IP of the server `smtp.example.org`. The
second line shows that the mail server (`MX`) for the domain
`example.org` is `smtp.example.org`. Number `1` shows the priority of
the mail server (since there may be more than one mail servers for the
same domain).

The third line basically tells to the other SMTP servers that only
this server is allowed to send emails on behalf of this domain, and no
other servers. This is done to prevent spammers from faking your email
addresses. If a spammer tries to send a mail as if it is coming from
your domain, the SMTP server that is getting this email will consult
this DNS record, will figure out that the server of the spammer is not
allowed to send emails on behalf of `example.org`, and will
immediately classify that email as spam or reject it at all.

**Note:** The configuration lines above are suitable for `bind9` (they
should normally go to `example.org.db`). If you use some other system
for managing your domain records, you should figure out how to do them
properly on it. If you are starting from scratch and don't have yet a
domain for the mail server, I would suggest trying this for managing
its DNS configuration: https://gitlab.com/docker-scripts/bind9

**Note:** On `bind9`, make sure to change the serial number on the
configuration file and then restart the service: `systemctl restart
bind9`. It may take a few hours or a couple of days for the DNS
changes to propagate on the internet.

You can use `dig` to verify that these settings have already been
activated:
```
$ dig MX example.org +short
1 smtp.example.org.

$ dig A smtp.example.org +short
10.11.12.13

$ dig TXT example.org +short
"v=spf1 mx -all"
```


## 4. Build a Postfix Container With Docker-Scripts

It is easy to build a postfix container with docker-scripts.

### 4.1. Install Docker-Scripts

```
sudo su
apt install m4
git clone https://gitlab.com/docker-scripts/ds /opt/docker-scripts/ds
cd /opt/docker-scripts/ds/
make install
```

### 4.2. Install Web-Server Proxy

- Get the scripts: `ds pull wsproxy`
- Create a container directory: `ds init wsproxy @wsproxy`
- Fix the settings: `cd /var/ds/wsproxy/; vim settings.sh`
- Build image, create the container and configure it: `ds make`

We need `wsproxy` to get and manage letsencrypt SSL certificates for
the `postfix` container.

### 4.3. Install Postfix

- Get the scripts: `ds pull postfix`
- Create a container directory: `ds init postfix @smtp.example.org`
- Fix the settings: `cd /var/ds/smtp.example.org/ ; vim settings.sh`
- Build image, create the container and configure it: `ds make`
- Get a letsencrypt SSL certificate: `ds get-ssl-cert`

### 4.4. Activate DKIM Key

DKIM keys are used by mail servers to sign the emails that they send,
so that they cannot be changed in transit, and so that it can be
verified that they were sent by them. It is an important tool against
spams and faked emails. If a smtp server signs the messages that it
sends, it is less likely that they will be classified as spam.

Installation scripts generate a DKIM key as well, which is on
`config/dkim-keys/example.org/`.  To activate it you need to add a
record like this on the DNS configuration of the domain:
```
mail._domainkey.example.org.  IN  TXT  "v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQE....kMJdAwIDAQAB"
```
You can find the content of the public key on the file:
`config/dkim-keys/example.org/mail.txt`.

Don't forget to update the serial number of the DNS domain and to
restart or reload the service (`systemctl restart bind9`). It may take
a couple of hours or days until these changes are propagated on the
internet.

To check whether it has been activated or not, try the command:
```
dig TXT mail._domainkey.example.org +short
```

### 4.5. Create a DMARC Record

DMARC is a standard that allows you to set policies on who can send
email for your domain based on DKIM and SPF. For more details see
this: https://postmarkapp.com/support/article/892-what-is-dmarc

You can add a DMARC Record on DNS that will allow you to get weekly
reports from major ISPs about the usage of your email domain.

- Go to http://dmarc.postmarkapp.com/ and add your email address where
  you want to receive reports, and email domain name (`example.org`).

- On the DNS configuration of the domain add a TXT record like this:
  ```
  _dmarc.example.org.  IN  TXT  "v=DMARC1; p=none; pct=100; rua=mailto:re+x2i0yw1hoq7@dmarc.postmarkapp.com; sp=none; aspf=r;"
  ```
  The value of this TXT record is the one generated by the website
  above.

- To check that it has been activated, try the command:
  ```
  dig TXT _dmarc.example.org. +short
  ```

## 5. Test the SMTP Server

- Install `swaks`:
  ```
  cd /var/ds/smtp.example.org/
  ds shell
  apt install swaks
  ```

- Send a test email and check the logs:
  ```
  swaks --from info@example.org --to admin@example.org -tlso
  tail /var/log/mail.log
  ```
  The option `-tlso` tells it to use TLS if possible.

- Send a test email to a gmail account:
  ```
  swaks --from info@example.org --to username@gmail.com -tlso
  tail /var/log/mail.log
  ```
  On gmail use "Show original" from the menu, to see the source of the
  received email.

- Try to send a test email from the host (outside the container):
  ```
  cd /var/ds/smtp.example.org/
  swaks --from info@example.org --to admin@example.org -tlso
  tail /var/log/mail.log
  ```
  It may fail, because the IP of the host may not be on the list of
  the trusted hosts (that are allowed to send email for the domain
  `example.org`). Add it on `config/trusted_hosts` and then run `ds
  inject update.sh`. Verify that now you can send emails.

- Try to send email to `test@example.org`:
  ```
  swaks --from info@example.org --to test@example.org -tlso
  ...
  <** 550 5.1.1 <test@example.org>: Recipient address rejected: User unknown in virtual alias table
  ...
  ```
  It may fail because the recipient does not exist on the alias table.
  On `config/virtual_alias_maps.cf` add a line like this:
  ```
  test@example.org  username@gmail.com
  ```
  Then update the alias db: `ds exec postmap
  /host/config/virtual_alias_maps.cf` (or `ds inject update.sh`).
  Verify that now you can send emails to this address.

- Send an email to `check-auth@verifier.port25.com`:
  ```
  swaks --from info@example.org --to check-auth@verifier.port25.com \
        --server smtp.example.org -tlso
  ```
  The automatic reply will give you important information about the
  status and health of your email server (for example whether the mails
  sent from it pass the SPF and DKIM checks, whether they are
  considered spam or not, etc.)

- Go to https://www.mail-tester.com/ and send a message to the email
  address displayed there, like this:
  ```
  swaks --from info@example.org --to test-1p4f6@mail-tester.com \
        --server smtp.example.org -tlso
  ```
  Then click the button for checking the score.

**Note:** Another way to send test emails (instead of `swaks`) is by
using `curl` and a script `testmail.sh` with a content like this:
```
#!/bin/bash

from_address='info@example.org'
to_address='admin@example.org'
cat << EOF | curl -v --ssl --upload-file - \
                  --url 'smtp://smtp.example.org' \
                  --mail-from $from_address \
                  --mail-rcpt $to_address
From: $from_address
To: $to_address
Subject: test $(date)

Test message.
EOF

```


## 6. Check the Mail Server

There are lots of tools and websites that help to check the
configuration of a mail server (DNS settings, configuration, security
features, etc.) These are some of them:

- https://ns.tools

- https://mxtoolbox.com/

- https://app.dmarcanalyzer.com
  + https://app.dmarcanalyzer.com/dns/spf?simple=1
  + https://app.dmarcanalyzer.com/dns/dkim?simple=1
  + https://app.dmarcanalyzer.com/dns/dmarc_validator

- https://github.com/drwetter/testssl.sh/
  ```
  git clone --depth 1 https://github.com/drwetter/testssl.sh.git
  cd testssl.sh/
  ./testssl.sh -t smtp smtp.example.org:25
  ```


## 7. Add Another Email Domain

The same smtp server can support more than one mail domains. If we
want to add another mail domain, for example `example.com`, we have to
do these:

- Edit `config/virtual_alias_domains` and add the domain on a new
  line.

- Edit `config/virtual_alias_maps.cf` and add new email aliases (for
  `postmamster@example.com`, `root@example.com`, `admin@example.com`,
  `info@example.com`, etc.)

- Update server configuration with `ds inject update.sh`, or:
  ```
  ds exec postmap /host/config/virtual_alias_maps.cf
  ds exec postfix reload
  ```

- Generate a DKIM key for the domain: `ds dkimkey add example.com`

- Go to http://dmarc.postmarkapp.com/ and generate a DMARC record for
  the new domain.

- Update the DNS configuration with records like these:
  ```
  ; mail for example.com
  example.com.    IN    MX    1    smtp.example.org.

  example.com.                  IN  TXT  "v=spf1 mx -all"
  mail._domainkey.example.com.  IN  TXT  "v=DKIM1; h=sha256; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQE....kMJdAwIDAQAB"
  _dmarc.example.com.           IN  TXT  "v=DMARC1; p=none; pct=100; rua=mailto:re+x2i0yw1hoq7@dmarc.postmarkapp.com; sp=none; aspf=r;"
  ```
  Note that:
  + The MX record has the same SMTP server as the primary domain:
    `smtp.example.org` (not the new domain `smtp.example.com`).
  + The value of the key for the DKIM record can be found on the file:
    `config/dkim-keys/example.com/mail.txt`
  + The value of the DMARC record is the one obtained on the previous
    step.
  You can check these DNS configurations like this:
  ```
  dig mx  example.com. +short
  dig txt example.com. +short
  dig txt mail._domainkey.example.com. +short
  dig txt _dmarc.example.com. +short
  ```


## 8. Using The SMTP Server

Different applications have different methods for configuring the SMTP
server. Let's see how to send emails from cron jobs and from Moodle.

**Important:** For this to work, the IP of the application server
should be on the list `config/trusted_hosts` on the smtp server,
otherwise it will refuse to accept and send emails. After adding it on
this list, run `ds inject update.sh` to update the configuration of
the mail server.

### 8.1. Sending Emails From Cron Jobs

Cron jobs (for example `logwatch`) send emails to `root` through
`sendmail`. We can make it work with `ssmtp`. First install it with:
`apt install ssmtp`.  Then edit `/etc/ssmtp/ssmtp.conf` like this:
```
mailhub=smtp.example.org
rewriteDomain=example.org
UseSTARTTLS=YES
FromLineOverride=YES
```
Test it with: `echo test | sendmail -v root`


### 8.2. Sending Emails From Moodle

If we search for `smtp` on the GUI menu for administration, we will
find that the place for SMTP configuration is on `Dashboard > Site
administration > Server > Email > Outgoing mail configuration` (or on
the location: `/admin/settings.php?section=outgoingmailconfig`).

But we can also configure Moodle from command line, like this:
```
moosh config-set smtphosts smtp.example.org
moosh config-set smtpsecure TLS
moosh config-set smtpauthtype PLAIN
moosh config-set smtpuser ''
moosh config-set smtppass ''
moosh config-set smtpmaxbulk 100
```


## 9. References

- https://www.linux.com/learn/how-set-virtual-domains-and-virtual-users-postfix
- https://tecadmin.net/send-email-smtp-server-linux-command-line-ssmtp/
- https://blog.kruyt.org/postfix-and-tls-encryption/
- https://www.linuxbabe.com/mail-server/setting-up-dkim-and-spf
- https://tecadmin.net/setup-dkim-with-postfix-on-ubuntu-debian/
- https://www.skelleton.net/2015/03/21/how-to-eliminate-spam-and-protect-your-name-with-dmarc/
