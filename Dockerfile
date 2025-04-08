FROM centos:latest

# Install Apache and necessary tools
RUN yum install -y httpd \
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
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]

# Expose port 80
EXPOSE 80 22
