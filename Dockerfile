ARG RUNTIME=ruby2.5

FROM lambci/lambda:build-${RUNTIME} AS install
COPY --from=hashicorp/terraform:0.11.14 /bin/terraform /bin/
COPY Gemfile /var/task/
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION
ARG AWS_SECRET_ACCESS_KEY
ARG BUNDLE_PATH=/opt/ruby/gems/2.5.0
RUN bundle install --system
COPY *.tf /var/task/
RUN terraform init

FROM install AS build
ARG AWS_ACCESS_KEY_ID
ARG AWS_DEFAULT_REGION
ARG AWS_SECRET_ACCESS_KEY
ARG TF_VAR_release
ARG TF_VAR_slack_client_id
ARG TF_VAR_slack_client_secret
ARG TF_VAR_slack_oauth_error_uri
ARG TF_VAR_slack_oauth_redirect_uri
ARG TF_VAR_slack_oauth_success_uri
ARG TF_VAR_slack_signing_secret
ARG TF_VAR_slack_signing_version
ARG TF_VAR_slack_token
RUN terraform fmt -check
RUN terraform validate
RUN terraform plan -out terraform.tfplan
COPY lib /var/task/
RUN zip package.zip *.rb
