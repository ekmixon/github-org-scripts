VENV_NAME:=venv
github3_version:=1.1.0
port := 10001
image_to_use := offboard-py3
container_user_name := ghjupyter

DOCKER_OPTS :=

.PHONY: help
help:
	@echo "Targets available"
	@echo ""
	@echo "    help          this message"
	@echo "    build         create a docker image based on working directory"
	@echo "    run-dev       run a docker image previously created"
	@echo "    run-update    run with modifiable current directory"
	@echo "    jupyter 	 run local (non docker) jupyter server for development"
	@echo "    $(VENV_NAME)  create a local virtualenv for old style development"

$(VENV_NAME):
	virtualenv --python=python3.7 $@
	. $(VENV_NAME)/bin/activate && echo req*.txt | xargs -n1 pip install -r
	@echo "Virtualenv created in $(VENV_NAME). You must activate before continuing."
	false

SHELL := /bin/bash
.PHONY: build
# we use a file url to avoid including work files in the production
# image. During development, you may prefer a bare dot "." to pick up
# local changes, and remove the `--ref ` option
build:
	-docker rmi $(image_to_use):$(github3_version) 2>/dev/null
	$(SHELL) -c '  \
		repo2docker --image-name "$(image_to_use):$(github3_version)" \
			--user-name $(container_user_name) \
			--no-run \
			--ref $$(git show-ref --verify --hash --head HEAD) \
			file://$$PWD/.git \
		; \
	'

# For `run-dev`, we use the configs baked into the image at the time of
# the build, so we get what we expect.
.PHONY: run-dev
run-dev:
	$(SHELL) -c ' ( export GITHUB_PAT=$$(pass show Mozilla/moz-hwine-PAT) ; \
		[[ -z $$GITHUB_PAT ]] && exit 3 ; \
		export CIS_CLIENT_ID=$$(pass show Mozilla/person_api_client_id 2>/dev/null) ; \
		export CIS_CLIENT_SECRET=$$(pass show Mozilla/person_api_client_secret 2>/dev/null) ; \
		docker run --rm --publish-all \
			--env "GITHUB_PAT" \
			--env "CIS_CLIENT_ID" \
			--env "CIS_CLIENT_SECRET" \
			--publish $(port):8888 \
			$(image_to_use):$(github3_version) \
		& \
		job_pid=$$! ; \
		sleep 5 ; \
		docker ps --filter "ancestor=$(image_to_use):$(github3_version)" ; \
		wait $$job_pid ; \
	) '

# For `run-update`, we're mapping the current directory atop the home
# directory
.PHONY: run-update
run-update:
	$(SHELL) -c ' ( export GITHUB_PAT=$$(pass show Mozilla/moz-hwine-PAT) ; \
		[[ -z $$GITHUB_PAT ]] && exit 3 ; \
		export CIS_CLIENT_ID=$$(pass show Mozilla/person_api_client_id 2>/dev/null) ; \
		export CIS_CLIENT_SECRET=$$(pass show Mozilla/person_api_client_secret 2>/dev/null) ; \
		docker run --rm --publish-all \
			$(DOCKER_OPTS) \
			--env "GITHUB_PAT" \
			--env "CIS_CLIENT_ID" \
			--env "CIS_CLIENT_SECRET" \
			--publish $(port):8888 \
			--volume "$$PWD/notebooks:/home/$(container_user_name)/notebooks" \
			$(image_to_use):$(github3_version) \
		& \
		job_pid=$$! ; \
		sleep 5 ; \
		docker ps --filter "ancestor=$(image_to_use):$(github3_version)" ; \
		wait $$job_pid ; \
	) '

.PHONY: jupyter
jupyter:
	$(SHELL) -c ' ( export GITHUB_PAT=$$(pass show Mozilla/moz-hwine-PAT) ; \
		[[ -z $$GITHUB_PAT ]] && exit 3 ; \
		export CIS_CLIENT_ID=$$(pass show Mozilla/person_api_client_id 2>/dev/null) ; \
		export CIS_CLIENT_SECRET=$$(pass show Mozilla/person_api_client_secret 2>/dev/null) ; \
		jupyter-notebook ; \
	) '

.PHONY: debug-update
debug-update:
	$(MAKE) DOCKER_OPTS="--security-opt=seccomp:unconfined" run-update


# vim: noet ts=8
