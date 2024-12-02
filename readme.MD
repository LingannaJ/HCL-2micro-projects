* Microservices Architecture with AWS and Docker

       * Project Overview

This project consists of two microservices:

Patient Service
Appointment Service
Both services are containerized using Docker and deployed on AWS using ECS (Elastic Container Service), with an Application Load Balancer (ALB) handling traffic. The infrastructure is automated using Terraform.

Architecture Diagram
Patient Service: Handles patient-related requests.
Appointment Service: Manages appointment scheduling.
Both services are deployed as Docker containers on ECS Fargate.
ALB: Routes traffic to the appropriate service based on the URL path (/patients for Patient Service, /appointments for Appointment Service).


1. Setup Overview

VPC (Virtual Private Cloud)
Created a custom VPC with public and private subnets in multiple Availability Zones.
Public Subnets: Used for the ALB.
Private Subnets: Used for ECS tasks to ensure they are not directly exposed to the internet.
ALB (Application Load Balancer)
The ALB listens on port 80 (HTTP) and routes traffic to the respective microservice based on the URL path.
The ALB is configured with two target groups:
Patient Target Group: Routes traffic to Patient Service on port 3000.
Appointment Target Group: Routes traffic to Appointment Service on port 3001.
ECS (Elastic Container Service)
Both services are deployed as containers in ECS using Fargate launch type.
ECS uses Docker images stored in ECR (Elastic Container Registry).
The ECS services are connected to the target groups through an ALB.
Terraform Infrastructure Code
Terraform automates the entire infrastructure creation, including VPC, ALB, ECS, ECR, and IAM roles.

2. Resources and Configuration Details
Terraform Configuration
The infrastructure is described using Terraform. The main resources used include:

VPC: Defines the network infrastructure.
Security Groups: Ensures secure communication between the services and ALB.
IAM Roles: Assigns necessary permissions for ECS tasks.
ALB and Target Groups: Set up for routing traffic to the microservices.
ECS Services and Task Definitions: Defines the containers that run on ECS.
ECR Repositories: Stores Docker images for both services.
Service Communication
Patient Service is accessible at /patients path and is handled by the patient-target-group.
Appointment Service is accessible at /appointments path and is handled by the appointment-target-group.
The ALB listens for HTTP requests and forwards them to the appropriate service.


3. Docker Setup
Dockerfile for Patient Service
Dockerfile
Copy code
# Base image
FROM node:14

# Set working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the application code
COPY . .

# Expose the application port
EXPOSE 3000

# Start the application
CMD ["node", "app.js"]
Dockerfile for Appointment Service
Dockerfile
Copy code
# Base image
FROM node:14

# Set working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the application code
COPY . .

# Expose the application port
EXPOSE 3001

# Start the application
CMD ["node", "app.js"]
ECR Push
To push Docker images to ECR:

Authenticate to ECR: aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com
Tag Image: docker tag patient-service:latest <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/patient-service-repo:latest
Push Image: docker push <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/patient-service-repo:latest


4. ECS Deployment and ALB Configuration
ECS Service Setup
Patient Service ECS: Uses a task definition to launch a Docker container that exposes port 3000.
Appointment Service ECS: Uses a similar task definition to launch a Docker container exposing port 3001.
Both services are registered with their respective target groups.
ALB Listener Rules
Patient Listener Rule: Directs traffic with path /patients or /patients/* to the Patient Service.
Appointment Listener Rule: Directs traffic with path /appointments or /appointments/* to the Appointment Service.
Security Group and Networking
ECS tasks are placed in private subnets with a security group that allows incoming traffic from the ALB.
The ALB has a security group allowing HTTP traffic from the internet.
ECS Security Group: Allows inbound traffic only from the ALB.

5. Accessing the Microservices
After the infrastructure is deployed and the services are running, you can access them via the ALB’s DNS URL:

Patient Service: Access via http://<ALB-DNS-Name>/patients
Appointment Service: Access via http://<ALB-DNS-Name>/appointments
Getting the ALB DNS URL
To find the ALB DNS name:

Go to the AWS Management Console.
Navigate to EC2 > Load Balancers.
Find your ALB and note down its DNS name (e.g., app-alb-1234567890.us-east-1.elb.amazonaws.com).

6. CI/CD with GitHub Actions
The application can be integrated with GitHub Actions to automate deployments.

GitHub Actions Configuration
Create a .github/workflows/ci-cd.yml file to define your CI/CD pipeline.

Example CI/CD Workflow:

yaml
Copy code
name: CI/CD Pipeline

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Build Docker Image
        run: |
          docker build -t patient-service:latest .
          docker tag patient-service:latest <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/patient-service-repo:latest
          docker push <aws_account_id>.dkr.ecr.us-east-1.amazonaws.com/patient-service-repo:latest

  deploy:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Configure AWS CLI
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Update ECS Service
        run: |
          ecs-cli configure --region us-east-1 --access-key ${{ secrets.AWS_ACCESS_KEY_ID }} --secret-key ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          ecs-cli compose --file docker-compose.yml --project-name patient-service up

          
7. Conclusion
This setup demonstrates a complete microservices architecture with AWS, Docker, ECS, ALB, and CI/CD. Using Terraform for infrastructure as code, Docker for containerization, and ECS for scalable application hosting, this solution is designed for high availability and ease of scaling.

VPC and Subnets: Custom VPC with public and private subnets.
ALB: Routes traffic to different microservices.
ECS: Fargate launch type for easy container management.
Docker and ECR: Containerizes services and stores images.
CI/CD Pipeline: Automatically deploys new code via GitHub Actions.
With this infrastructure, adding new microservices is simple, and traffic management can be scaled with minimal effort.