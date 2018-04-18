FROM ubuntu:16.04
MAINTAINER Tim Harder <radhermit@gmail.com>

# environment configuration
ENV BUGS_DB_DRIVER mysql
ENV BUGS_DB_NAME bugs
ENV BUGS_DB_PASS bugs
ENV BUGS_DB_HOST localhost

ENV BUGZILLA_USER bugzilla
ENV BUGZILLA_ROOT /var/www/html/bugzilla

ENV GITHUB_BASE_GIT https://github.com/bugzilla/bugzilla
ENV GITHUB_BASE_BRANCH release-5.0-stable

ENV ADMIN_EMAIL admin@bugzilla.lan
ENV ADMIN_PASS password

# automate pkg configuration during install
COPY debconf-selections /
RUN debconf-set-selections /debconf-selections && rm /debconf-selections

COPY pkgs /
RUN apt-get update && apt-get install -y `cat /pkgs` && rm /pkgs

# user configuration
RUN useradd -m -G sudo -u 1000 -s /bin/bash $BUGZILLA_USER -p $BUGZILLA_USER \
    && echo "bugzilla:bugzilla" | chpasswd

# apache configuration
RUN mkdir -p $BUGZILLA_ROOT && chown -R $BUGZILLA_USER:$BUGZILLA_USER $BUGZILLA_ROOT
COPY bugzilla.conf /etc/apache2/sites-available/bugzilla.conf
RUN a2dissite 000-default && a2ensite bugzilla && a2enmod cgi headers expires

# sudo configuration
COPY sudoers /etc/sudoers
RUN chown root:root /etc/sudoers && chmod 440 /etc/sudoers

# clone the code repo
RUN su $BUGZILLA_USER -c "git clone $GITHUB_BASE_GIT -b $GITHUB_BASE_BRANCH $BUGZILLA_ROOT"

# setup bugzilla
COPY *.sh checksetup_answers.txt /
RUN chmod 755 /*.sh
RUN /bugzilla_config.sh && /my_config.sh && rm /*.sh /checksetup_answers.txt

# fix permissions
RUN chown -R $BUGZILLA_USER:$BUGZILLA_USER $BUGZILLA_ROOT

# fix sshd issue
RUN mkdir -p /var/run/sshd

# expose ports
EXPOSE 80
EXPOSE 22

# use custom rsyslog configs to work with docker
# https://serverfault.com/questions/816235/command-klogpermitnonkernelfacility-is-currently-not-permitted
COPY rsyslog/rsyslog.conf /etc/rsyslog.conf
COPY rsyslog/50-default.conf /etc/rsyslog.d/50-default.conf

# add bugzilla alias for postfix
RUN echo "admin: root" >> /etc/aliases && postalias /etc/aliases

# supervisor
COPY supervisord.conf /etc/supervisord.conf
RUN chmod 700 /etc/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
