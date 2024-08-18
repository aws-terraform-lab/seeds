
LOCAL_SEEDS_TOPIC=
LOCAL_SEEDS_REGISTRY_NAME=kafka-study
LOCAL_SEEDS_CONNECT_NAME=kafka-avro-to-s3-parquet-glue


SECURITY_PROTOCOL=PLAINTEXT
INTERNAL_BROKER_ENDPOINT=broker:9092
GLUE_REGISTRY=kafka-study

include .env
include Makefile.terraform.AWS


seeds-event-receiver-docker-build:
	docker build -f ./event-receiver/Dockerfile -t event-receiver ./event-receiver


seeds-infra-build:
	docker-compose build

seeds-infra-up: seeds-event-receiver-docker-build
	docker-compose up

seeds-infra-down:
	docker-compose down


seeds-send-events:
	docker-compose \
		run \
		-e HOST=http://event-receiver:5000 \
		event-receiver \
	 	python client.py

seeds-get-connect-logs:
	docker-compose \
		logs connect

seeds-replace-connector:
	jq \
		'.name = "${LOCAL_SEEDS_CONNECT_NAME}" | \
		.config.topics = "user_login-v2" | \
		.config."key.converter.schemaName" = "user_login-v2-key" | \
		.config."key.converter.registry.name" = "${GLUE_REGISTRY_NAME}" | \
		.config."value.converter.schemaName" = "user_login-v2-value" | \
		.config."value.converter.registry.name" = "${GLUE_REGISTRY_NAME}"' \
		./connect/sink/kafka-avro-to-s3-parquet-glue.json > /tmp/connector-sink.json

seeds-connect-delete-kafka-avro-to-s3-parquet-glue:
	curl -X DELETE http://localhost:8083/connectors/${LOCAL_SEEDS_CONNECT_NAME}

seeds-connect-kafka-avro-to-s3-parquet-glue: seeds-replace-connector
	curl -X POST http://localhost:8083/connectors \
	-H 'Content-Type: application/json' \
	-d @/tmp/connector-sink.json