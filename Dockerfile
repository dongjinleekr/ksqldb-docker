FROM ghcr.io/graalvm/graalvm-ce:java8-21.0.0

ARG ksqldb_version=5.5.2

LABEL org.label-schema.name="ksqlDB" \
      org.label-schema.description="ksqlDB" \
      org.label-schema.build-date="${build_date}" \
      org.label-schema.vcs-url="https://github.com/dongjinleekr/ksqldb-docker" \
      org.label-schema.vcs-ref="${vcs_ref}" \
      org.label-schema.version="${ksqldb_version}" \
      org.label-schema.schema-version="1.0" \
      maintainer="dongjin@apache.org"

ENV KSQLDB_VERSION=$ksqldb_version
ENV KSQLDB_HOME=/etc/ksqldb
ENV PATH ${PATH}:${KSQLDB_HOME}/bin

# see: https://github.com/confluentinc/ksql
# mvn clean package -DskipTests -Pdist
COPY ksqldb-package-${KSQLDB_VERSION}-package /etc/ksqldb-${KSQLDB_VERSION}

# common
# converters/confluent-common
# converters/rest-utils
# converters/confluentinc-kafka-connect-avro-converter-5.5.2
# converters/confluentinc-kafka-connect-json-schema-converter-5.5.2
# converters/confluentinc-kafka-connect-protobuf-converter-5.5.2
COPY common /usr/share/java/common

# custom
COPY custom /usr/share/java/custom

COPY start-ksqldb-server.sh /tmp/

RUN microdnf install -y hostname \
 && chmod a+x /tmp/*.sh \
 && mv /tmp/start-ksqldb-server.sh /usr/bin \
 && sync \
 && ln -s /etc/ksqldb-${KSQLDB_VERSION} ${KSQLDB_HOME}

# Use "exec" form so that it runs as PID 1 (useful for graceful shutdown)
CMD ["start-ksqldb-server.sh"]
