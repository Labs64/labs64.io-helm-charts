#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:-all}
REGISTRY="localhost:5005"

build_auditflow() {
    echo "=== Building auditflow images ==="
    (
        cd ../labs64.io-auditflow/auditflow-be
        mvn -B clean package -DskipTests -q
        docker build -t ${REGISTRY}/auditflow:latest .
    )
    (
        cd ../labs64.io-auditflow/auditflow-transformer
        docker build -t ${REGISTRY}/auditflow-transformer:latest .
    )
    (
        cd ../labs64.io-auditflow/auditflow-sink
        docker build -t ${REGISTRY}/auditflow-sink:latest .
    )
    docker push ${REGISTRY}/auditflow:latest
    docker push ${REGISTRY}/auditflow-transformer:latest
    docker push ${REGISTRY}/auditflow-sink:latest
}

build_checkout() {
    echo "=== Building checkout images ==="
    (
        cd ../labs64.io-checkout/checkout-be
        mvn -B clean package -DskipTests -q
        docker build -t ${REGISTRY}/checkout:latest .
    )
    (
        cd ../labs64.io-checkout/checkout-fe
        docker build -t ${REGISTRY}/checkout-ui:latest .
    )
    docker push ${REGISTRY}/checkout:latest
    docker push ${REGISTRY}/checkout-ui:latest
}

build_payment_gateway() {
    echo "=== Building payment-gateway image ==="
    (
        cd ../labs64.io-payment-gateway/payment-gateway-be
        mvn -B clean package -DskipTests -q
        docker build -t ${REGISTRY}/payment-gateway:latest .
    )
    docker push ${REGISTRY}/payment-gateway:latest
}

build_traefik_authproxy() {
    echo "=== Building traefik-authproxy image ==="
    (
        cd ../labs64.io-gateway/traefik-authproxy
        docker build -t ${REGISTRY}/traefik-authproxy:latest .
    )
    docker push ${REGISTRY}/traefik-authproxy:latest
}

build_customer_portal() {
    echo "=== Building customer-portal-ui image ==="
    (
        cd ../labs64.io-customer-portal/customer-portal-fe
        docker build -t ${REGISTRY}/customer-portal-ui:latest .
    )
    docker push ${REGISTRY}/customer-portal-ui:latest
}

case "$TARGET" in
    all)
        build_auditflow
        build_checkout
        build_payment_gateway
        build_traefik_authproxy
        build_customer_portal
        ;;
    auditflow)
        build_auditflow
        ;;
    checkout)
        build_checkout
        ;;
    payment-gateway)
        build_payment_gateway
        ;;
    traefik-authproxy|gateway)
        build_traefik_authproxy
        ;;
    customer-portal|customer-portal-ui)
        build_customer_portal
        ;;
    *)
        echo "Unknown target: $TARGET"
        echo "Valid targets: all, auditflow, checkout, payment-gateway, traefik-authproxy, customer-portal"
        exit 1
        ;;
esac

echo "=== All requested images built and pushed ==="
curl -s http://${REGISTRY}/v2/_catalog || echo "Warning: could not connect to local registry at http://${REGISTRY}"
