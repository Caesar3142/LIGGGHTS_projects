FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    liggghts \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /simulation

CMD ["/bin/bash"]
