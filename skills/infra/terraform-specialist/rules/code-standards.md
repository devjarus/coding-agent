# Terraform Code Standards

## File Layout (Module or Root)
```
module-name/
  main.tf          # Primary resources
  variables.tf     # Input variable declarations
  outputs.tf       # Output value declarations
  locals.tf        # Local value computations
  data.tf          # Data source declarations
  versions.tf      # terraform{} and required_providers{}
  README.md        # Module documentation
```

## versions.tf Template
```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "prod/networking/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "myapp-terraform-locks"
    encrypt        = true
  }
}
```

## Variable Validation Example
```hcl
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}
```

## Lifecycle Rules
```hcl
resource "aws_db_instance" "main" {
  # ... arguments ...

  lifecycle {
    prevent_destroy       = true   # Protect production databases
    create_before_destroy = true   # Zero-downtime replacement
    ignore_changes        = [password]  # Managed externally
  }
}
```

## For Each vs Count
- Prefer `for_each` with a `map` or `set` over `count` -- `count`-based resources shift indices on removal
- Use `count = var.enabled ? 1 : 0` only for simple enable/disable toggles
