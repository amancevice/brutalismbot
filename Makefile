image   := brutalismbot/brutalismbot.com
images   = $(shell docker image ls --filter reference=$(image) --quiet)
release := $(shell git describe --tags)
runtime := ruby2.5

.PHONY: build

pkg/brutalismbot-$(release).zip: build Gemfile.lock
	mkdir -p pkg
	docker run --rm $(image):$<-$(runtime) cat package.zip > $@

Gemfile.lock: build Gemfile
	docker run --rm $(image):$<-$(runtime) cat $@ > $@

build:
	docker build \
	--build-arg AWS_ACCESS_KEY_ID \
	--build-arg AWS_DEFAULT_REGION \
	--build-arg AWS_SECRET_ACCESS_KEY \
	--build-arg RUNTIME=$(runtime) \
	--build-arg TF_VAR_release=$(release) \
	--build-arg TF_VAR_slack_client_id \
	--build-arg TF_VAR_slack_client_secret \
	--build-arg TF_VAR_slack_oauth_error_uri \
	--build-arg TF_VAR_slack_oauth_redirect_uri \
	--build-arg TF_VAR_slack_oauth_success_uri \
	--build-arg TF_VAR_slack_signing_secret \
	--build-arg TF_VAR_slack_signing_version \
	--build-arg TF_VAR_slack_token \
	--tag $(image):$@-$(runtime) \
	--target $@ .

test:
	docker-compose run --rm install
	docker-compose run --rm cache
	docker-compose run --rm mirror
	docker-compose run --rm uninstall
