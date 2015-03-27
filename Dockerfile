FROM ubuntu:14.04

RUN apt-get update
RUN apt-get install -y supervisor swift python-swiftclient rsync \
                       swift-proxy swift-object memcached python-keystoneclient \
                       python-swiftclient swift-plugin-s3 python-netifaces \
                       python-xattr python-memcache \
                       swift-account swift-container swift-object pwgen man-db rlwrap

RUN apt-get install -y vim bash python-dev command-not-found bash-completion python-pip build-essential git vim
RUN git clone https://github.com/ya790206/auto_config /auto_config
RUN python /auto_config/init_vim.py
RUN python /auto_config/init_bashrc.py

# python package

RUN pip install ipython
RUN pip install pudb 
RUN pip install pdbpp
RUN pip install virtualenvwrapper

# SSH server
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config
RUN sed -i 's/RSAAuthentication yes/RSAAuthentication no/' /etc/ssh/sshd_config
RUN sed -i 's/PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# supervisor
RUN mkdir -p /var/log/supervisor
ADD files/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

#
# Swift configuration
# - Partially fom http://docs.openstack.org/developer/swift/development_saio.html
#

# not sure how valuable dispersion will be...
ADD files/dispersion.conf /etc/swift/dispersion.conf
ADD files/rsyncd.conf /etc/rsyncd.conf
ADD files/swift.conf /etc/swift/swift.conf
ADD files/proxy-server.conf /etc/swift/proxy-server.conf

ADD files/account-server.conf /etc/swift/account-server.conf
ADD files/account-server-1.conf /etc/swift/account-server-1.conf

ADD files/object-server.conf /etc/swift/object-server.conf
ADD files/object-server-1.conf /etc/swift/object-server-1.conf

ADD files/container-server.conf /etc/swift/container-server.conf
ADD files/container-server-1.conf /etc/swift/container-server-1.conf

ADD files/startmain.sh /usr/local/bin/startmain.sh
ADD files/createfile /usr/local/bin/createfile

RUN chmod 755 /usr/local/bin/*.sh

EXPOSE 8080

# create swift home dir

RUN mkdir /home/swift
RUN chown -R swift:swift /home/swift

# link swift package to home dir
RUN ln -s /usr/lib/python2.7/dist-packages/swift ~

# make version controll for swift package
RUN cd ~/swift
ADD files/python.gitignore /data/gitignore


# Create image
RUN echo "This is image." > ~/image

# enable rsync

RUN sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/' /etc/default/rsync

# swift
RUN cd ~/swift
RUN cp /data/gitignore ~/swift/.gitignore
RUN git config --global user.email "email@email.com"
RUN git config --global user.name "swift_docker"
RUN git init
RUN git add .
RUN git commit -m "init"

EXPOSE 22

CMD /usr/local/bin/startmain.sh
