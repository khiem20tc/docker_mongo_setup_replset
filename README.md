# Setup MongoDB Replicate by Docker

## Mongo Replicate Set with Docker in same VPS
Master - Secondary

Note
- Same network docker
- Set static IP for each container
- Same secret.kf
- Chmod 600 for all file
- Build custom image form MONGO base image
- Chown for mongodb USER in custome image

## Step 1: create new user Database on VPS (tránh dùng user Root)

## Step 2: tạo 2 folder mongodb với structure như source code

## Step 3: tạo Docker file build từ base igame mongo:5.0.6
```
FROM mongo:5.0.6

RUN mkdir -p /var/log/mongodb && \
 touch /var/log/mongodb/mongod.log && \
 chown mongodb:mongodb -R /var/log/mongodb && \
 touch /etc/secret.kf && \
 chmod 400 /etc/secret.kf && \
 chown mongodb:mongodb /etc/secret.kf 

CMD ["mongod"]
```

## Step 4: Tạo secre.kf và mongod.conf
```
openssl rand -base64 768 > secret.kf
```

```
# mongod.conf

# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# Where and how to store data.
storage:
  dbPath: /data/db
  journal:
    enabled: true
#  engine:
#  wiredTiger:

# how the process runs
processManagement:
 # fork: true  # fork and run in background
 # pidFilePath: /var/run/mongodb/mongod.pid  # location of pidfile
  timeZoneInfo: /usr/share/zoneinfo

# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0  # Enter 0.0.0.0,:: to bind to all IPv4 and IPv6 addresses or, alternatively, use the net.bindIpAll setting.


security:
  authorization: "enabled"
  keyFile: /etc/secret.kf
#operationProfiling:

replication:
  replSetName: "marketplace_nft"
#sharding:

## Enterprise-Only Options

#auditLog:

#snmp:
```

## Step 5: Tạo file script chạy init config mongodb_configuaration/init-mongodb.sh

```
#!bin/bash

mongo -- "$MONGO_INITDB_DATABASE" <<EOF
  var rootUser = '$MONGO_INITDB_ROOT_USERNAME';
  var rootPassword = '$MONGO_INITDB_ROOT_PASSWORD';
  var user = '$MONGO_INITDB_USERNAME';
  var passwd = '$MONGO_INITDB_PASSWORD';
  var userBackup = '$MONGO_INITDB_USERNAME_BACKUP';
  var passwdBackup = '$MONGO_INITDB_PASSWORD_BACKUP';
  var admin = db.getSiblingDB('admin');
  var dbName = '$MONGO_INITDB_DATABASE';


  admin.auth(rootUser, rootPassword);

  db.createUser({
    user: user,
    pwd: passwd,
    roles: [
      {
        role: "readWrite",
        db: dbName
      }
    ]
  });

  db.createUser({
    user: userBackup,
    pwd: passwdBackup,
    roles: [
      {
        role: "backup",
        db: "admin"
      }
    ]
  });


EOF
```

## Step 6: Tạo 2 folder data (mount dữ liệu) và log (ghi nhật ký)

## Step 7: Tạo file docker-compose.yaml
```
version: "3.9"
services:
  mongodb:
    image: mongodb_local:latest
    container_name: stag_marketplace_nft_mongodb01
    ports:
      - "27019:27017"
    networks:
      outer:
        ipv4_address: "10.5.0.11"
    env_file:
      - .env
    volumes:
      - ./mongodb_configuration/:/docker-entrypoint-initdb.d/:ro
      - ./mongodb_configuration/init-mongodb.sh:/docker-entrypoint-initdb.d/init-mongodb.sh:ro
      - "./config/mongod.conf:/data/configdb/mongod.conf:ro"
      - "./config/secret.kf:/etc/secret.kf:ro"
      - "./data:/data/db"
      - "log:/var/log/mongodb"
    command: ["/usr/bin/mongod", "-f", "/data/configdb/mongod.conf"]
    restart: always
volumes:
  log: null
networks:
  outer:
    external:
      name: marketplace
```
## Step 8: Tạo file .env
```
# Project prefix name
PROJECT_NAME=

# Add the init root information
MONGO_INITDB_ROOT_USERNAME=
MONGO_INITDB_ROOT_PASSWORD=

# Add init readWrite user and default database
MONGO_INITDB_USERNAME=
MONGO_INITDB_PASSWORD=

MONGO_INITDB_DATABASE=

MONGO_INITDB_USERNAME_BACKUP=
MONGO_INITDB_PASSWORD_BACKUP=

MONGO_INITDB_DATABASE_FILE_STORE=
MONGO_INITDB_USERNAME_FILE_STORE=
MONGO_INITDB_PASSWORD_FILE_STORE=

# Add expose port for the services
SERVICE_MONGODB_PORT=
SERVICE_REDIS_PORT=
SERVICE_RABBITMQ_PORT=
SERVICE_RABBITMQ_MANAGEMENT_PLUGIN_PORT=
# Add network name
NETWORK_NAME=
```

## Step 9: Kiểm tra quyền toàn bộ các file
```
ls -l

sudo chmod 600

sudo chown -R user:groupuser file_name
```

## Step 10: Run 
```docker network create --subnet 10.5.0.0/24 marketplace```
```docker-compose up -d --build --force-recreate```

## Step 11: Start and config mongo REPLICATE SET
```
mongo

use admin

db.createUser({ 
    user: "userAdmin",
    pwd: "pwd",
    roles: [{
    role: "root",
    db: "admin"
    }]
})

db.createUser({ 
    user: "userReadWrite",
    pwd: "pwd",
    roles: [{
    role: "readWrite",
    db: "db_name"
    }]
})

rs.initial()

cf = rs.conf()

cf.members[0].host = "10.5.0.11:27017"

rs.reconfig(cf)
```

## Step 12: Add secondary to REPLICATE SET
```
rs.add(10.5.0.12:27017)
```
