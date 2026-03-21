-include .env
export

check-env:
	@if [ -z "$(RHSM_USERNAME)" ] || [ -z "$(RHSM_PASSWORD)" ]; then \
	  echo "ERROR: RHSM_USERNAME and RHSM_PASSWORD must be set in .env"; \
	  exit 1; \
	fi

ubi97: check-env
	DOCKER_BUILDKIT=1 docker build -f Dockerfile.ubi97 -t adtest:ubi97 --no-cache .

shell-ubi97:
	@docker run -it --entrypoint=/bin/bash adtest:ubi97

almalinux:
	DOCKER_BUILDKIT=1 docker build -f Dockerfile.almalinux97 \
	  -t adtest:almalinux .

shell-almalinux:
	@docker run -it --entrypoint=/bin/bash adtest:almalinux
