```
helm package charts/helm-base --destination .cr-release-packages


CR_TOKEN=<personal access token>
CR_OWNER=cheddarwhizzy
CR_GIT_REPO=helm-charts
CR_PACKAGE_PATH=.cr-release-packages
CR_GIT_BASE_URL=https://api.github.com/
CR_GIT_UPLOAD_URL=https://uploads.github.com/

cr upload

cr index -i ./index.yaml -c https://cheddarwhizzy.github.io/helm-charts/
```
