FROM ubuntu:20.04

# Install ansible and its dependencies
RUN \
  apt-get update && \
  apt-get -y install \
    ansible \
    rsync && \
  apt-get autoclean && \
  apt-get clean

# Install extra plugins
# Not needed (yet)
#RUN \
#  ansible-galaxy collection install community.docker

# Prepare SSH and Ansible environment
# - We will mount host's id_rsa to allow connection to the server
# - We will mount known_hosts to only accept once the server's fingerprint
# - Set the inventory file
# - Ansible conf files will be mounted during run instead of copied during build.
#   This way, all updates are immediatly available
RUN \
  mkdir -p \
    /root/.ssh \
    /ansible && \
  rm /etc/ansible/hosts && \
  ln -s /ansible/hosts /etc/ansible/hosts

# We will mount ansible configuration files here
WORKDIR /ansible
