-include .env
export


ubi97:
	DOCKER_BUILDKIT=1 docker build -f Dockerfile.ubi97 -t adtest:ubi97 --no-cache .

shell-ubi97:
	@docker run -it --entrypoint=/bin/bash adtest:ubi97

almalinux:
	DOCKER_BUILDKIT=1 docker build -f Dockerfile.almalinux97 \
	  -t adtest:almalinux .

shell-almalinux:
	@docker run -it --entrypoint=/bin/bash adtest:almalinux
