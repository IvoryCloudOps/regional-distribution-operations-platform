terraform {
    backend "s3" {
    region = "us-east-1"
    encrypt = true
    bucket = "ivorycloudops-distribution-tfstate"
    key = "regional-distribution-operations-platform/terraform.tfstate"
    use_lockfile = true
}
}

