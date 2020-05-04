#### Microservice Base Helm Chart
This is used as a subchart dependency to quickly construct common types of Deployments and Statefulset configurations 

See [The values file](./values.yaml) for available options.

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
**Options**
- name: (Required)
- path: (Required)
- secretName: Override wildcard SSL cert
- port: Override (defaults to .Values.ingress.port)
- annotations: Kubernetes Nginx Ingress annotations to add to route

**Example Route**
```
  ingress:
    ...
    routes:
    - name: default
      host: "some.host.domain.com"
      port: 8080
      path: /
      annotations: {}
```