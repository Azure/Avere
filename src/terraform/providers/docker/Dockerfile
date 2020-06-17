FROM hashicorp/terraform:full

ENV GOPATH /go

RUN mkdir -p $GOPATH

RUN go get -v github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere; exit 0

WORKDIR $GOPATH/src/github.com/Azure/Avere/src/terraform/providers/terraform-provider-avere
RUN go mod download
RUN go mod tidy
RUN go build
RUN mkdir -p ~/.terraform.d/plugins
RUN cp terraform-provider-avere ~/.terraform.d/plugins

WORKDIR ~

ENTRYPOINT ["terraform"]