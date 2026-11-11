terraform {
  backend "s3" {
    bucket       = "taskly-terraform-state-686699774218-eu-central-1"
    key          = "taskly/staging/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
