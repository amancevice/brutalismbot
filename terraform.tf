terraform {
  backend s3 {
    bucket  = "brutalismbot"
    key     = "terraform/brutalismbot.tf"
    region  = "us-east-1"
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

locals {
  tags {
    App     = "brutalismbot"
    Name    = "brutalismbot.com"
    Release = "${var.release}"
    Repo    = "${var.repo}"
  }
}

data aws_acm_certificate cert {
  domain      = "brutalismbot.com"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data aws_kms_key key {
  key_id = "alias/brutalismbot"
}

data aws_iam_policy_document s3 {
  statement {
    actions   = ["s3:*"]
    resources = [
      "${aws_s3_bucket.brutalismbot.arn}",
      "${aws_s3_bucket.brutalismbot.arn}/*",
    ]
  }
}

data aws_route53_zone website {
  name = "brutalismbot.com."
}

data aws_s3_bucket_object lambda {
  bucket = "${aws_s3_bucket.brutalismbot.bucket}"
  key    = "terraform/pkg/brutalismbot-${var.release}.zip"
}

resource aws_api_gateway_base_path_mapping api {
  api_id      = "${module.slackbot.api_id}"
  domain_name = "${aws_api_gateway_domain_name.api.domain_name}"
  stage_name  = "${module.slackbot.api_stage_name}"
  base_path   = "slack"
}

resource aws_api_gateway_domain_name api {
  certificate_arn = "${data.aws_acm_certificate.cert.arn}"
  domain_name     = "api.brutalismbot.com"
}

resource aws_cloudwatch_dashboard dash {
  dashboard_name = "Brutalismbot"
  dashboard_body = "${file("${path.module}/dashboard.json")}"
}

resource aws_cloudwatch_event_rule cache {
  description         = "Cache posts from /r/brutalism to S3"
  name                = "${aws_lambda_function.cache.function_name}"
  schedule_expression = "rate(1 hour)"
}

resource aws_cloudwatch_event_target cache {
  rule  = "${aws_cloudwatch_event_rule.cache.name}"
  arn   = "${aws_lambda_function.cache.arn}"
}

resource aws_cloudwatch_log_group install {
  name              = "/aws/lambda/${aws_lambda_function.install.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group cache {
  name              = "/aws/lambda/${aws_lambda_function.cache.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group mirror {
  name              = "/aws/lambda/${aws_lambda_function.mirror.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_cloudwatch_log_group uninstall {
  name              = "/aws/lambda/${aws_lambda_function.uninstall.function_name}"
  retention_in_days = 30
  tags              = "${local.tags}"
}

resource aws_iam_role_policy s3_access {
  name   = "s3"
  policy = "${data.aws_iam_policy_document.s3.json}"
  role   = "${module.slackbot.role_name}"
}

resource aws_lambda_function install {
  description       = "Install OAuth credentials"
  function_name     = "brutalismbot-install"
  handler           = "handlers.install"
  role              = "${module.slackbot.role_arn}"
  runtime           = "ruby2.5"
  s3_bucket         = "${data.aws_s3_bucket_object.lambda.bucket}"
  s3_key            = "${data.aws_s3_bucket_object.lambda.key}"
  s3_object_version = "${data.aws_s3_bucket_object.lambda.version_id}"
  tags              = "${local.tags}"
  timeout           = 3

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function cache {
  description       = "Cache posts from /r/brutalism"
  function_name     = "brutalismbot-cache"
  handler           = "handlers.cache"
  role              = "${module.slackbot.role_arn}"
  runtime           = "ruby2.5"
  s3_bucket         = "${data.aws_s3_bucket_object.lambda.bucket}"
  s3_key            = "${data.aws_s3_bucket_object.lambda.key}"
  s3_object_version = "${data.aws_s3_bucket_object.lambda.version_id}"
  tags              = "${local.tags}"
  timeout           = 15

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function mirror {
  description       = "Mirror posts from /r/brutalism"
  function_name     = "brutalismbot-mirror"
  handler           = "handlers.mirror"
  role              = "${module.slackbot.role_arn}"
  runtime           = "ruby2.5"
  s3_bucket         = "${data.aws_s3_bucket_object.lambda.bucket}"
  s3_key            = "${data.aws_s3_bucket_object.lambda.key}"
  s3_object_version = "${data.aws_s3_bucket_object.lambda.version_id}"
  tags              = "${local.tags}"
  timeout           = 30

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_function uninstall {
  description       = "Uninstall brutalismbot from workspace"
  function_name     = "brutalismbot-uninstall"
  handler           = "handlers.uninstall"
  role              = "${module.slackbot.role_arn}"
  runtime           = "ruby2.5"
  s3_bucket         = "${data.aws_s3_bucket_object.lambda.bucket}"
  s3_key            = "${data.aws_s3_bucket_object.lambda.key}"
  s3_object_version = "${data.aws_s3_bucket_object.lambda.version_id}"
  tags              = "${local.tags}"

  environment {
    variables {
      S3_BUCKET = "${aws_s3_bucket.brutalismbot.bucket}"
    }
  }
}

resource aws_lambda_permission install {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.install.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${module.slackbot.oauth_topic_arn}"
}

resource aws_lambda_permission cache {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cache.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.cache.arn}"
}

resource aws_lambda_permission mirror {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.mirror.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.brutalismbot.arn}"
}

resource aws_lambda_permission uninstall {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.uninstall.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.uninstall.arn}"
}

resource aws_route53_record api {
  name    = "${aws_api_gateway_domain_name.api.domain_name}"
  type    = "A"
  zone_id = "${data.aws_route53_zone.website.id}"

  alias {
    evaluate_target_health = true
    name                   = "${aws_api_gateway_domain_name.api.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.api.cloudfront_zone_id}"
  }
}

resource aws_s3_bucket brutalismbot {
  acl           = "private"
  bucket        = "brutalismbot"
  force_destroy = false
}

resource aws_s3_bucket_notification mirror {
  bucket = "${aws_s3_bucket.brutalismbot.id}"

  lambda_function {
    id                  = "mirror"
    lambda_function_arn = "${aws_lambda_function.mirror.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "posts/v1/"
    filter_suffix       = ".json"
  }
}

resource aws_sns_topic uninstall {
  name = "brutalismbot_event_app_uninstalled"
}

resource aws_sns_topic_subscription install {
  endpoint  = "${aws_lambda_function.install.arn}"
  protocol  = "lambda"
  topic_arn = "${module.slackbot.oauth_topic_arn}"
}

resource aws_sns_topic_subscription uninstall {
  endpoint  = "${aws_lambda_function.uninstall.arn}"
  protocol  = "lambda"
  topic_arn = "${aws_sns_topic.uninstall.arn}"
}

module secrets {
  source                   = "amancevice/slackbot-secrets/aws"
  version                  = "1.1.0"
  kms_key_alias            = "alias/brutalismbot"
  kms_key_tags             = "${local.tags}"
  secret_name              = "brutalismbot"
  secret_tags              = "${local.tags}"
  slack_client_id          = "${var.slack_client_id}"
  slack_client_secret      = "${var.slack_client_secret}"
  slack_oauth_error_uri    = "${var.slack_oauth_error_uri}"
  slack_oauth_redirect_uri = "${var.slack_oauth_redirect_uri}"
  slack_oauth_success_uri  = "${var.slack_oauth_success_uri}"
  slack_signing_secret     = "${var.slack_signing_secret}"
  slack_signing_version    = "${var.slack_signing_version}"
  slack_token              = "${var.slack_token}"
}

module slackbot {
  source               = "amancevice/slackbot/aws"
  version              = "13.5.1"
  api_description      = "Brutalismbot REST API"
  api_name             = "brutalismbot"
  api_stage_name       = "v1"
  api_stage_tags       = "${local.tags}"
  base_url             = "/slack"
  kms_key_id           = "${data.aws_kms_key.key.key_id}"
  lambda_function_name = "brutalismbot-api"
  lambda_layer_name    = "brutalismbot"
  lambda_tags          = "${local.tags}"
  log_group_tags       = "${local.tags}"
  role_name            = "brutalismbot"
  role_tags            = "${local.tags}"
  secret_name          = "brutalismbot"
  sns_topic_prefix     = "brutalismbot_"
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
  default     = "https://github.com/amancevice/brutalismbot"
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
