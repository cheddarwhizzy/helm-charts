```
cr package charts/helm-base


CR_TOKEN=<personal access token>
CR_OWNER=cheddarwhizzy
CR_GIT_REPO=helm-charts
CR_GIT_BASE_URL=https://api.github.com/
CR_GIT_UPLOAD_URL=https://uploads.github.com/

cr upload

cr index --push -i ./index.yaml -c https://cheddarwhizzy.github.io/helm-charts/
```
