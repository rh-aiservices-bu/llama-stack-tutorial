#!/bin/bash

SSL_CERT="/certs/cert.pem"
SSL_KEY="/certs/key.pem"

CMD="streamlit run app.py --server.port=8501 --server.address=0.0.0.0"

if [[ -f "$SSL_CERT" && -f "$SSL_KEY" ]]; then
    CMD="$CMD --server.sslCertFile=$SSL_CERT --server.sslKeyFile=$SSL_KEY"
else
    echo "SSL certs not found. Starting without HTTPS..."
fi

exec $CMD
