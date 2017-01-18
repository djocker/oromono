#!/usr/bin/env bash
APP_ROOT="/var/www"
DATA_ROOT="/srv/app-data"

function info {
    printf "\033[0;36m===> \033[0;33m${1}\033[0m\n"
}

# Check and fix ownership if invalid
if [[ `stat -c '%u:%g' /var/www` -ne `getent passwd | grep www-data | awk -F ':' '{print $3 ":" $4}'` ]] || [[ `ls -l ${APP_ROOT} | awk '{print $3 ":" $4}' | grep -v www-data:www-data | wc -l` -gt 0 ]]; then
    info "Fix ownership for /var/www  directory"
    chown -R $(getent passwd | grep www-data | awk -F ':' '{print $3 ":" $4}') ${APP_ROOT}
fi


# Check if the local usage
if [[ -z ${IS_LOCAL} ]]; then
    # Prepare folders for persistent data
    info "Verify directory ${DATA_ROOT}/cache"
    [[ -d ${DATA_ROOT}/cache ]] || runuser -s /bin/sh -c "mkdir -p ${DATA_ROOT}/cache" www-data
    info "Verify directory ${DATA_ROOT}/media"
    [[ -d ${DATA_ROOT}/media ]] || runuser -s /bin/sh -c "mkdir -p ${DATA_ROOT}/media" www-data
    info "Verify directory ${DATA_ROOT}/uploads"
    [[ -d ${DATA_ROOT}/uploads ]] || runuser -s /bin/sh -c "mkdir -p ${DATA_ROOT}/uploads" www-data
    info "Verify directory ${DATA_ROOT}/attachment"
    [[ -d ${DATA_ROOT}/attachment ]] || runuser -s /bin/sh -c "mkdir -p ${DATA_ROOT}/attachment" www-data

    # Map environment variables
    info "Map parameters.yml to environment variables"
    composer-map-env.php ${APP_ROOT}/composer.json

    # Generate parameters.yml
    info "Run composer script 'post-install-cmd'"
    runuser -s /bin/sh -c "composer --no-interaction run-script post-install-cmd -n -d ${APP_ROOT}" www-data

    # Clean exists folders
    [[ -d ${APP_ROOT}/app/cache ]]      && rm -r ${APP_ROOT}/app/cache
    [[ -d ${APP_ROOT}/web/media ]]      && rm -r ${APP_ROOT}/web/media
    [[ -d ${APP_ROOT}/web/uploads ]]    && rm -r ${APP_ROOT}/web/uploads
    [[ -d ${APP_ROOT}/app/attachment ]] && rm -r ${APP_ROOT}/app/attachment

    # Linking persistent data
    info "Linking persistent data folders to volumes"
    
    runuser -s /bin/sh -c "ln -s ${DATA_ROOT}/cache       ${APP_ROOT}/app/cache" www-data
    runuser -s /bin/sh -c "ln -s ${DATA_ROOT}/media       ${APP_ROOT}/web/media" www-data
    runuser -s /bin/sh -c "ln -s ${DATA_ROOT}/uploads     ${APP_ROOT}/web/uploads" www-data
    runuser -s /bin/sh -c "ln -s ${DATA_ROOT}/attachment  ${APP_ROOT}/app/attachment" www-data
fi

info "Checking if application is already installed"
if [[ ! -z ${APP_IS_INSTALLED} ]] \
    || [[ `mysql -e "show databases like '${APP_DB_NAME}'" -h${APP_DB_HOST} -u${APP_DB_USER} -p${APP_DB_PASSWORD} -N | wc -l` -gt 0 ]] \
    && [[ `mysql -e "show tables from ${APP_DB_NAME}" -h${APP_DB_HOST} -u${APP_DB_USER} -p${APP_DB_PASSWORD} -N | wc -l` -gt 0 ]]; then
  sed -i -e "s/installed:.*/installed: true/g" /var/www/app/config/parameters.yml
  info "Application is already installed!"
  APP_IS_INSTALLED=true
else
  info "Application is not installed!"
fi

if [[ -z ${APP_DB_PORT} ]]; then
    if [[ "pdo_pgsql" = ${APP_DB_DRIVER} ]]; then
        APP_DB_PORT="5432"
    else
        APP_DB_PORT="3306"
    fi
fi

until nc -z ${APP_DB_HOST} ${APP_DB_PORT}; do
    info "Waiting database on ${APP_DB_HOST}:${APP_DB_PORT}"
    sleep 2
done

if [[ ! -z ${CMD_INIT_BEFORE} ]]; then
    info "Running pre init command: ${CMD_INIT_BEFORE}"
    sh -c "${CMD_INIT_BEFORE}"
fi

cd ${APP_ROOT}

# If already installed
if [[ -z ${APP_IS_INSTALLED} ]]
then
    if [[ ! -z ${CMD_INIT_CLEAN} ]]; then
        info "Running init command: ${CMD_INIT_CLEAN}"
        sh -c "${CMD_INIT_CLEAN}"
    fi
else
    info "Updating application..."
    if [[ -d ${APP_ROOT}/app/cache ]] && [[ $(ls -l ${APP_ROOT}/app/cache/ | grep -v total | wc -l) -gt 0 ]]; then
        rm -r ${APP_ROOT}/app/cache/*
    fi

    if [[ ! -z ${CMD_INIT_INSTALLED} ]]; then
        info "Running init command: ${CMD_INIT_INSTALLED}"
        sh -c "${CMD_INIT_INSTALLED}"
    fi

fi

if [[ ! -z ${CMD_INIT_AFTER} ]]; then
    info "Running post init command: ${CMD_INIT_AFTER}"
    sh -c "${CMD_INIT_AFTER}"
fi

# Starting services
if php -r 'foreach(json_decode(file_get_contents("'${SOURCE_DIR}'/composer.lock"))->{"packages"} as $p) { echo $p->{"name"} . ":" . $p->{"version"} . PHP_EOL; };' | grep 'platform:2' > /dev/null
then
  info "Starting supervisord for platform 2.x" 
  exec /usr/local/bin/supervisord -n -c /etc/supervisord-2.x.conf
else
  info "Starting supervisord for platform 1.x" 
  exec /usr/local/bin/supervisord -n -c /etc/supervisord-1.x.conf
fi


