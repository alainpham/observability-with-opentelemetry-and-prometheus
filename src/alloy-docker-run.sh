    docker run -d \
        --name "alloy" \
        --restart unless-stopped \
        --pid="host" \
        --uts="host" \
        -v "/etc/alloy/config.alloy:/etc/alloy/config.alloy:ro" \
        -v "/:/rootfs:ro,rslave" \
        -v "/sys:/sys:ro,rslave" \
        -v "/var/run/docker.sock:/var/run/docker.sock:rw" \
        -v "/var/log/journal:/var/log/journal:ro,rslave" \
        \
        -e PROM_URL="${PROM_URL}" \
        -e PROM_REMOTEWRITE_PATH="${PROM_REMOTEWRITE_PATH}" \
        -e PROM_USER="${PROM_USER}" \
        -e PROM_PASSWORD="${PROM_PASSWORD}" \
        -e LOKI_URL="${LOKI_URL}" \
        -e LOKI_USER="${LOKI_USER}" \
        -e LOKI_PASSWORD="${LOKI_PASSWORD}" \
        -e OTLP_URL="${OTLP_URL}" \
        -e OTLP_USER="${OTLP_USER}" \
        -e OTLP_PASSWORD="${OTLP_PASSWORD}" \
        -e PROFILES_URL="${PROFILES_URL}" \
        -e PROFILES_USER="${PROFILES_USER}" \
        -e PROFILES_PASSWORD="${PROFILES_PASSWORD}" \
        -e GCLOUD_FARO="${GCLOUD_FARO}" \
        \
        -v "/var/lib/docker:/var/lib/docker:ro" \
        -v /dev/disk/:/dev/disk:ro \
        -p "12345:12345" \
        -p "4317:4317" \
        -p "4318:4318" \
        -p "9090:9090" \
        -p "3100:3100" \
        -p "4040:4040" \
        grafana/alloy:v1.12.1 \
        run \
        --server.http.listen-addr=0.0.0.0:12345 \
        --storage.path=/data \
        /etc/alloy/config.alloy
