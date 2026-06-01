# Local state for the homework. Switch to remote backend (S3 + DynamoDB)
# for a real engagement.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}