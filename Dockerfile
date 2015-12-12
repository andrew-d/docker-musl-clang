FROM debian:jessie
MAINTAINER Andrew Dunham <andrew@du.nham.ca>

# Set up environment variables
ENV MUSL_VERSION 1.1.12

# Install build tools
ADD . /root/
RUN /root/build.sh
