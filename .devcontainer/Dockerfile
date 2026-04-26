# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.2
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

# Ensure binding is always 0.0.0.0
# Binds the server to all IP addresses of the container, so it can be accessed from outside the container.
ENV BINDING="0.0.0.0"

# Pre-install gems at image build time (network available), so postCreateCommand
# bundle check passes without needing internet access inside the running container.
USER vscode
ENV PATH="/home/vscode/.local/bin:/home/vscode/.local/share/mise/shims:${PATH}"
WORKDIR /workspaces/runmodel
COPY --chown=vscode:vscode .ruby-version Gemfile Gemfile.lock ./
RUN bundle install

# Install Node.js and Claude Code CLI
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code
USER vscode
