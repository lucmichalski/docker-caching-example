FROM ubuntu:bionic

LABEL maintainer="jessegoodier@gmail.com"

# Set Nginx Plus version
ENV NGINX_PLUS_VERSION 21

## Install Nginx Plus
 # Download certificate and key from the customer portal https://cs.nginx.com
 # and copy to the build context and set correct permissions
RUN mkdir -p /etc/ssl/nginx
COPY nginx-repo.crt /etc/ssl/nginx/nginx-repo.crt
COPY nginx-repo.key /etc/ssl/nginx/nginx-repo.key
RUN chmod 644 /etc/ssl/nginx/* \
# Install prerequisite packages, vim for editing, then Install NGINX Plus
  && set -x \
  && apt-get update && apt-get upgrade -y \
  && apt-get install --no-install-recommends --no-install-suggests -y apt-transport-https ca-certificates gnupg1 curl python2.7 procps net-tools vim-tiny joe jq less git openssh-server openssh-client sudo iproute2 \
  && \
  NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
  found=''; \
  for server in \
    ha.pool.sks-keyservers.net \
    hkp://keyserver.ubuntu.com:80 \
    hkp://p80.pool.sks-keyservers.net:80 \
    pgp.mit.edu \
  ; do \
    echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
    apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
  done; \
  test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
  echo "Acquire::https::plus-pkgs.nginx.com::Verify-Peer \"true\";" >> /etc/apt/apt.conf.d/90nginx \
  && echo "Acquire::https::plus-pkgs.nginx.com::Verify-Host \"true\";" >> /etc/apt/apt.conf.d/90nginx \
  && echo "Acquire::https::plus-pkgs.nginx.com::SslCert     \"/etc/ssl/nginx/nginx-repo.crt\";" >> /etc/apt/apt.conf.d/90nginx \
  && echo "Acquire::https::plus-pkgs.nginx.com::SslKey      \"/etc/ssl/nginx/nginx-repo.key\";" >> /etc/apt/apt.conf.d/90nginx \
  && printf "deb https://plus-pkgs.nginx.com/R${NGINX_PLUS_VERSION}/debian stretch nginx-plus\n" > /etc/apt/sources.list.d/nginx-plus.list \
  && apt-get update && apt-get install -y nginx-plus \
  ## Optional: Install NGINX Plus Modules from repo
  # See https://www.nginx.com/products/nginx/modules
  # && DEBIAN_FRONTEND=noninteractive apt-get -qq -y install --no-install-recommends nginx-plus-module-modsecurity \
  # && DEBIAN_FRONTEND=noninteractive apt-get -qq -y install --no-install-recommends nginx-plus-module-geoip \
  # && DEBIAN_FRONTEND=noninteractive apt-get -qq -y install --no-install-recommends nginx-plus-module-njs \
  && rm -rf /var/lib/apt/lists/* \
  # Remove default nginx config
  && rm /etc/nginx/conf.d/default.conf \
  # Optional: Create cache folder and set permissions for proxy caching
  && mkdir -p /var/cache/nginx \
  && chown -R nginx /var/cache/nginx

# Optional: COPY over any of your SSL certs for HTTPS servers
# e.g.
#COPY etc/ssl/www.example.com.crt /etc/ssl/www.example.com.crt
#COPY etc/ssl/www.example.com.key /etc/ssl/www.example.com.key

# COPY /etc/nginx (Nginx configuration) directory
COPY etc/nginx /etc/nginx
RUN chown -R nginx:nginx /etc/nginx \
 # Forward request logs to docker log collector
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 # Raise the limits to successfully run benchmarks
 && ulimit -c -m -s -t unlimited 
 # Remove the cert/keys from the image
 #&& rm /etc/ssl/nginx/nginx-repo.crt /etc/ssl/nginx/nginx-repo.key

#add ubuntu and workshop users for testing
RUN useradd -m ubuntu && echo "ubuntu:ubuntu" | chpasswd && adduser ubuntu sudo
COPY authorized_keys /home/ubuntu/.ssh/authorized_keys
RUN mkdir -p /home/ubuntu/.ssh
RUN chmod 400 /home/ubuntu/.ssh/authorized_keys
RUN chown -R ubuntu:ubuntu /home/ubuntu/.ssh/
RUN echo "ubuntu ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

RUN useradd -m workshop && echo "workshop:workshop" | chpasswd && adduser workshop sudo
RUN mkdir -p /home/workshop/.ssh
COPY authorized_keys /home/workshop/.ssh/authorized_keys
RUN chmod 400 /home/workshop/.ssh/authorized_keys
RUN chown -R workshop:workshop /home/workshop/.ssh/
RUN echo "workshop ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers

RUN mkdir /var/run/sshd

RUN echo 'root:root' |chpasswd

RUN sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config

RUN mkdir /root/.ssh
COPY authorized_keys /root/.ssh/authorized_keys
RUN chmod 400 /root/.ssh/authorized_keys
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 22 80 443 8080
STOPSIGNAL SIGTERM
COPY sshd-nginx.sh sshd-nginx.sh
CMD /bin/sh /sshd-nginx.sh
#CMD    ["/usr/sbin/sshd", "-D"]
