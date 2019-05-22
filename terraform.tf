terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/brutalismbot.tf"
    region = "us-east-1"
  }
}

provider archive {
  version = "~> 1.0"
}

provider aws {
  access_key = "${var.aws_access_key_id}"
  profile    = "${var.aws_profile}"
  region     = "${var.aws_region}"
  secret_key = "${var.aws_secret_access_key}"
  version    = "~> 2.0"
}

module brutalismbot {
  source                   = "github.com/brutalismbot/terraform-aws-brutalismbot"
  release                  = "${var.release}"
  repo                     = "${var.repo}"
  slack_client_id          = "${var.slack_client_id}"
  slack_client_secret      = "${var.slack_client_secret}"
  slack_oauth_error_uri    = "${var.slack_oauth_error_uri}"
  slack_oauth_redirect_uri = "${var.slack_oauth_redirect_uri}"
  slack_oauth_success_uri  = "${var.slack_oauth_success_uri}"
  slack_signing_secret     = "${var.slack_signing_secret}"
  slack_signing_version    = "${var.slack_signing_version}"
  slack_token              = "${var.slack_token}"
}

variable aws_access_key_id {
  description = "AWS Access Key ID."
  default     = ""
}

variable aws_secret_access_key {
  description = "AWS Secret Access Key."
  default     = ""
}

variable aws_profile {
  description = "AWS Profile."
  default     = ""
}

variable aws_region {
  description = "AWS Region."
  default     = "us-east-1"
}

variable release {
  description = "Release tag."
}

variable repo {
  description = "Project repository."
  default     = "https://github.com/brutalismbot/brutalismbot"
}

variable slack_client_id {
  description = "Slack Client ID."
}

variable slack_client_secret {
  description = "Slack Client Secret."
}

variable slack_oauth_error_uri {
  description = "Slack OAuth error URI."
}

variable slack_oauth_redirect_uri {
  description = "Slack OAuth redirect URI."
}

variable slack_oauth_success_uri {
  description = "Slack OAuth success URI."
}

variable slack_signing_secret {
  description = "Slack signing secret."
}

variable slack_signing_version {
  description = "Slack signing version."
  default     = "v0"
}

variable slack_token {
  description = "Slack bot OAuth token."
}
