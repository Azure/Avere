FROM golang:1.16

RUN apt update && apt install -y unzip jq

WORKDIR /root

# Build Terraform Avere provider
RUN git clone https://github.com/Azure/Avere.git
WORKDIR /root/Avere/src/terraform/providers/terraform-provider-avere
RUN go mod download
RUN go mod tidy
RUN go build
RUN mkdir -p ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/1.1.1/linux_amd64
RUN cp terraform-provider-avere ~/.terraform.d/plugins/registry.terraform.io/hashicorp/avere/1.1.1/linux_amd64

WORKDIR /root

# clean up unneeded files
RUN rm -rf /root/Avere

# install terraform to 0.15.1
RUN wget https://releases.hashicorp.com/terraform/0.15.1/terraform_0.15.1_linux_amd64.zip
RUN unzip terraform_0.15.1_linux_amd64.zip && rm terraform_0.15.1_linux_amd64.zip
RUN mv terraform /usr/bin/terraform

# Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash
