#!/bin/bash -e

# Store original IFS config, so we can restore it at various stages
ORIG_IFS=$IFS

if [[ -z "$KSQL_BOOTSTRAP_SERVERS" ]]; then
    echo "ERROR: missing mandatory config: KSQL_BOOTSTRAP_SERVERS"
    exit 1
fi

if [[ -n "$KSQL_HEAP_OPTS" ]]; then
    sed -r -i 's/(export KSQL_HEAP_OPTS)="(.*)"/\1="'"$KSQL_HEAP_OPTS"'"/g' "$KSQLDB_HOME/bin/ksql-server-start"
    unset KSQL_HEAP_OPTS
fi

if [[ -n "$HOSTNAME_COMMAND" ]]; then
    HOSTNAME_VALUE=$(eval "$HOSTNAME_COMMAND")

    # Replace any occurences of _{HOSTNAME_COMMAND} with the value
    IFS=$'\n'
    for VAR in $(env); do
        if [[ $VAR =~ ^KSQL_ && "$VAR" =~ "_{HOSTNAME_COMMAND}" ]]; then
            eval "export ${VAR//_\{HOSTNAME_COMMAND\}/$HOSTNAME_VALUE}"
        fi
    done
    IFS=$ORIG_IFS
fi

# Try and configure minimal settings or exit with error if there isn't enough information
if [[ -z "$KSQL_LISTENERS" ]]; then
    export KSQL_LISTENERS="http://0.0.0.0:8088"
fi

if [[ -z "$KSQL_ADVERTISED_LISTENERS" ]]; then
    if [[ -z "$HOSTNAME_VALUE" ]]; then
        echo "ERROR: No advertised listener or hostname configuration provided in environment."
        echo "       Please define KSQL_ADVERTISED_LISTENERS or HOSTNAME or HOSTNAME_COMMAND"
        exit 1
    fi

    export KSQL_ADVERTISED_LISTENERS="http://${HOSTNAME_VALUE}:8088"
fi

#Issue newline to config file in case there is not one already
echo "" >> "$KSQLDB_HOME/etc/ksqldb/ksql-server.properties"

(
    function updateConfig() {
        key=$1
        value=$2
        file=$3

        # Omit $value here, in case there is sensitive information
        echo "[Configuring] '$key' in '$file'"

        # If config exists in file, replace it. Otherwise, append to file.
        if grep -E -q "^#?$key=" "$file"; then
            sed -r -i "s@^#?$key=.*@$key=$value@g" "$file" #note that no config values may contain an '@' char
        else
            echo "$key=$value" >> "$file"
        fi
    }

    # grep -rohe KSQL[A-Z0-0_]* /etc/ksqldb/bin | sort | uniq | tr '\n' '|'
    EXCLUSIONS="|KSQL_CLASSPATH|KSQL_CONFIG_DIR|KSQL_DIR|KSQL_GC_LOG_OPTS|KSQL_LOG4J_OPTS|KSQL_HEAP_OPTS|KSQL_JMX_OPTS|KSQL_JVM_PERFORMANCE_OPTS|KSQL_LOG|KSQL_OPTS|"

    # Read in env as a new-line separated array. This handles the case of env variables have spaces and/or carriage returns. See wurstmeister/kafka-docker#313
    IFS=$'\n'
    for VAR in $(env)
    do
        env_var=$(echo "$VAR" | cut -d= -f1)
        if [[ "$EXCLUSIONS" = *"|$env_var|"* ]]; then
            echo "Excluding $env_var from broker config"
            continue
        fi

        if [[ $env_var =~ ^KSQL_ ]]; then
            ksql_name=$(echo "$env_var" | cut -d_ -f2- | tr '[:upper:]' '[:lower:]' | tr _ .)
            updateConfig "$ksql_name" "${!env_var}" "$KSQLDB_HOME/etc/ksqldb/ksql-server.properties"
        fi

        if [[ $env_var =~ ^LOG4J_ ]]; then
            log4j_name=$(echo "$env_var" | tr '[:upper:]' '[:lower:]' | tr _ .)
            updateConfig "$log4j_name" "${!env_var}" "$KSQLDB_HOME/etc/ksqldb/log4j.properties"
        fi
    done
)

# Add all jars in /usr/share/java/common, /usr/share/java/custom, /usr/local/share/java/custom to classpath
USR_SHARE_COMMON=$(find /usr/share/java/common -name '*.jar' -type f -printf ':%p\n' | sort -u | tr -d '\n')
USR_SHARE_CUSTOM=$(find /usr/share/java/custom -name '*.jar' -type f -printf ':%p\n' | sort -u | tr -d '\n')
USR_LOCAL_SHARE_CUSTOM=$(find /usr/local/share/java/custom -name '*.jar' -type f -printf ':%p\n' | sort -u | tr -d '\n')

export KSQL_CLASSPATH=$KSQL_CLASSPATH$USR_SHARE_COMMON$USR_SHARE_CUSTOM$USR_LOCAL_SHARE_CUSTOM

if [[ -n "$CUSTOM_INIT_SCRIPT" ]] ; then
  eval "$CUSTOM_INIT_SCRIPT"
fi

exec "$KSQLDB_HOME/bin/ksql-server-start" "$KSQLDB_HOME/etc/ksqldb/ksql-server.properties"
