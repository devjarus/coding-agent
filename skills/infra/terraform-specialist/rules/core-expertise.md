# Terraform Core Expertise

## HCL Fundamentals
- **Resources**: meta-arguments (`depends_on`, `count`, `for_each`, `provider`, `lifecycle`), and timeouts
- **Variables**: `type`, `description`, `default`, and `validation` blocks; sensitive handling
- **Outputs**: export values for other modules; mark sensitive outputs
- **Locals**: derived values, reducing repetition
- **Data Sources**: query existing infrastructure without managing it
- **Expressions**: template strings, conditionals, `for` expressions, splat, dynamic blocks
- **Functions**: `merge`, `lookup`, `flatten`, `toset`, `jsonencode`, `filebase64`, etc.

## Module Design
- Reusable modules with clear input/output contracts; document every variable and output
- Root modules compose child modules; max 2-3 levels of nesting
- Pin module sources to specific git tags or registry versions -- never `?ref=main`
- Structure for Registry: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md`
- Backward-compatible inputs/outputs; use `precondition` for deprecation warnings

## State Management
- Remote backends: S3+DynamoDB (AWS), GCS (GCP), Azure Blob, or Terraform Cloud
- State locking to prevent concurrent `apply`
- Separate state by environment and layer (networking/compute/data)
- `terraform import` for existing resources; document import steps
- State surgery via `terraform state mv`/`rm` -- never manually edit `.tfstate`
- State files contain secrets; encrypt at rest

## Provider Configuration
- **AWS**: region, profile, assume_role, default_tags, endpoint overrides
- **GCP**: project, region, credentials, impersonated service accounts
- **Azure**: subscription, features block, service principal auth
- **Kubernetes**: cluster endpoint from data source, exec-based auth
- Multi-provider aliases for multi-region or multi-account
- Always specify `required_providers` with `source` and `version` constraints

## Terraform Workflow
- `terraform init` after any provider/module version change
- `terraform plan` -- always inspect before applying; save with `-out`
- `terraform apply` -- apply saved plan files in CI; `-target` only for urgent hotfixes
- `terraform destroy` -- protect production with `prevent_destroy`
- Workspaces for lightweight env isolation; prefer separate root modules for different configs
