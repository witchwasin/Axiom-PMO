# syntax=docker/dockerfile:1
#
# Clean-room walkthrough environment for issue #8.
#
# The point is not to run the test suite -- CI already does that. The point is
# to put someone who does not know this repository in front of the README with
# a machine that carries none of their own state, and find out where the
# instructions fail them.
#
# Everything verified so far was verified by people who already knew the answer,
# which is the weakest kind of evidence for a getting-started experience.
#
# WHAT THIS CANNOT PROVE
#   This is a Linux container. Linux/macOS support is EXPERIMENTAL; Windows
#   PowerShell 5.1 is the reference platform. A clean walkthrough here does not
#   close the Windows half of issue #8 -- that needs a Windows machine or a
#   Windows container. Say which one you walked when you report findings.
#
# TWO MODES, answering two different questions.
#
#   PREREQS=none        (default)
#     Nothing but git and curl. The walker has to work out how to get
#     PowerShell and Node from the documentation alone.
#     Answers: "does the README tell a stranger how to get started at all?"
#
#   PREREQS=documented
#     Exactly what README.md names as prerequisites -- PowerShell 7 and
#     Node.js -- and nothing else.
#     Answers: "if you install precisely what the docs ask for, does it work?"
#     That question is machine-checkable; see clean-room/README.md.

FROM ubuntu:24.04

ARG PREREQS=none
ARG PWSH_VERSION=7.4.6

ENV DEBIAN_FRONTEND=noninteractive \
    AXIOM_CLEAN_ROOM=1 \
    AXIOM_PREREQS=${PREREQS}

# git to clone, curl to follow whatever install instructions the docs give,
# ca-certificates so both work over TLS. Nothing else: an editor, jq, or a
# build toolchain would quietly paper over a missing instruction.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl ca-certificates less \
 && rm -rf /var/lib/apt/lists/*

# The documented prerequisites, installed only when asked for. The apt method
# in Microsoft's install-ubuntu page is the documented route; the tarball below
# is its equivalent and is stable across Ubuntu releases, which matters more in
# a throwaway container than matching the page step for step.
RUN if [ "$PREREQS" = "documented" ]; then \
      set -eux; \
      apt-get update; \
      apt-get install -y --no-install-recommends nodejs; \
      arch="$(dpkg --print-architecture)"; \
      case "$arch" in \
        amd64) pwsh_arch=x64 ;; \
        arm64) pwsh_arch=arm64 ;; \
        *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
      esac; \
      curl -fsSL -o /tmp/pwsh.tar.gz \
        "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${pwsh_arch}.tar.gz"; \
      mkdir -p /opt/microsoft/powershell/7; \
      tar zxf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/7; \
      chmod +x /opt/microsoft/powershell/7/pwsh; \
      ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh; \
      rm -f /tmp/pwsh.tar.gz; \
      rm -rf /var/lib/apt/lists/*; \
    fi

# A non-root user with an empty home. Running as root hides permission problems
# a real reader would hit, and a fresh HOME means no shell history, no dotfiles,
# and no credentials leaking a shortcut into the walkthrough.
RUN useradd --create-home --shell /bin/bash walker
USER walker
WORKDIR /home/walker

COPY --chown=walker:walker briefing.sh /home/walker/.briefing.sh
RUN printf '%s\n' 'source ~/.briefing.sh' >> /home/walker/.bashrc

CMD ["/bin/bash"]
