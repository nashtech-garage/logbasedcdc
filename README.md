# Context 1: only CDC

- We have a Users table (fields: user_id, first_name, last_name) in a source PostgreSQL database.
- We have a Wages table (fields: user_id, wage) in a soure PostgreSQL database.
- We have a Users table (fields: user_id, first_name, last_name) in a sink PostgreSQL database.
- We have a Wages table (fields: user_id, wage) in a sink PostgreSQL database.
- We want to synchronize the Change Data Capture (CDC) to the tables Users and Wages in a sink PostgreSQL database when the tables Users and Wages are inserted, updated, or deleted in the source PostgreSQL database.
- We expect this synchonization happenning in near-real-time.

![alt text](https://github.com/bao2902/logbasedcdc/blob/main/LogBasedCDC_3.png)

![alt text](https://github.com/bao2902/logbasedcdc/blob/main/LogBasedCDC_1.PNG)

# Context 2: CDC + transform

- We have a Users table (fields: user_id, first_name, last_name) in a source PostgreSQL database.
- We have a Wages table (fields: user_id, wage) in a soure PostgreSQL database.
- We have a User_Wages table (fields: user_id, full_name, wage) in a sink PostgreSQL database.
- We want to synchronize the Change Data Capture (CDC) to the table User_Wages in a sink PostgreSQL database when the tables Users and Wages are inserted, updated, or deleted in the source PostgreSQL database.
- This synchonization includes the data tranforming as following:
+ User_Wages.user_id = Users.user_id
+ User_Wages.full_name = Users.first_name + ' ' + Users.last_name
+ User_Wages.wage = Wages.wage
- We expect this synchonization happenning in near-real-time.

![alt text](https://github.com/bao2902/logbasedcdc/blob/main/LogBasedCDC_4.png)

![alt text](https://github.com/bao2902/logbasedcdc/blob/main/LogBasedCDC_2.PNG)


# Environment

"docker-compose.yml" includes the following containers:
- Zookeeper
- Kafka
- kSQL database server
- kSQL database client
- Source PostgreSQL database
- Sink PostgreSQL database

"config" folder includes the following configurations:
- Source PostgreSQL config for Users and Wages tables (connect-postgres-source.properties)
- Sink PostgreSQL config for Users table (connect-postgres-sink-users.properties)
- Sink PostgreSQL config for Wages table (connect-postgres-sink-wages.properties)
- Sink PostgreSQL config for User_Wages table (connect-postgres-sink-user-wages.properties)

"plugins" folder includes the following plugins:
- Debezium PostgreSQL source connector (debezium-connector-postgres)
- Debezium JDBC sink connector (confluentinc-kafka-connect-jdbc)


# Steps to start containers:

1. Build Dockerfile

sudo docker build -t nashtech/kafka .

2. Start Docker Compose

sudo docker-compose up -d


# Steps to create source PosgreeSQL tables:

1. Access source PostgreSQL container

sudo docker exec -it  postgres-source /bin/bash

psql -U postgres

2. Create Users table and insert 1 record

CREATE TABLE users(user_id INTEGER, first_name VARCHAR(200), last_name VARCHAR(200), PRIMARY KEY (user_id));

INSERT INTO users VALUES(1, 'first 1', 'last 1');

3. Create Wages table and insert 1 record

CREATE TABLE wages(user_id INTEGER, wage integer, PRIMARY KEY (user_id));

INSERT INTO wages VALUES(1, '1000');



# Steps to create sink PosgreeSQL tables:

1. Access sink PostgreSQL container

sudo docker exec -it  postgres-sink /bin/bash

psql -U postgres

2. Create Users table

CREATE TABLE users(user_id INTEGER, first_name VARCHAR(200), last_name VARCHAR(200), PRIMARY KEY (user_id));

3. Create Wages table 

CREATE TABLE wages(user_id INTEGER, wage integer, PRIMARY KEY (user_id));

4. Create User_Wages table 

CREATE TABLE user_wages(user_id INTEGER, full_name VARCHAR(200), wage integer, PRIMARY KEY (user_id));



# Steps to create source Kafka topics:

1. Access Kafka container

sudo docker exec -t -i kafka /bin/bash

2. Start Kafka standalone cluster

cd /bin

connect-standalone /config/connect-standalone.properties /config/connect-postgres-source.properties /config/connect-postgres-sink-users.properties /config/connect-postgres-sink-wages.properties /config/connect-postgres-sink-user-wages.properties

3. Check source Kafka topics

kafka-topics --list --bootstrap-server localhost:9092


# Steps to create kSQL streams:

1. Access kSQL client

sudo docker-compose exec ksqldb-cli ksql http://ksqldb-server:8088

2. Create kSQL stream for users

CREATE STREAM stream_users (
schema varchar, 
payload STRUCT<
	before varchar,
	after STRUCT<
		user_id int,
		first_name varchar,
		last_name varchar
	>,
	source varchar,
	op varchar,
	ts_ms bigint
>
)
WITH (kafka_topic='localhost.public.users', value_format='JSON');

3. Create kSQL stream for wages

CREATE STREAM stream_wages (
schema varchar, 
payload STRUCT<
	before varchar,
	after STRUCT<
		user_id int,
		wage bigint
	>,
	source varchar,
	op varchar,
	ts_ms bigint
>
)
WITH (kafka_topic='localhost.public.wages', value_format='JSON');

4. Create kSQL stream for user_wages

CREATE STREAM stream_user_wages 
WITH (KAFKA_TOPIC='sink_database.user_wages', value_format='KAFKA', PARTITIONS=1, REPLICAS=1) 
AS 
SELECT 
'{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"user_id"}],"optional":false,"name":"sink_database.user_wages_1.Key"},"payload":{"user_id":' + CAST(stream_users.payload->after->user_id AS VARCHAR) + '}}' as key,
'{"schema":{"type":"struct","fields":[{"type":"struct","fields":[{"type":"int32","optional":false,"field":"user_id"},{"type":"string","optional":true,"field":"full_name"},{"type":"int32","optional":true,"field":"wage"}],"optional":true,"name":"sink_database.user_wages_1.Value","field":"before"},{"type":"struct","fields":[{"type":"int32","optional":false,"field":"user_id"},{"type":"string","optional":true,"field":"full_name"},{"type":"int32","optional":true,"field":"wage"}],"optional":true,"name":"sink_database.user_wages_1.Value","field":"after"},{"type":"struct","fields":[{"type":"string","optional":false,"field":"version"},{"type":"string","optional":false,"field":"connector"},{"type":"string","optional":false,"field":"name"},{"type":"int64","optional":false,"field":"ts_ms"},{"type":"string","optional":true,"name":"io.debezium.data.Enum","version":1,"parameters":{"allowed":"true,last,false"},"default":"false","field":"snapshot"},{"type":"string","optional":false,"field":"db"},{"type":"string","optional":false,"field":"schema"},{"type":"string","optional":false,"field":"table"},{"type":"int64","optional":true,"field":"txId"},{"type":"int64","optional":true,"field":"lsn"},{"type":"int64","optional":true,"field":"xmin"}],"optional":false,"name":"io.debezium.connector.postgresql.Source","field":"source"},{"type":"string","optional":false,"field":"op"},{"type":"int64","optional":true,"field":"ts_ms"}],"optional":false,"name":"sink_database.user_wages_1.Envelope"},"payload":{"before":null,"after":{"user_id":' + CAST(stream_users.payload->after->user_id AS VARCHAR) 
+ ',"full_name":"' + stream_users.payload->after->first_name + ' ' + stream_users.payload->after->last_name 
+ '","wage":' + CAST(stream_wages.payload->after->wage AS VARCHAR) 
+ '},"source":{"version":"0.10.0.Final","connector":"postgresql","name":"localhost","ts_ms":1682324643158,"snapshot":"false","db":"postgres","schema":"public","table":"user_wages","txId":831,"lsn":23268184,"xmin":null},"op":"c","ts_ms":1682324669819}}'
FROM stream_users 
INNER JOIN stream_wages 
WITHIN 1 HOURS GRACE PERIOD 15 MINUTES 
ON stream_users.payload->after->user_id = stream_wages.payload->after->user_id
PARTITION BY '{"schema":{"type":"struct","fields":[{"type":"int32","optional":false,"field":"user_id"}],"optional":false,"name":"sink_database.user_wages_1.Key"},"payload":{"user_id":' + CAST(stream_users.payload->after->user_id AS VARCHAR) + '}}'
;


# Steps to test the context 1:

1. Test case of "insert"

Access sink PostgreSQL container and check if a record with "user_id = 1" is created in Users and Wages table

select * from Users;

select * from Wages;

2. Test case of "update"

Access source PostgreSQL container and update the record with "user_id = 1"

UPDATE users SET first_name = 'first 1 updated' WHERE user_id = 1;

UPDATE wages SET wage = 1000 + 1 WHERE user_id = 1;

Access sink PostgreSQL container and check if the record with "user_id = 1" is updated

select * from Users;

select * from Wages;

3. Test case of "delete"

Access source PostgreSQL container and delete the record with "user_id = 1"

DELETE FROM users WHERE user_id = 1;

DELETE FROM wages WHERE user_id = 1;

Access sink PostgreSQL container and check if the record with "user_id = 1" is deleted

select * from Users;

select * from Wages;



# Steps to test the context 2:

1. Test case of "insert"

Access source PostgreSQL container and insert a record with "user_id = 2"

INSERT INTO users VALUES(2, 'first 2', 'last 2');

INSERT INTO wages VALUES(2, '2000');

Access sink PostgreSQL container and check if a record with "user_id = 1" is created in User_Wages table

select * from user_wages;

2. Test case of "update"

Access source PostgreSQL container and update the record with "user_id = 2"

UPDATE users SET first_name = 'first 2 updated' WHERE user_id = 2;

UPDATE wages SET wage = 2000 + 1 WHERE user_id = 2;

Access sink PostgreSQL container and check if the record with "user_id = 2" is updated

select * from user_wages;

3. Test case of "delete"

Access source PostgreSQL container and delete the record with "user_id = 2"

DELETE FROM users WHERE user_id = 2;

DELETE FROM wages WHERE user_id = 2;

Access sink PostgreSQL container and check if the record with "user_id = 2" is deleted

select * from user_wages;

