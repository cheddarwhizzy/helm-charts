# Setting up GHCR Image Pull Access

## Option 1: Make Repository Public (Easiest)

1. Go to: https://github.com/orgs/cheddarwhizzy/packages?repo_name=helm-charts
2. Find the package: `argocd-scm-k8s-plugin`
3. Click on the package
4. Go to "Package settings"
5. Scroll down to "Danger Zone"
6. Click "Change visibility" → Select "Public"
7. Confirm

## Option 2: Use Image Pull Secrets (Recommended for Private Repos)

### Step 1: Create GitHub Personal Access Token

1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name: `ghcr-k8s-image-pull`
4. Select scope: `read:packages`
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again!)

### Step 2: Create Kubernetes Secret

Create the secret in the `argocd` namespace:

```bash
kubectl create secret docker-registry ghcr-image-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=cheddarwhizzy \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  --namespace=argocd
```

Or if you want to use a GitHub Personal Access Token with a different username:

```bash
# Use your GitHub username as docker-username
kubectl create secret docker-registry ghcr-image-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=<YOUR_GITHUB_USERNAME> \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  --namespace=argocd
```

### Step 3: Update values.yaml

Add the imagePullSecrets to your values.yaml:

```yaml
plugin:
  imagePullSecrets:
    - name: ghcr-image-pull-secret
```

### Step 4: Verify Secret

```bash
kubectl get secret ghcr-image-pull-secret -n argocd
```

### Alternative: Use Service Account

You can also attach the imagePullSecret to a service account:

```yaml
plugin:
  serviceAccount:
    create: true
    name: cheddarwhizzy-scm-k8s-plugin
    imagePullSecrets:
      - name: ghcr-image-pull-secret
```

## Option 3: Use GitHub Actions to Auto-Push

If you're pushing from GitHub Actions, you can automatically make packages public or set up proper authentication:

```yaml
- name: Publish package
  run: |
    docker push ghcr.io/cheddarwhizzy/argocd-scm-k8s-plugin:0.1.0
    docker push ghcr.io/cheddarwhizzy/argocd-scm-k8s-plugin:latest
```

Make sure your GitHub Actions workflow has the `packages: write` permission.

