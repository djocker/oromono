FROM djocker/orobase

COPY bin/run.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/run.sh

COPY conf/nginx.conf          /etc/nginx/nginx.conf
COPY conf/nginx-bap.conf      /etc/nginx/sites-enabled/bap.conf
COPY conf/supervisord.conf    /etc/supervisord.conf

VOLUME ["/srv/app-data"]
EXPOSE 443 80 8080

CMD ["run.sh"]


