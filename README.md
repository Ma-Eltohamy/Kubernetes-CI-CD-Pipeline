![overview image](./arch.png)

# 📄 Project Overview

This project automates the deployment process of a web application using a CI/CD pipeline built with GitHub Webhooks, Jenkins, Ansible, Docker, and Kubernetes. The goal is to simulate a complete deployment workflow without relying on cloud services like AWS, using Docker containers to replicate a real-world environment.

Here’s how the flow works:

**Developer Interaction:** A developer pushes code or performs actions (e.g., commits, merges) to a GitHub repository.

**GitHub Webhook Trigger:** The repository is configured with a GitHub Webhook. A webhook is a lightweight notification mechanism that sends an **HTTP** **POST** request to a predefined URL when specified events occur (e.g., push, pull_request). Unlike GitHub Actions, which run workflows directly in GitHub, webhooks only notify external services like Jenkins to perform actions.

**Jenkins CI:** Jenkins receives the webhook notification and triggers a pipeline job. Jenkins then clones the repository onto its workspace.

**File Transfer to Ansible Server:** Jenkins copies the cloned repository to a separate Ansible server. This server is responsible for image creation and deployment logic.

**Docker Build & Push:** The Ansible server uses Docker to build, tag, and push the application image to a container registry. Docker must be installed and configured on this server.

**Deployment to Kubernetes:** The Ansible server copies the necessary deployment files to the Kubernetes cluster server. Then, using kubectl, it applies the manifests to deploy the application.

**Web Access:** Once deployed, the application is exposed and can be accessed through a web browser via a Kubernetes service (e.g., LoadBalancer or NodePort).

Due to AWS Free Tier limitations, this project avoids using AWS services and instead relies entirely on Docker containers to simulate the servers and environment.

## Why Use a Fixed IP Address for This Project?
For this project, using a **fixed IP address** for certain containers, like the **Ansible server**, is a better approach for several reasons:

1. **Consistency:** By assigning a fixed IP address, you ensure that the container always has the same address every time it starts. This eliminates potential issues with dynamic IP addressing, where the IP may change after a container is restarted.

2. **Reliability in Communication:** Since this project involves communication between multiple containers (e.g., Jenkins, Ansible, and other services), having a fixed IP ensures reliable network communication. Other services can always find the Ansible server at the same IP address without needing to resolve it dynamically.

3. **Ease of Networking:** For the SSH file transfer (SCP) between the Jenkins server and the **Ansible server**, it is essential to have a consistent destination IP address. Using a fixed IP address eliminates the need to update configurations or scripts every time the container restarts.

4. **Simulating a Production Environment:** In a production setting, servers often have static IP addresses for stability, security, and ease of management. By using fixed IPs in this project, we are simulating a more realistic environment where services and containers rely on fixed network addresses.

However, **I didn't end up using a fixed IP address** for the containers in this project. While it was initially an ideal choice for ensuring stable communication and reliable networking, I encountered a few challenges that made it more complex than necessary for my use case. Instead, I opted for more dynamic networking options while still maintaining reliable communication between the containers.

### Steps to Run a Docker Container with a Fixed IP Address
```bash
# 1. Create a custom Docker network:
$ docker network create --subnet=192.168.1.0/24 my_custom_network

# 2. Run a Docker container with a static IP:
$ docker container run -dt --name my-cont --net my_customer_network --ip 172.17.1.10 ubuntu tail -f /dev/null
# 3. Verify the container’s IP:
$ docker inspect my_cont
```

## 🐳 Running Jenkins in a Custom Docker Container
Before setting up the GitHub webhook, the first thing I did was run a Jenkins server inside a Docker container using an Ubuntu base image. While the official Jenkins Docker image exists, I chose to manually set up Jenkins to understand the setup process better.

Docker Run Command
```bash
$ docker container run -dt --name jenkins-server -p 8080:8080 -v jenkins_homoe:/var/jenkins_home ubuntu tail -f /dev/null
```

Initializing Jenkins Inside the Container
```bash
# 1. Enter the container:
$ docker exec -it jenkins-server bash

# 2. Update packages and install dependencies:
$ apt update && apt install -y fontconfig openjdk-17-jdk wget sudo openssh-server

# 3. Add the Jenkins repository key and source list:
$ wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian binary/ | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

$ apt-get update
$ apt-get install jenkins

# 4. don't forget to start the jenkins service & ssh
$ service jenkins start
$ service ssh start

# 5. Find the initial admin password:
$ cat /var/lib/jenkins/secrets/initialAdminPassword
```
OR simply visit the [jenkins_download_page](https://www.jenkins.io/download/) choose your distro then, go ahead with the installation guid

## 🔗 Setting Up the GitHub Webhook
Once Jenkins was up and running, the next step was to configure the GitHub Webhook for the repository. But before proceeding, ensure that you have:

1. **Initialized a local Git repository** on your machine (if you haven't already).

2. **Connected the repository** to a GitHub remote.

Afterward, you can create a webhook by navigating to:
```
Repository Settings → Webhooks → Add Webhook
```

GitHub webhooks require a Payload URL — this is the endpoint where GitHub will send POST requests whenever the configured events occur (e.g., ```push```, ```pull_request```). Since I'm working from a local development environment, hosting a public-facing URL is not straightforward.

I initially considered using my public IP address, but this approach doesn't work reliably. Most home networks share a single public IP across all connected devices, and without proper port forwarding and DNS setup, GitHub won’t be able to reach the specific machine hosting the server.

To solve this, I used **tunneling tools** that expose local servers to the internet securely. I explored several options:

- Ngrok (freemium, closed-source)

- LocalTunnel

- Cloudflare Tunnel

- **Tunnelmole**

I decided to go with **Tunnelmole**, because it’s open-source, completely free, and the most suitable option for my use case.

Here’s how I set it up:

1. Visited [tunnelmole.com](https://tunnelmole.com/) (or the [official GitHub repo](https://github.com/robbie-cahill/tunnelmole-client)).

2. Installed it on my local machine using the instructions provided.
```bash
# Universal Installer for Linux, Mac and Windows Subsystem for Linux
$ curl -O https://install.tunnelmole.com/t357g/install && sudo bash install
# OR
# Install using NodeJS !! make sure that you have npm installed first.
$ npm install -g tunnelmole
```

3. Started a tunnel pointing to the local Jenkins server (or whichever service you’re exposing).
```bash
$ tmole 8080 # just specify the port number that i want my localhost to expose
```

Tunnelmole provided a public URL (e.g., https://abc123.tunnelmole.net) which I used as the Payload URL in the GitHub Webhook configuration.

⚠️ **Important:** When using Jenkins with the GitHub plugin, the Payload URL must end with ```/github-webhook/```.
For example:
```bash
https://abc123.tunnelmole.net/github-webhook/
```

### Configuring the Content Type for the Webhook
While setting up the GitHub Webhook, you'll encounter a "Content type" field. This field determines how the data (payload) will be formatted in the POST request that GitHub sends to your endpoint.

You’ll have two options:

1. ```application/json``` (Recommended)
- The payload is sent as raw **JSON** in the body of the POST request.

- Most modern services and tools — including **Jenkins plugins** like:

  - GitHub Integration Plugin

  - Generic Webhook Trigger Plugin

...expect the incoming data to be in JSON format.

**Important:** Using the wrong content type (like x-www-form-urlencoded) can result in Jenkins not triggering the job or failing to parse the payload correctly.

2. ```application/x-www-form-urlencoded```
The payload is sent as a URL-encoded string in key-value pairs (e.g., ```key1=value1&key2=value2```).

This format is more common in older systems or legacy scripts.

Not typically recommended for modern webhook integrations unless explicitly required.

✅ Set the content type to: ```application/json```

This ensures smooth integration with Jenkins and other modern automation tools that rely on structured JSON payloads.

### Authenticating GitHub with Jenkins (API Token)
To allow GitHub to securely communicate with your Jenkins server via webhook, you need to generate a Jenkins API Token. This token serves as a secret that verifies the incoming request is legitimate.

Here’s how to generate it in the current Jenkins interface:

1. In the Jenkins GUI, click on your username (top right).

2. From the sidebar menu, go to "Security".

3. Click on "Add new token".

4. Give your token a name (e.g., GitHub Webhook), then generate it.

5. Copy the token and paste it into the Secret field when setting up the webhook in GitHub.

> ⚠️ Make sure to copy the token right away — you won't be able to view it again once you close the dialog.

### Finalizing the Webhook
After you’ve entered the Payload URL, selected the content type (```application/json```), and pasted the API token into the **Secret** field, click **"Add Webhook"**.

GitHub will **automatically send a test POST request** to the payload URL to verify the connection. If everything is configured correctly (the tunnel is running, the Jenkins endpoint is reachable, and the webhook is correctly set up), you should see a green check mark with a **"200 OK"** response in the webhook delivery log.

> 📌 If the test fails, check:
>   - Is Tunnelmole running and exposing the correct local port?
>   - Is Jenkins running and listening on that port?
>   - Is the webhook URL pointing to the right path (e.g., /github-webhook/)?

## 🔧 Creating a Jenkins Pipeline
### stage 1: Cloning the GitHub Repo
1. Create a Pipeline:
 In Jenkins, go to New Item, enter ```pipeline-demo```, select **Pipeline**, and click **OK**.

2. Enable GitHub Trigger:
 Under Build Triggers, check GitHub hook trigger for GITScm polling to trigger the pipeline on GitHub pushes.

3. Groovy Script for the First Stage:
 The entire Groovy script I wrote for the pipeline has been pushed to the GitHub repository. 

```grovy
// cloning the repo on the jenkins server
node{
    stage ('Git checkout'){
        git branch: 'main', url: 'https://github.com/Ma-Eltohamy/Kubernetes-CI-CD-Pipeline.git'
    }
}
```

### Stage 2: Sending Dockerfile to Ansible Server Over SSH
The goal of this stage is to transfer the **Dockerfile** from the Jenkins server to the **Ansible server** so that the Ansible server can (```build```, ```tag```, and ```push```) the Docker image. For this task, I chose to use **SSH (SCP)** for file transfer, as it is simple and secure.

Additionally, the **Ansible server** needs to have **Docker** installed to build the image. While installing **SSH** and **Ansible** is easy, setting up **Docker** requires careful consideration. I had two options:

1. **Docker-in-Docker (DinD):** Running Docker inside a Docker container is an option, but it can introduce unnecessary complexity and security concerns.

2. **Binding the Local Docker Daemon:** The simpler and more efficient option is to bind the Docker socket (```/var/run/docker.sock```) from the host machine into the container. This allows the Ansible container to use the host’s Docker daemon directly.

For my project, the second option was the most suitable because the goal is not to complicate the process but to simulate the experience of managing a pipeline on a real server. Binding the local Docker daemon avoids the overhead of Docker-in-Docker while still allowing the Ansible server to build Docker images using the host’s Docker engine.

Here are the steps I followed:

```bash
# Run the Ansible Docker Container with the Docker Socket Bound:
$ docker container run -dt --name ansible-server -v ansible_data:/home/ubuntu -v /var/run/docker.sock:/var/run/docker.sock ubuntu tail -f /dev/null

# Install Docker, SSH, and Ansible on the Server:
$ apt update && apt install -y docker.io openssh-server ansible

# Start the SSH Service:
$ service ssh start # if you didn't start the service the connection will be refused on port 22
```

After setting up the **Ansible server**, the next task is to ensure a **passwordless SSH connection** between the **Jenkins server** and the **Ansible server**. This is important for seamless file transfers without requiring credentials each time.

Here’s how to set up SSH key-based authentication:

```bash
# 1. Generate SSH Keys on Jenkins Server:
$ ssh-keygen -t rsa -b 4096 -C "jenkins@server"
# This will generate a public/private key pair (id_rsa and id_rsa.pub) under /root/.ssh/.
# the home dir of jenkins user at the jenkins server is /var/lib/jenkins --> there you will find .ssh 
# and also this is why you would have to add the private key (of the jenkins server) at the jenkins gui

# 2. Copy the Public Key to the Ansible Server:
$ cat /root/.ssh/id_rsa.pub
```
Then, **exec into the Ansible server** container and switch to the ```ubuntu``` user (because the default user is root):
```bash
$ docker exec -it ansible-server bash
$ su ubuntu # very important 

# Now, on the Ansible server, create the .ssh directory (if it doesn't already exist) and add the Jenkins server’s public key to the authorized_keys file:

$ mkdir -p /home/ubuntu/.ssh
$ echo "paste_the_jenkins_public_key_here" >> /home/ubuntu/.ssh/authorized_keys
$ chmod 600 /home/ubuntu/.ssh/authorized_keys
```

From the **Jenkins server**, test the SSH connection to the **Ansible server** without a password prompt:
```bash
3. Test the SSH Connection:
$ ssh ubuntu@<ansible-ip> # Use the Ansible container's static IP
```
If everything is set up correctly, you should be able to log in to the Ansible server without being prompted for a password.

Once the SSH connection is successfully established, you're ready to transfer files from Jenkins to Ansible using scp and perform further tasks like building Docker images.


>Using Private Key for SSH Authentication (e.g., AWS Method)
When working with cloud services like AWS, the most typical method for SSH authentication is to provide the private key of the target machine (in the case of AWS, an EC2 instance) when creating the SSH connection. This avoids the need to manually copy the public key between machines.

In order for Jenkins to use the private SSH key during the pipeline, you'll need to install the SSH Agent Plugin in Jenkins.

### Stage 3,4 and 5: Building, Tagging, and Pushing the Docker Image
After successfully setting up SSH and SCP file transfers, the next steps were to build, tag, and push the Docker image to Docker Hub. These steps can be executed easily on the **Ansible server** because of the SSH connection established earlier. Below is how I structured these three stages in the Jenkins pipeline:
```bash
# 1. Sending the Dockerfile to the Ansible Server:
stage ('Sending Dockerfile to ansible server over ssh'){
    sshagent(['docker-ansible-server']) {
        sh 'scp /var/lib/jenkins/workspace/pipline-demo/* ubuntu@172.17.0.2:/home/ubuntu/'
    }
}

# 2. Building the Docker Image:
stage ('Docker building image'){
    sshagent(['docker-ansible-server']) {
        sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 cd /home/ubuntu'
        sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 docker image build -t $JOB_NAME:v1.$BUILD_ID .'
    }
}

# 3. Tagging the Docker Image:
stage('Tagging docker image') {
    withCredentials([usernamePassword(
        credentialsId: 'docker-credentials',
        usernameVariable: 'USERNAME',
        passwordVariable: 'PASSWORD'
    )]) {
        sshagent(['docker-ansible-server']) {
            sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 cd /home/ubuntu'
            sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 docker image tag $JOB_NAME:v1.$BUILD_ID $USERNAME/$JOB_NAME:v1.$BUILD_ID'
            sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 docker image tag $JOB_NAME:v1.$BUILD_ID $USERNAME/$JOB_NAME:latest'
        }
    }
}

# 4. Pushing the Docker Image:
stage('Pushing docker image') {
    withCredentials([usernamePassword(
        credentialsId: 'docker-credentials',
        usernameVariable: 'USERNAME',
        passwordVariable: 'PASSWORD'
    )]) {
        sshagent(['docker-ansible-server']) {
            sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 docker login -u $USERNAME -p $PASSWORD'
            sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 docker image push $USERNAME/$JOB_NAME:v1.$BUILD_ID'
            sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 docker image push $USERNAME/$JOB_NAME:latest'
            
            // Clean up old image
            sh 'ssh -o StrictHostKeyChecking=no ubuntu@172.17.0.2 docker image rm $USERNAME/$JOB_NAME:v1.$BUILD_ID'
        }
    }
}
```

#### Using Jenkins Credentials for Docker Hub
For security, I used **Jenkins credentials** to manage Docker Hub authentication instead of hardcoding my Docker Hub credentials in the pipeline. Although using a **Jenkins secret** for storing the Docker Hub password is better practice, I opted to **use username and password** credentials in this case for flexibility.

Using credentials ensures that sensitive information like passwords isn't exposed in the pipeline script, reducing security risks.

#### Why Two Tags: Version and Latest?
I created two tags for the image: one based on the **BUILD_ID** and another as the latest tag. This is a common practice for the following reasons:

- The **versioned tag** (```v1.<BUILD_ID>```) ensures a unique version for every build, making it easy to track and reference specific releases.

- The **latest tag** points to the most recent release. This is useful for Kubernetes or other orchestrators that deploy the most recent version by default if no version tag is specified.

#### Cleaning Up Old Docker Images
After successfully pushing the new images to Docker Hub, I removed the **versioned tag** (```v1.<BUILD_ID>```) from the **Ansible server** to avoid cluttering the system with too many images. This step helps to keep the server clean.


### Stage 6: Sending Dockerfile to Kubernetes Server Over SSH
In this stage, the goal is to **transfer files from the Jenkins server to the Kubernetes server**, where the deployment will happen. Since I don’t have actual physical servers, I had to choose an approach that would **simulate a real Kubernetes environment** without adding too much complexity.

```grovy
stage ('Sending Dockerfile to kubernetes server over ssh'){
    sshagent(['web-k8s-app']) {
        sh 'scp /var/lib/jenkins/workspace/pipline-demo/* ubuntu@172.17.0.1:/home/ubuntu/'
    }
}
```
#### Simulating a Kubernetes Server
To simulate a Kubernetes server setup, I considered two options:

- **Running a Kubernetes cluster inside a Docker container using Kind**
While this was an interesting idea, it introduced extra complexity (like running Docker-in-Docker and managing nested containers), which wasn't necessary for this project.

- **Using the local Kind cluster directly on my host machine**
This turned out to be the **simplest and most efficient solution**. I used my host's Kind cluster and exposed services using **MetalLB** to assign reachable local IPs. This way, I could access the deployed application from my browser just like in a real-world scenario.

#### Simulating a Separate Kubernetes Server with a Different User
To keep the simulation realistic, I created a **new user on my machine named** ```ubuntu```. This user represents the **Kubernetes server environment**, and I needed it to access the same Kind cluster I set up on my machine.

To do that:
- I copied my Kubernetes config file to the new user:

```bash
$ cp ~/.kube/config /home/ubuntu/.kube/config
$ chown ubuntu:ubuntu /home/ubuntu/.kube/config
# This allows the ubuntu user to interact with the same cluster (using kubectl) without creating a new one.
```

#### SSH Access Between Jenkins and the Kubernetes Server
To make the **Jenkins server** able to SSH into the ```ubuntu``` user (Kubernetes server):

- I added the public SSH key of Jenkins to the file:
```bash
$ /home/ubuntu/.ssh/authorized_keys 
# on my local machine
# This enabled passwordless file transfers using SCP, just like we did with the Ansible server.
```

In short, I:
- Simulated a Kubernetes server with a local user
- Used the local machine’s Kind cluster for simplicity
- Shared the cluster’s kubeconfig with the new user
- Used SSH and SCP for file transfer

This approach balances realism with simplicity, simulating a full CI/CD pipeline without requiring a fleet of physical or cloud-based servers.

### 🧩 Final Stage: Running Ansible Playbook on Kubernetes Server
In this final stage, the goal is to **execute the Ansible playbook** that deploys the application to the **Kubernetes cluster**, which, as mentioned earlier, is hosted on the same machine.

This can be broken into **two simple steps**:

From the **Jenkins server**, SSH into the **Ansible server**

On the Ansible server, run the Ansible playbook (e.g., ```ansibler.yml```) that deploys the app to the Kubernetes cluster

#### 🧪 What Happens Here?
- Jenkins triggers the Ansible server via SSH

- The Ansible server executes the playbook, which uses kubectl to:

  - Pull the Docker image from Docker Hub

  - Apply the necessary Kubernetes manifests (Deployment, Service, etc.)

  - Expose the app via MetalLB with a local reachable IP

### 🌐 Final Touch: Open the App in Your Browser
Once the deployment completes, simply visit the exposed MetalLB IP on the specified port to access your application:
```php
http://<metallb-ip>:<nodePort>
```
That’s the full CI/CD workflow from GitHub commit → Jenkins → Ansible → Kubernetes → Live app in the browser.

>⚠️ **Note on File Transfers:**
While copying the _entire_ workspace or all files from one server to another (as done here using `scp`) technically works, it's **not a good practice** in real-world environments. This approach can:
>-   Lead to unnecessary overhead
>-   Expose sensitive or irrelevant files    
>-   Cause confusion between different environments 

🧠 The better solution would be to:

-   Create **dedicated directories** for each server (Jenkins, Ansible, K8s)
-   **Only transfer the specific files** needed by each one
    
I intentionally used the full copy approach in this project as an experiment — to see if it was technically viable and to simulate how Jenkins handles file movement — but in a real deployment scenario, this should absolutely be more organized and selective.>
