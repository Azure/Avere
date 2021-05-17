# Dockerfile for Avere Terraform Provider

This directory contains a [Dockefile](https://docs.docker.com/engine/reference/builder/) which will build a container with the following content:
 - Build a container based on the [golang image in DockerHub](https://hub.docker.com/_/golang/)
 - Install unzip package
 - Clone this git repository
 - Build the Avere terraform provider in this repository
 - Install the terraform provider in the location Terraform expects to find it
 - Install Terraform (currently version 0.15.1)
 - Install the latest version of the Azure CLI

To build the container:

 - Ensure [Docker is installed](https://docs.docker.com/desktop/) on your machine
 - Clone this repo: `git clone https://github.com/Azure/Avere.git`
 - Change to the directory with the Dockerfile: `cd Avere/src/terraform/provider/docker`
 - Build the container: `docker build ./ -t azureAvereTerraform`
   - Note: -t <VALUE> assigns the <VALUE> as a named tag to your image. It is optional

If required, you can input an argument when building the container that is used as the version number for the Avere Terraform provider:

 - `docker build ./ -t azureAvereTerraform --build-arg version=1.1.2`

You can use the image as part of a pipeline or execute it in interactive mode with the following command:

 - `docker run -i azureAvereTerraform`
