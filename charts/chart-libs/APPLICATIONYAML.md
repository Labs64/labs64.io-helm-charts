# applicationYaml Contract

Every module chart follows this values convention for `applicationYaml`. The rendered YAML must match the consuming Spring Boot service's `@ConfigurationProperties` binding prefix — a mismatch is the root cause of config-binding defects (see I-1).

## Structure

```yaml
applicationYaml:
  # Spring Boot framework config (datasource, rabbitmq, redis, etc.)
  spring:
    rabbitmq:
      host: ...
      port: 5672
    data:
      redis:
        host: ...
        port: 6379

  # Module-specific @ConfigurationProperties(prefix = "<module>")
  <module>:
    # e.g. auditflow.pipelines, checkout.checkoutProperties
    ...

  # Transformer/sink discovery (auditflow-specific)
  transformer:
    discovery:
      mode: local  # or kubernetes
    local:
      url: "http://localhost:8081"
  sink:
    discovery:
      mode: local
    local:
      url: "http://localhost:8082"
```

## Rules

1. **`applicationYaml.spring.*`** — Spring Boot framework config. Keyed by Spring's own property paths (`spring.rabbitmq.host`, `spring.datasource.url`, etc.).

2. **`applicationYaml.<module>.*`** — The module's own configuration tree. The key must match the `@ConfigurationProperties(prefix = "<module>")` annotation on the module's properties class.
   - `auditflow.pipelines` → `AuditFlowConfiguration`
   - `checkout.checkoutProperties` → `CheckoutProperties`
   - `paymentgateway.paymentGatewayProperties` → `PaymentGatewayProperties`

3. **Top-level non-`applicationYaml` keys** — Chart/deployment concerns: `image`, `service`, `resources`, `transformer`, `sink`, `gateway`, etc. These are Helm-only and never appear in the Spring config file.

## The Binding Rule

> A value's rendered YAML path **must** match the consuming service's `@ConfigurationProperties` binding prefix.

If the service binds `auditflow.pipelines`, the chart must render:
```yaml
auditflow:
  pipelines: [...]
```

Not:
```yaml
applicationYaml:
  auditflow:
    auditflow:
      pipelines: [...]  # WRONG — double nesting
```

This is the contract that chart-lint CI validates.

## Per-Module Reference

| Module | Prefix | Key Config |
|--------|--------|------------|
| auditflow | `auditflow` | `pipelines`, `idempotency.store` |
| checkout | `checkout` | `checkoutProperties.*` |
| payment-gateway | `paymentgateway` | `paymentGatewayProperties.*` |
