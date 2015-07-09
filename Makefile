.PHONY: all gobuild static checkdockerfile docker release certs test coverage clean

all: release

# Dynamic go build; useful in that it does not have -a so it won't recompile
# everything every time
gobuild:
	cd agent && godep go build -o ../out/amazon-ecs-agent .

# Basic go build
static:
	cd agent && CGO_ENABLED=0 godep go build -a -x -ldflags '-s' -o ../out/amazon-ecs-agent .

# Phony target to make sure we never clobber someone's dockerfile. TODO, better
# cleaning up of the dockerfile we ln so that this doesn't trigger incorrectly
checkdockerfile:
	@if [[ -e Dockerfile ]]; then echo "Dockerfile exists; please remove or rename it before building"; exit 1; fi

docker: checkdockerfile
	@ln -s scripts/dockerfiles/Dockerfile.build Dockerfile
	docker build -t "DOCKER_REGISTRY_SERVER:5000/amazon-ecs-agent-clean-build:make" .
	docker run -v "$(shell pwd)/out:/out" "DOCKER_REGISTRY_SERVER:5000/amazon-ecs-agent-clean-build:make"
	@rm -f Dockerfile

# Release packages our agent into a "scratch" based dockerfile
release: checkdockerfile certs out/amazon-ecs-agent
	@ln -s scripts/dockerfiles/Dockerfile.release Dockerfile
	docker build -t "DOCKER_REGISTRY_SERVER:5000/amazon-ecs-agent-clean:make" .
	@echo "Built Docker image \"DOCKER_REGISTRY_SERVER:5000/amazon-ecs-agent-clean:make\""
	@rm -f Dockerfile

# There's two ways to build this; default to the docker way
out/amazon-ecs-agent: docker


# We need to bundle certificates with our scratch-based container
certs: misc/certs/ca-certificates.crt
misc/certs/ca-certificates.crt:
	docker build -t "DOCKER_REGISTRY_SERVER:5000/amazon-ecs-agent-clean-cert-source:make" misc/certs/
	docker run "DOCKER_REGISTRY_SERVER:5000/amazon-ecs-agent-clean-cert-source:make" cat /etc/ssl/certs/ca-certificates.crt > misc/certs/ca-certificates.crt


test:
	cd agent && godep go test -v -cover ./...

test-in-docker: checkdockerfile
	@ln -s scripts/dockerfiles/Dockerfile.test Dockerfile
	docker build -t "DOCKER_REGISTRY_SERVER:5000/amazon-ecs-agent-clean-test:make" .
	# Privileged needed for docker-in-docker so integ tests pass
	docker run --privileged "DOCKER_REGISTRY_SERVER:5000/amazon-ecs-agent-clean-test:make"
	@rm -f Dockerfile

coverage:


clean:
	rm -f misc/certs/ca-certificates.crt &> /dev/null
	rm -f out/amazon-ecs-agent &> /dev/null
