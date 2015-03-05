package api

import (
	"strconv"
	"strings"

	"github.com/coursera/go-dockerclient"
)

const DOCKER_MINIMUM_MEMORY = 4 * 1024 * 1024 // 4MB

// Overriden returns
func (c *Container) Overridden() *Container {
	result := *c

	// We only support Command overrides at the moment
	if result.Overrides.Command != nil {
		result.Command = *c.Overrides.Command
	}

	return &result
}

// DockerConfig converts the given container in this task to the format of
// GoDockerClient's 'Config' struct
func (container *Container) DockerConfig() (*docker.Config, error) {
	return container.Overridden().dockerConfig()
}

// dockerConfig returns a docker.Config struct that represents how to start this
func (container *Container) dockerConfig() (*docker.Config, error) {
	dockerEnv := make([]string, 0, len(container.Environment))
	for envKey, envVal := range container.Environment {
		dockerEnv = append(dockerEnv, envKey+"="+envVal)
	}

	// Convert MB to B
	dockerMem := int64(container.Memory * 1024 * 1024)
	if dockerMem != 0 && dockerMem < DOCKER_MINIMUM_MEMORY {
		dockerMem = DOCKER_MINIMUM_MEMORY
	}
	dockerExposedPorts := make(map[docker.Port]struct{})

	for _, portBinding := range container.Ports {
		dockerPort := docker.Port(strconv.Itoa(int(portBinding.ContainerPort)) + "/tcp")
		dockerExposedPorts[dockerPort] = struct{}{}
	}

	config := &docker.Config{
		Image:        container.Image,
		Cmd:          container.Command,
		ExposedPorts: dockerExposedPorts,
		Env:          dockerEnv,
		Memory:       dockerMem,
		CPUShares:    int64(container.Cpu),
		VolumesFrom:  strings.Join(container.VolumesFrom, ","),
	}
	return config, nil
}
