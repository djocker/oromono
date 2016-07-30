# Monolitic docker image for docker based ORO Apps and for local development

For local usage [see](./local/README.md).

## Additional Info

**Environment variables (will be mapped to parameters.yml):**

`APP_DB_DRIVER=pdo_mysql`
`APP_DB_HOST=db`
`APP_DB_PORT=3306`
`APP_DB_USER=orocrm`
`APP_DB_PASSWORD=orocrm`
`APP_DB_NAME=orocrm`
`APP_DB_HOST=db`
`APP_HOSTNAME=localhost`
`APP_MAILER_TRANSPORT=smtp`
`APP_MAILER_HOST=127.0.0.1`
`APP_MAILER_PORT=`
`APP_MAILER_ENCRYPTION=`
`APP_MAILER_USER=`
`APP_MAILER_PASSWORD=`
`APP_WEBSOCKET_HOST=websocket`
`APP_WEBSOCKET_PORT=8080`
`APP_IS_INSTALLED=`

**Advanced Variables:**

`CMD_INIT_BEFORE` - Command will be executed before initialization (or installation)
`CMD_INIT_CLEAN` - Command will be used if application not installed (here you can initiate installation via cli)
`CMD_INIT_INSTALLED` - Command will be used for initialization of already installed application
`CMD_INIT_AFTER` - Command will be executed after initialization (or installation
