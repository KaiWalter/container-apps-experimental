ARG DOTNET_VARIANT="3.1"
ARG PULUMI_VERSION=latest
ARG INSTALL_NODE="true"
ARG NODE_VERSION="lts/*"

# --------------------------------------------------------------------------------

FROM debian:11-slim AS builder
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y \
    curl \
    build-essential \
    git

RUN if [ "$PULUMI_VERSION" = "latest" ]; then \
    curl -fsSL https://get.pulumi.com/ | bash; \
    else \
    curl -fsSL https://get.pulumi.com/ | bash -s -- --version $PULUMI_VERSION ; \
    fi

# --------------------------------------------------------------------------------

FROM mcr.microsoft.com/vscode/devcontainers/dotnetcore:0-${DOTNET_VARIANT}

RUN if [ "${INSTALL_NODE}" = "true" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"; fi

COPY --from=builder /root/.pulumi/bin/pulumi /pulumi/bin/pulumi
COPY --from=builder /root/.pulumi/bin/*-dotnet* /pulumi/bin/

ENV PATH "/pulumi/bin:${PATH}"