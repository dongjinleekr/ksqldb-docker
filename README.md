ksqldb-docker (graalvm ce)
=====

Dockerfile for [ksqldb](https://github.com/confluentinc/ksql), based on [Oracle Linux + GraalVM CE](https://hub.docker.com/r/oracle/graalvm-ce).

Tags and releases
-----------------

As of present, available tags are:

- `5.5.2` (graalvm ce 21.0.0-java8)

# How to Run

The following configuration shows how to configure a ksqldb cluster with this Docker image in Kubernetes cluster, with a Kafka cluster available in `djlee-kafka-headless` service.

Note:

- For configuring Kafka cluster, see [here](https://github.com/dongjinleekr/kafka-docker).
- For configuring Schema Registry cluster, see [here](https://github.com/helm/charts/tree/master/incubator/schema-registry).
- **This configuration is intended for dev or testing purpose; it may be used in production environment, but I can't give any guarantees in that respect.**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: djlee-ksqldb
  labels:
    app: djlee-ksqldb
spec:
  replicas: 2
  selector:
    matchLabels:
      app: djlee-ksqldb
  template:
    metadata:
      labels:
        app: djlee-ksqldb
    spec:
      containers:
        - name: djlee-ksqldb
          image: dongjinleekr/ksqldb:5.5.2
          imagePullPolicy: IfNotPresent
          ports:
            - name: ksqldb-rest
              containerPort: 8088
            - name: ksqldb-jmx
              containerPort: 5555
          env:
            - name: KSQL_BOOTSTRAP_SERVERS
              value: "djlee-kafka-0.djlee-kafka-headless:9092,djlee-kafka-1.djlee-kafka-headless:9092,djlee-kafka-2.djlee-kafka-headless:9092,djlee-kafka-3.djlee-kafka-headless:9092"
            - name: KSQL_KSQL_SERVICE_ID
              value: "djlee-ksqldb-service"
            - name: KSQL_KSQL_SCHEMA_REGISTRY_URL
              value: "djlee-schema-registry-service"
            - name: KSQL_HEAP_OPTS
              value: "-Xms512M -Xmx512M"
            - name: HOSTNAME_COMMAND
              value: hostname
            - name: JMX_PORT
              value: "5555"
---
apiVersion: v1
kind: Service
metadata:
  name: djlee-ksqldb-service
  labels:
    app: djlee-ksqldb-service
spec:
  ports:
    - name: ksqldb-rest
      port: 8088
    - name: ksqldb-jmx
      port: 5555
  selector:
    app: djlee-ksqldb
```

As you can see above, a environment variale named with `KSQL_A_B` corresponds to a configuration property of `a.b` unless it is [KSQL environment variable](https://docs.ksqldb.io/en/latest/operate-and-deploy/installation/server-config/) (listed below). For example, `KSQL_BOOTSTRAP_SERVERS` corresponds to `bootstrap.servers` property in ksqldb configuration).

- `KSQL_CLASSPATH`
- `KSQL_CONFIG_DIR`
- `KSQL_DIR`
- `KSQL_GC_LOG_OPTS`
- `KSQL_LOG4J_OPTS`
- `KSQL_HEAP_OPTS`
- `KSQL_JMX_OPTS`
- `KSQL_JVM_PERFORMANCE_OPTS`
- `KSQL_LOG`
- `KSQL_OPTS`
- `JMX_PORT`

`HOSTNAME_COMMAND` is 

The following configuration shows how to spin up a ksqldb client pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ksqldb-client
  namespace: default
spec:
  containers:
    - name: ksqldb-client
      image: dongjinleekr/ksqldb:5.5.2
      command:
        - sh
        - -c
        - "exec tail -f /dev/null"
```

Now you can connect to the ksqldb cluster with:

```sh
kubectl -n default exec -it ksqldb-client -- ksql http://djlee-ksqldb-service:8088
```

# How to Build

To build the image yourself, do following:

1. Place built packages (following) into the directory.

- `common`: common-package-${version}-package
- `rest-utils`: ${project-dir}/rest-utils-package-${version}-package
- `ksqldb`: ${project-dir}/ksqldb-package-${version}-package

2. Build Docker image

```
KSQLDB_VERSION=5.5.2 && docker build --build-arg ksqldb_version=${KSQLDB_VERSION} -t dongjinleekr/ksqldb:${KSQLDB_VERSION} .
```

