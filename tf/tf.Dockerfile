FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y gnupg software-properties-common wget curl vim jq unzip

RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    gpg --no-default-keyring \
    --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    --fingerprint && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list

RUN apt update && apt-get install -y terraform

RUN echo "alias tf=terraform" >> ~/.bashrc &&\
    echo "export AWS_DEFAULT_REGION=eu-central-1" >> ~/.bashrc &&\
    . ~/.bashrc

WORKDIR /home/tf

CMD [ "tail", "-f", "/dev/null" ]


