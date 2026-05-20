terraform {
  backend "s3" {
    bucket         = "coupon-prod-tf-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-1"
    encrypt        = true
    kms_key_id     = "alias/coupon-prod-tf-state"
    dynamodb_table = "coupon-prod-tf-state-lock"
  }
}
