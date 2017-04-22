FROM djocker/orobase:1.2

COPY bin/run.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/run.sh

COPY conf/nginx.conf          /etc/nginx/nginx.conf
COPY conf/nginx-bap.conf      /etc/nginx/sites-enabled/bap.conf
COPY ["conf/supervisord-1.x.conf", "conf/supervisord-2.x.conf", "/etc/"] 

VOLUME ["/var/www/app/cache", "/var/www/web/uploads", "/var/www/web/media", "/var/www/app/attachment"]

EXPOSE 443 80 8080

CMD ["run.sh"]

ENV "SYMFONY_ENV=prod"
