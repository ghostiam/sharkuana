FROM nixos/nix

# Set the working directory for the application
WORKDIR /app

COPY flake.nix flake.lock ./

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

RUN nix --experimental-features 'nix-command flakes' develop
