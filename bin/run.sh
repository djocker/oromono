#!/usr/bin/env bash
APP_ROOT="/var/www"
DATA_ROOT="/srv/app-data"


# Check and fix ownership if invalid
if [[ $(stat -c '%u:%g' /var/www) != $(getent passwd | grep www-data | awk -F ':' '{print $3 ":" $4}') ]] || [[ $(ls -l ${APP_ROOT} | awk '{print $3 ":" $4}' | grep -v www-data:www-data | wc -l) -gt 0 ]]; then
    chown -R $(getent passwd | grep www-data | awk -F ':' '{print $3 ":" $4}') ${APP_ROOT}
fi

# Check if the local usage
if [[ -z ${IS_LOCAL} ]]; then
    # Prepare folders for persistent data
    [[ -d ${DATA_ROOT}/cache ]]          || sudo -u www-data mkdir -p ${DATA_ROOT}/cache
    [[ -d ${DATA_ROOT}/media ]]          || sudo -u www-data mkdir -p ${DATA_ROOT}/media
    [[ -d ${DATA_ROOT}/uploads ]]        || sudo -u www-data mkdir -p ${DATA_ROOT}/uploads
    [[ -d ${DATA_ROOT}/attachment ]]     || sudo -u www-data mkdir -p ${DATA_ROOT}/attachment

    # Map environment variables
    composer-map-env.php ${APP_ROOT}/composer.json

    # Generate parameters.yml
    sudo -u www-data -E composer run-script post-install-cmd -n -d ${APP_ROOT};

    # Clean exists folders
    [[ -d ${APP_ROOT}/app/cache ]]      && rm -r ${APP_ROOT}/app/cache
    [[ -d ${APP_ROOT}/web/media ]]      && rm -r ${APP_ROOT}/web/media
    [[ -d ${APP_ROOT}/web/uploads ]]    && rm -r ${APP_ROOT}/web/uploads
    [[ -d ${APP_ROOT}/app/attachment ]] && rm -r ${APP_ROOT}/app/attachment

    # Linking persistent data
    sudo -u www-data ln -s ${DATA_ROOT}/cache       ${APP_ROOT}/app/cache
    sudo -u www-data ln -s ${DATA_ROOT}/media       ${APP_ROOT}/web/media
    sudo -u www-data ln -s ${DATA_ROOT}/uploads     ${APP_ROOT}/web/uploads
    sudo -u www-data ln -s ${DATA_ROOT}/attachment  ${APP_ROOT}/app/attachment
fi

if [[ ! -z ${APP_IS_INSTALLED} ]] \
    || [[ $(mysql -e "show databases like '${APP_DB_NAME}'" -h${APP_DB_HOST} -u${APP_DB_USER} -p${APP_DB_PASSWORD} -N | wc -l) -gt 0 ]] \
    && [[ $(mysql -e "show tables from ${APP_DB_NAME};'" -h${APP_DB_HOST} -u${APP_DB_USER} -p${APP_DB_PASSWORD} -N | wc -l) -gt 0 ]]; then
  sed -i -e "s/installed:.*/installed: true/g" /var/www/app/config/parameters.yml
  APP_IS_INSTALLED=true
fi

if [[ -z ${APP_DB_PORT} ]]; then
    if [[ "pdo_pgsql" = ${APP_DB_DRIVER} ]]; then
        APP_DB_PORT="5432"
    else
        APP_DB_PORT="3306"
    fi
fi

until nc -z ${APP_DB_HOST} ${APP_DB_PORT}; do
    echo "Waiting database on ${APP_DB_HOST}:${APP_DB_PORT}"
    sleep 2
done

if [[ ! -z ${CMD_INIT_BEFORE} ]]; then
    echo "Running pre init command: ${CMD_INIT_BEFORE}"
    sh -c "${CMD_INIT_BEFORE}"
fi

cd ${APP_ROOT}

# If already installed
if [[ -z ${APP_IS_INSTALLED} ]]
then
    if [[ ! -z ${CMD_INIT_CLEAN} ]]; then
        echo "Running init command: ${CMD_INIT_CLEAN}"
        sh -c "${CMD_INIT_CLEAN}"
    fi
else
    echo "Updating application..."
    if [[ -d ${APP_ROOT}/app/cache ]] && [[ $(ls -l ${APP_ROOT}/app/cache/ | grep -v total | wc -l) -gt 0 ]]; then
        rm -r ${APP_ROOT}/app/cache/*
    fi

    if [[ ! -z ${CMD_INIT_INSTALLED} ]]; then
        echo "Running init command: ${CMD_INIT_INSTALLED}"
        sh -c "${CMD_INIT_INSTALLED}"
    fi

fi

if [[ ! -z ${CMD_INIT_AFTER} ]]; then
    echo "Running post init command: ${CMD_INIT_AFTER}"
    sh -c "${CMD_INIT_AFTER}"
fi

# Starting services
exec /usr/local/bin/supervisord -n

