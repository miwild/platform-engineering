#!/bin/bash

# Script to validate Terraform configurations
# This script validates the shared/AWS environment only

set -euo pipefail

echo "=== Validating Terraform Configurations ==="

# Check that we're in the right directory
if [[ ! -d "infra/AWS" ]]; then
  echo "ERROR: Must run this script from the repository root"
  exit 1
fi

# Validate each module
for module in infra/AWS infra/AWS/ACM infra/AWS/RDS; do
  echo "Validating $module..."
  (
    cd "$module"
    terraform init -backend=false -input=false
    terraform validate
  )
  echo "✓ $module validation successful"
done

echo "=== All validations passed ==="