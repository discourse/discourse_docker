# Use an existing docker image as a base
FROM ubuntu

# Update and install sudo
RUN apt-get update && apt-get install -y sudo

# Create a new user
RUN useradd -m discourse

# Set the entrypoint
ENTRYPOINT ["sudo", "-H", "-u", "discourse", "-E", "/bin/bash", "-c"]

# Set the default command
CMD ["echo Hello, world!"]
