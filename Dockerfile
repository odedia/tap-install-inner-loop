FROM projects.registry.vmware.com/educates/base-environment AS builder
ARG PIVNET_API_TOKEN
# Download Insight CLI via Pivnet
RUN curl -L -o /tmp/pivnet https://github.com/pivotal-cf/pivnet-cli/releases/download/v3.0.1/pivnet-linux-amd64-3.0.1 && \
    chmod 777 /tmp/pivnet
RUN /tmp/pivnet login --api-token=${PIVNET_API_TOKEN}
RUN /tmp/pivnet download-product-files --product-slug='supply-chain-security-tools' --release-version='v1.0.0-beta.4' --product-file-id=1130451 && \
    mv insight-1.0.1_linux_amd64 /tmp/insight && \
    chmod 777 /tmp/insight

FROM projects.registry.vmware.com/educates/base-environment AS workshop

# All the direct Downloads need to run as root as they are going to /usr/local/bin
USER root
# TMC
RUN curl -L -o /usr/local/bin/tmc $(curl -s https://tanzupaorg.tmc.cloud.vmware.com/v1alpha/system/binaries | jq -r 'getpath(["versions",.latestVersion]).linuxX64') && \
    chmod 755 /usr/local/bin/tmc

# Policy Tools
RUN curl -L -o /usr/local/bin/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64 && \
    chmod 755 /usr/local/bin/opa

# TBS
RUN curl -L -o /usr/local/bin/kp https://github.com/vmware-tanzu/kpack-cli/releases/download/v0.4.1/kp-linux-0.4.1 && \
    chmod 755 /usr/local/bin/kp

# Tanzu CLI
RUN curl -o /usr/local/bin/tanzu https://storage.googleapis.com/tanzu-cli/artifacts/core/latest/tanzu-core-linux_amd64 && \
    chmod 755 /usr/local/bin/tanzu
COPY plugins/apps-artifacts /tmp/apps-artifacts
COPY plugins/apps-artifacts /tmp/apps-artifacts/
RUN tanzu plugin install apps --local /tmp/apps-artifacts --version v0.2.0

# Downloading gcloud package
RUN curl https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz > /tmp/google-cloud-sdk.tar.gz

# Installing gcloud SDK
RUN mkdir -p /usr/local/gcloud \
    && tar -C /usr/local/gcloud -xvf /tmp/google-cloud-sdk.tar.gz \
    && /usr/local/gcloud/google-cloud-sdk/install.sh

# Add CA Cert for Trust
COPY files/wildcard.crt /usr/local/share/ca-certificates/ca.crt
RUN update-ca-certificates

# Adding the package path to local
ENV PATH $PATH:/usr/local/gcloud/google-cloud-sdk/bin

# Install SCP Plugin
COPY kubectl-scp /usr/local/bin/kubectl-scp

# Add Accelerator Plugin
COPY plugins/acc-artifacts /tmp/acc-artifacts
COPY plugins/acc-artifacts /tmp/acc-artifacts/
RUN tanzu plugin install accelerator --local /tmp/acc-artifacts --version v0.4.1

# Knative
RUN curl -L -o /usr/local/bin/kn https://github.com/knative/client/releases/download/v0.26.0/kn-linux-amd64 && \
    chmod 755 /usr/local/bin/kn

# Install hey for load testing an app
RUN curl -L -o /usr/local/bin/hey https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 && \
    chmod 755 /usr/local/bin/hey

# Requirements for Live Update
RUN apt-get update && apt-get install -y unzip openjdk-11-jdk
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version 4.0.0
RUN mv /usr/bin/code-server /opt/code-server/bin/code-server
COPY tanzu-vscode-extension.vsix /opt/tanzu-vscode-extension.vsix
RUN code-server --install-extension redhat.vscode-yaml && \
    code-server --install-extension redhat.java && \
    code-server --install-extension vscjava.vscode-java-pack && \
    code-server --install-extension /opt/tanzu-vscode-extension.vsix
RUN mv /opt/code-server/extensions/ms-toolsai.jupyter-2021.6.99 /opt/code-server/extensions/ms-kubernetes-tools.vscode-kubernetes-tools-1.2.4 /opt/code-server/extensions/golang.go-0.27.2 /opt/code-server/extensions/humao.rest-client-0.24.3 /opt/code-server/extensions/ms-python.python-2021.8.1159798656 /opt/code-server/extensions/pivotal.eduk8s-vscode-helper-0.0.1 /home/eduk8s/.local/share/code-server/extensions/
RUN echo -n 'export PATH=~/.local/bin:$PATH' >> /etc/profile
RUN chown eduk8s:users /home/eduk8s/.cache
RUN curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash
RUN chown -R eduk8s:users /home/eduk8s/.tilt-dev
RUN curl -L https://github.com/tohjustin/kube-lineage/releases/download/v0.4.2/kube-lineage_linux_amd64.tar.gz --output /tmp/kube-lineage_linux_amd64.tar.gz && \
    tar -zxvf /tmp/kube-lineage_linux_amd64.tar.gz -C /tmp && \
    mv /tmp/kube-lineage /usr/local/bin/kubectl-lineage
RUN apt-get install -y ruby && \
    curl -L -o /tmp/eksporter.tar.gz https://github.com/Kyrremann/kubectl-eksporter/releases/download/v1.7.0/eksporter.tar.gz && \
    tar -zxvf /tmp/eksporter.tar.gz -C /tmp && \
    mv /tmp/eksporter.rb /usr/local/bin/kubectl-eksporter

# Adding Pivnet CLI and installing Insight CLI
COPY --from=builder /tmp/insight /usr/local/bin/insight
COPY --from=builder /tmp/pivnet /usr/local/bin/pivnet

# Set user to eduk8s
USER 1001

# Install Tilt for eduk8s user in local path under homedir
RUN curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | PATH=~/.local/bin:$PATH bash
RUN fix-permissions /home/eduk8s