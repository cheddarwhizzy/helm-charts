#### Microservice Base Helm Chart
This provides common config & environment variables across all python3 backend microservices.

### Service to Service communication
Kubernetes provides environment variables in the form of `SERVICE_NAME_SERVICE_HOST` and `SERVICE_NAME_SERVICE_PORT`. (the endpoint for `account-service` would be `ACCOUNT_SERVICE_SERVICE_HOST` `ACCOUNT_SERVICE_SERVICE_PORT`)

### Adding Environment Variables
See `<repository-name>/k8s/<repository-name>/values.yaml`
```
helm-base:
  envName: integration
  ...
  containers:
  - name: new-service
    env:
      MY_ENV_VAR: some-static-var
      SOME_VAR_VAULT: vault:secret/data/environments/%envName#SOME_VAR_VAULT
```


### Adding Nginx Routes
See the `repository-name/k8s/service-name/values.yaml` `ingress` section

**Options**
- name: (Required)
- path: (Required)
- type: [api host portal hydra admin] (default api)
- secretName: Override wildcard SSL cert
- port: Override .service.ports[0]
- public: Exposed to outside world (default true)
- annotations: Kubernetes Nginx Ingress annotations to add to route
- snippets: Additional nginx config to add to the route

**Example API Route**
```
    - name: root
      path: /new-service/(.*)
      rewriteTarget: /$1
```

**Example Primary Host Route**
```
    - name: root
      path: /new-service/(.*)
      type: host
      rewriteTarget: /$1
```

**Advanced Route**
```
    - name: portal-assets-maps
      path: /(header_)?(main|runtime|polyfills|vendor|common|styles|[0-9]+)(.[a-zA-Z0-9_]+)?.(js|css)(.map)$
      type: portal
      secretName: portal-wildcard
      port: 81
      public: false
      annotations:
        nginx.ingress.kubernetes.io/use-regex: "true"
```
