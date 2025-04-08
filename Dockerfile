FROM ubuntu:20.04

# Set the time zone non-interactively to avoid tzdata prompt
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y tzdata

# Install Apache and necessary tools
RUN apt-get install -y \
  apache2 \
  zip \
  unzip \
  curl

# Set working directory for Apache
WORKDIR /var/www/html

# Download the Spering template
RUN curl -L -o spering.zip https://www.free-css.com/assets/files/free-css-templates/download/page296/spering.zip

# Unzip the template
RUN unzip spering.zip

# Move the contents to the working directory
RUN cp -rvf spering/* . && rm -rf spering spering.zip

# Start Apache in the foreground
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]

# Expose port 80
EXPOSE 80 22
