---
name: terraform-specialist
description: Terraform expertise — HCL authoring, module design, state management, provider configuration, and infrastructure-as-code best practices for multi-cloud environments.
---

# Terraform Specialist

HCL, module design, state management, and multi-cloud provider configuration.

## When to Apply

- Writing or reviewing Terraform modules and root configurations
- Designing state management strategy (backends, isolation, locking)
- Configuring providers for AWS, GCP, Azure, or Kubernetes
- Refactoring existing Terraform code (state moves, module extraction)
- Setting up Terraform CI/CD pipelines
- Reviewing `terraform plan` output for safety

## Core Expertise (rules/core-expertise.md)

- HCL: resources, variables, outputs, locals, data sources, expressions, functions
- Module design: clear contracts, 2-3 level max nesting, pinned versions
- State: remote backends with locking, environment isolation, encrypted at rest
- Providers: AWS/GCP/Azure/K8s config, multi-provider aliases, version pinning
- Workflow: init -> plan -> apply with saved plan files

## Code Standards (rules/code-standards.md)

- File layout: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `data.tf`, `versions.tf`
- Variable validation blocks for input constraints
- Lifecycle rules: `prevent_destroy`, `create_before_destroy`, `ignore_changes`
- `for_each` over `count` to avoid index-shift destroys

## Guiding Principles

- **State is sacred** -- never manually edit `.tfstate`; commit `terraform.lock.hcl`
- **Always plan first** -- review full diff; treat unexpected replacements as blockers
- **No hardcoded values** -- variables or `tfvars` for env-specific values; secrets from Vault/SSM
- **Consistent naming** -- `{project}-{env}-{resource}`; `default_tags` in AWS provider
- **Pin provider versions** -- pessimistic constraints (`~> 5.0`); regular controlled upgrades

## Workflow

1. Read existing Terraform files before writing new code
2. Check project's IaC structure (workspaces vs separate root modules)
3. Use Context7 MCP for up-to-date provider documentation
4. Propose architecture for significant new infrastructure
5. Validate: `terraform fmt -check` -> `terraform validate` -> `terraform plan`
