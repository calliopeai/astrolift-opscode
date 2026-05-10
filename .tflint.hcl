config {
  format = "compact"
}

# Modules ship variables that callers may reference even if the module's
# own resources don't use them (scaffolding for future wiring + caller
# contract stability). Disable the rule rather than churn the var list.
rule "terraform_unused_declarations" {
  enabled = false
}

plugin "aws" {
  enabled = true
  version = "0.34.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "google" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
