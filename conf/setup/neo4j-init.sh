#!/bin/bash
set -e

cp -r /source/* /plugins/
chmod 744 /plugins/*.jar

if [[ ! -f /var/lib/neo4j/conf/neo4j.conf ]] || [[ -z "$(grep 'server.config.strict_validation.enabled=false' /var/lib/neo4j/conf/neo4j.conf)" ]]; then
    echo server.config.strict_validation.enabled=false >>/var/lib/neo4j/conf/neo4j.conf
    echo dbms.security.procedures.unrestricted=apoc.*,gds.* >>/var/lib/neo4j/conf/neo4j.conf
else
    echo "Neo4j configuration already set."
fi

if [[ ! -f /var/lib/neo4j/conf/apoc.conf ]] || [[ -z "$(grep 'apoc.import.file.enabled=true' /var/lib/neo4j/conf/apoc.conf)" ]]; then
    echo apoc.import.file.enabled=true >>/var/lib/neo4j/conf/apoc.conf
    echo apoc.export.file.enabled=true >>/var/lib/neo4j/conf/apoc.conf
else
    echo "APOC plugin configuration already set."
fi

cat /var/lib/neo4j/conf/neo4j.conf
cat /var/lib/neo4j/conf/apoc.conf
