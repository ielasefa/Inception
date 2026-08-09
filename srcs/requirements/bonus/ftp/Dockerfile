FROM debian:bullseye

RUN apt-get update \
    && apt-get install -y --no-install-recommends vsftpd \
    && rm -rf /var/lib/apt/lists/*

COPY conf/vsftpd.conf /etc/vsftpd.conf
COPY tools/start.sh /usr/local/bin/start-ftp.sh

RUN chmod +x /usr/local/bin/start-ftp.sh

EXPOSE 21
EXPOSE 21000-21010

ENTRYPOINT ["/usr/local/bin/start-ftp.sh"]