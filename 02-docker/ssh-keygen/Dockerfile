# Use the official Ubuntu 24.04 base image
FROM ubuntu:24.04

# Update the package manager and install Python 3 and pip
RUN apt update -y && \                              
    apt install -y python3-pip && \                 
    apt-get clean && \                              
    mkdir /ssh-keygen && \                               
    chmod 777 /ssh-keygen                               

# Copy application files to the /ssh-keygen directory in the container
COPY app.py /ssh-keygen/                                 
COPY requirements.txt /ssh-keygen/                       
COPY start_app.sh /ssh-keygen/                     

# Prepare the application environment
RUN chmod +x /ssh-keygen/start_app.sh && \         
    pip3 install -r /ssh-keygen/requirements.txt --break-system-packages 

# Expose port 8080 for the HTTP Listener
EXPOSE 8080                                         

# Set the default command to run the HTTP Listener
ENTRYPOINT [ "/ssh-keygen/start_app.sh" ]          