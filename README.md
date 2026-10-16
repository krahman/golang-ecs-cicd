# Golang EKS CI/CD starter

## Scope
Runnable Go API, multi-stage distroless Dockerfile, Helm chart, GitHub CI workflow and staged CD workflow, plus Terraform for ECR and GitHub OIDC publishing role. **EKS cluster, networking, GitHub deployment roles, access entries and external ingress are prerequisites** and are intentionally not fabricated by this template. See setup below. Production is gated by a GitHub Environment approval.

## Setup
1. Install Go 1.25, Docker, AWS CLI v2, kubectl, Helm 3, Terraform. Create or identify two EKS clusters (staging and production), with node capacity, cluster endpoint reachable by GitHub runners (otherwise use a self-hosted runner). Configure VPC/subnets/NAT or VPC endpoints, IAM, EKS access entries, DNS/TLS and ingress separately. Enable the Kubernetes NetworkPolicy implementation before relying on network policy enforcement.
2. Create ECR and publishing role: `cd infra && terraform init && terraform apply -var='github_owner=YOUR_ORG' -var='github_repo=YOUR_REPO'`. If the GitHub OIDC provider already exists, import it instead of creating a duplicate. Set GitHub repo variables `AWS_REGION`, `AWS_ECR_ROLE_ARN`, `ECR_REPOSITORY`.
3. For each environment, create a *separate* IAM role trusting GitHub OIDC sub `repo:OWNER/REPO:environment:staging` or `repo:OWNER/REPO:environment:production` and audience `sts.amazonaws.com`. Grant only `eks:DescribeCluster` on its target cluster, then create EKS access entries and Kubernetes RBAC allowing deployments, services, PDBs, network policies, and Helm release Secrets in `go-api` namespace. Bootstrap namespace and namespace-scoped access before first deploy. Do not use cluster-admin permissions in production. Grant ECR pull permissions to worker node IAM roles (or appropriate Fargate execution roles).
4. Create GitHub environments `staging` and `production`, require reviewers for production, and limit production deployments to main. Define environment variables `AWS_REGION`, `EKS_CLUSTER`, `ECR_IMAGE` (full ECR URL, e.g. 123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/go-api), and environment role ARN `AWS_EKS_STAGING_ROLE_ARN` or `AWS_EKS_PROD_ROLE_ARN` respectively. `ECR_IMAGE` must point to the same repository in both environments for digest promotion.
5. Push to main. `ci.yml` tests, scans and publishes an immutable commit-SHA image to ECR. `deploy.yml` runs only after successful main push CI, deploys staging and awaits protected production approval. Use GitHub Actions logs to inspect the result.
6. Manual rollback: `helm history go-api -n go-api` then `helm rollback go-api <REVISION> -n go-api --wait --timeout 5m`. `--atomic` also automatically rolls back failed Helm upgrades. Rollback of a failed *new installation* removes the release.

## Security and operational hardening before production
- Pin every GitHub Action by full reviewed commit SHA; sample uses readable tags for maintenance convenience.
- Enable branch protection, CODEOWNERS, required CI checks, production environment approvals, and GitHub Actions least privilege.
- `workflow_run` executes privileged CD after CI; this template checks successful main push, uses immutable SHA checkout and verifies digest format. Harden artifact provenance and verify digest corresponds to the expected ECR repository before use. Do not run untrusted PR code with deploy credentials.
- Add artifact signing (cosign), SBOM and provenance attestation, policy verification, SAST, dependency vulnerability checks, secret scanning, and license checks according to your requirements.
- Set explicit ingress, TLS certificates, WAF if public, external secrets/Secrets Manager CSI, logging, metrics, alerting, HPA, and disaster recovery. A ClusterIP service is intentionally private; add an AWS Load Balancer Controller-managed ingress or gateway as appropriate.
- For full production HA, use multiple AZs, autoscaling, node disruption controls, topology spread constraints and tested rollback/recovery drills. Consider separate AWS accounts for staging and production.
- Validate Helm charts with `helm lint deploy/helm/go-api` and `helm template go-api deploy/helm/go-api --set image.repository=example.invalid/go-api --set image.digest=sha256:$(printf 'a%.0s' {1..64})`.
- Note Dockerfile uses `golang:1.25-alpine` and `distroless/static-debian12:nonroot` tags; pin both to verified immutable digests for reproducibility. Verify supported Go patch versions and CVEs before release.
- The pipeline builds twice (scan then publish), which is acceptable as a starter but not strict binary-identical promotion. For higher assurance build once to OCI tar, scan and push the same image digest, or use trusted registry scanning/signing with policy gates.
- Ensure the CI workflow name matches `workflow_run.workflows`, and avoid `cancel-in-progress` in CD. Recheck concurrent pushes and implement a release queue if strict promotion order is required.

## Local checks
`go test -race ./...` / `docker build -t go-api:local .` / `docker run --rm -p 8080:8080 go-api:local` / `curl localhost:8080/readyz`.
