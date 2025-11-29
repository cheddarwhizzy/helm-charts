# Helm Base Chart

A comprehensive base Helm chart for DRY Kubernetes deployments.

## Table of Contents

- [Quick Start](#quick-start)
- [Subchart Usage](#subchart-usage)
- [Alias Structure](#alias-structure)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Gateway API](#gateway-api)
- [Cilium Service Mesh Recipes](#cilium-service-mesh-recipes)
- [License](#license)

## Quick Start

```bash
# Add as dependency in your Chart.yaml
dependencies:
  - name: helm-base
    version: "0.1.26"
    repository: "https://cheddarwhizzy.github.io/helm-charts"

# Or install directly
helm install my-app cheddarwhizzy/helm-base
```

## Subchart Usage

Use as a subchart dependency with aliases for multiple deployments:

```yaml
# Chart.yaml
dependencies:
- name: helm-base
  version: 0.1 # NEVER CHANGE THIS VERSION - LEAVE AT 0.1
  repository: https://cheddarwhizzy.github.io/helm-charts
  alias: app
- name: helm-base
  version: 0.1 # NEVER CHANGE THIS VERSION - LEAVE AT 0.1
  repository: https://cheddarwhizzy.github.io/helm-charts
  alias: migrations
```

## Alias Structure

Configure each aliased subchart in your `values.yaml`:

```yaml
# Main application (aliased as 'app')
app:
  fullnameOverride: my-app
  replicaCount: 2
  image:
    repository: my-registry/my-app
    tag: v1.0.0
  services:
    - name: web
      ports:
        - name: http
          port: 3000
  virtualservice:
    enabled: true
    host: "myapp.com"
    gateway: "istio-system/gateway"
    port: 3000

# Migration job (aliased as 'migrations')
migrations:
  fullnameOverride: my-app-migration
  kind: Job
  backoffLimit: "3"
  activeDeadlineSeconds: "1800"
  containers:
    - name: migration
      image: my-registry/my-app:v1.0.0
      command:
        - node
        - migrate
```

## Deployment

To deploy the latest subchart version:

```bash
# Update dependencies to latest version
helm dependency update

# Deploy with latest chart
helm upgrade --install my-release . -f values.yaml
```

## Configuration

See [values.yaml](./values.yaml) for complete configuration options with detailed documentation.

### Override-friendly values schemas

`helm-base` is designed to work well with layered values files (base → env → cluster → local) and with aliased subcharts. To avoid "all or nothing" list replacement and make deep merging reliable:

- **Containers & initContainers**
  - **Preferred:** map-based schema keyed by container name:
    - `containers.main`, `containers.sidecar-logger`, `initContainers.migrator`, etc.
  - **Legacy:** list-based schema (`containers: [ { name: ... } ]`) is still supported for backward compatibility.
  - Map-based containers allow higher-level values files to add `resources`, `env`, or probes to `containers.main` without redefining the entire list.

- **Volumes & volumeMounts**
  - **Preferred:** map-based schema keyed by volume/mount name:
    - `volumes.data`, `volumes.config`, `containers.main.volumeMounts.data`, etc.
  - **Legacy:** list-based `volumes: [ { name: ... } ]` and `volumeMounts: [ { name: ... } ]` remain supported.
  - Map-based volumes/mounts let overlays add or tweak a single volume or mount instead of replacing the full list.

- **env, envFrom, envRaw**
  - **env:** expected as maps, with optional grouping for clarity and deep merging:
    - `env.base.LOG_LEVEL`, `env.observability.OTEL_EXPORTER_OTLP_ENDPOINT`, `containers.main.env.featureFlags.FEATURE_X_ENABLED`, etc.
  - **envFrom/envRaw:** accept either flat lists or grouped map-of-lists; helpers flatten these into final lists for the Pod spec.
  - The chart merges `global.env` → chart-level `env` → container-level `env` so each layer can override or extend variables without losing lower layers.

Old list-based shapes for containers, volumes, and simple `env` remain supported, but the map-based/grouped styles are **recommended** for any new work or when refactoring existing values to support multiple environments and clusters.

## Gateway API

Gateway API (Gateway/HTTPRoute) support is built into the chart and follows the Kubernetes v1.3.0 specification. Enable it by setting `gatewayApi.enabled` and defining Gateways plus HTTPRoutes:

```yaml
gatewayApi:
  enabled: true
  gateways:
    - name: public
      gatewayClassName: istio
      listeners:
        - name: http
          protocol: HTTP
          port: 80
          hostname: "app.example.com"
  httpRoutes:
    - name: default
      hostnames:
        - app.example.com
      parentRefs:
        - name: public
          sectionName: http
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - service: web
              port: 3000
```

Backends default to the first service defined in `services`, so the example above automatically targets `web`. Override per backend with `serviceFullName` or `name` to point at external services, and use `gatewayAnnotations`/`httpRouteAnnotations` for shared metadata.

## Cilium Service Mesh Recipes

Helm Base can emit any Cilium CRD through `rawResources`, so you can keep service-mesh configuration next to your workloads. The snippets below cover mutual TLS, retries/timeouts, identity-aware network policies, and HTTP-layer enforcement. All examples assume Cilium Service Mesh with Envoy is already enabled in the cluster ([official guide](https://docs.cilium.io/en/stable/network/servicemesh/)).

> **Tip:** Scope these objects under the same alias you use for the workload (e.g., `app.rawResources`) so each release only renders the policies it owns.

### Mutual TLS (east–west)

Use a `CiliumClusterwideEnvoyConfig` to require TLS on both listener and upstream cluster. Cilium’s SPIFFE/SPIRE integration automatically provisions the identities.

```yaml
rawResources:
  checkout-mtls:
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideEnvoyConfig
    metadata:
      name: checkout-mtls
    spec:
      services:
        - name: checkout
          namespace: storefront
          ports:
            - port: 8080
      resources:
        listeners:
          - name: checkout_https
            address:
              socketAddress:
                address: 0.0.0.0
                portValue: 8080
            filterChains:
              - transportSocket:
                  name: envoy.transport_sockets.tls
                  typedConfig:
                    "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
                    commonTlsContext:
                      tlsCertificateSdsSecretConfigs:
                        - name: spiffe://cluster.local/ns/storefront/sa/default
                      validationContextSdsSecretConfig:
                        name: spiffe://cluster.local
                filters:
                  - name: envoy.filters.network.http_connection_manager
                    typedConfig:
                      "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                      statPrefix: checkout_inbound
                      routeConfig:
                        name: checkout_route
                        virtualHosts:
                          - name: checkout
                            domains: ["*"]
                            routes:
                              - match: { prefix: "/" }
                                route: { cluster: checkout-backend }
                      httpFilters:
                        - name: envoy.filters.http.router
        clusters:
          - name: checkout-backend
            connectTimeout: 1s
            type: STRICT_DNS
            lbPolicy: ROUND_ROBIN
            transportSocket:
              name: envoy.transport_sockets.tls
              typedConfig:
                "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
                commonTlsContext:
                  validationContextSdsSecretConfig:
                    name: spiffe://cluster.local
```

### Retries & per-route timeouts

Envoy handles retries and budgets per route. Define them inside a `CiliumEnvoyConfig` that targets the service port.

```yaml
rawResources:
  payments-retries:
    apiVersion: cilium.io/v2
    kind: CiliumEnvoyConfig
    metadata:
      name: payments-retries
      namespace: finance
    spec:
      services:
        - name: payments
          namespace: finance
          ports:
            - port: 8443
      resources:
        listeners:
          - name: payments_listener
            address:
              socketAddress:
                address: 0.0.0.0
                portValue: 8443
            filterChains:
              - filters:
                  - name: envoy.filters.network.http_connection_manager
                    typedConfig:
                      "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                      statPrefix: payments_ingress
                      requestTimeout: 6s
                      routeConfig:
                        name: payments-route
                        virtualHosts:
                          - name: payments
                            domains: ["*"]
                            routes:
                              - match: { prefix: "/" }
                                route:
                                  cluster: payments-upstream
                                  timeout: 5s
                                  retryPolicy:
                                    retryOn: "5xx,gateway-error,reset"
                                    numRetries: 3
                                    perTryTimeout: 1.5s
                                    hostSelectionRetryMaxAttempts: 2
                                    retriableStatusCodes: [429]
                      httpFilters:
                        - name: envoy.filters.http.router
        clusters:
          - name: payments-upstream
            connectTimeout: 1s
            type: STRICT_DNS
            lbPolicy: ROUND_ROBIN
            loadAssignment:
              clusterName: payments-upstream
              endpoints:
                - lbEndpoints:
                    - endpoint:
                        address:
                          socketAddress:
                            address: payments.finance.svc.cluster.local
                            portValue: 8443
```

### Identity-aware network policies

`CiliumNetworkPolicy` lets you express zero-trust rules based on pod labels, identities, and entities.

```yaml
rawResources:
  checkout-policy:
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: checkout-zero-trust
      namespace: storefront
    spec:
      endpointSelector:
        matchLabels:
          app.kubernetes.io/name: checkout
      ingress:
        - fromEndpoints:
            - matchLabels:
                app.kubernetes.io/name: payments
          toPorts:
            - ports:
                - port: "8080"
                  protocol: TCP
              rules:
                http:
                  - method: POST
                    path: "^/charge"
                  - method: GET
                    path: "^/status"
        - fromEntities: ["host"] # kubelet probes
      egress:
        - toServices:
            - k8sService:
                serviceName: inventory
                namespace: ops
          toPorts:
            - ports:
                - port: "7001"
                  protocol: TCP
```

Available selectors (`fromEndpoints`, `fromEntities`, `toGroups`, DNS/FQDN matches, etc.) are covered in the [policy reference](https://docs.cilium.io/en/stable/security/policy/).

### L7 policies & rate limits

Combine HTTP rules, headers, and optional rate limits to constrain high-value APIs.

```yaml
rawResources:
  api-l7-guardrails:
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: api-l7-guardrails
      namespace: platform
    spec:
      endpointSelector:
        matchLabels:
          app: public-api
      ingress:
        - fromEndpoints:
            - matchLabels:
                team: mobile
          toPorts:
            - ports:
                - port: "8443"
                  protocol: TCP
              rules:
                http:
                  - method: GET
                    path: "^/profile"
                    headers:
                      - name: x-request-id
                        mismatch: MATCH_PRESENT
                  - method: POST
                    path: "^/profile"
                    rateLimit:
                      average: 20
                      burst: 40
```

### Workflow summary

1. **Define CRs via `rawResources`** under the alias that deploys your workload.
2. **`helm upgrade --install`** to publish Envoy configs, network policies, and rate limits together with the app.
3. **Validate** using `kubectl -n kube-system exec -it <cilium-pod> -- hubble observe --from-pod <ns>/<pod>` or `cilium status --verbose` to confirm mTLS and L7 guards are active.

Additional references:

- Envoy traffic management in Cilium: <https://docs.cilium.io/en/stable/network/servicemesh/envoy/>
- L7/L3-L4 policy examples: <https://docs.cilium.io/en/stable/security/policy/l7-policy/>
- Identity-aware policies & entities: <https://docs.cilium.io/en/stable/security/policy/l3-policy/>

## License

MIT