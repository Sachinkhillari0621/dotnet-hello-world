
---

## dotnet-hello-world — Jenkins CI/CD Pipeline

### Objective

Automate the **build**, **push**, and **deployment** of a Dockerized **.NET Core API** using Jenkins.
The pipeline supports **UAT** and **Production** deployments via Jenkins parameters.

---

## 1. Prerequisites

Before setting up the pipeline, ensure you have:

* ✅ Jenkins server installed and running (can be on EC2 or local)
* ✅ Docker & Git installed on Jenkins server
* ✅ AWS EC2 instances ready for **UAT** and **Production**
* ✅ Docker Hub account (for image push)
* ✅ Jenkins Plugins:

  * Git Plugin
  * Pipeline Plugin
  * Docker Pipeline Plugin
  * SSH Agent Plugin

---

## 2. Repository Structure

```
dotnet-hello-world/
│
├── Dockerfile
├── Jenkinsfile
├── dotnet-hello-world.sln
├── dotnet-hello-world/
│   ├── dotnet-hello-world.csproj
│   └── Program.cs
└── README.md
```

---

## 3. Dockerfile

The Dockerfile builds and packages the .NET app into a Docker image:

```dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /app

COPY *.sln ./
COPY dotnet-hello-world/*.csproj ./dotnet-hello-world/
RUN dotnet restore

COPY . .
RUN dotnet publish ./dotnet-hello-world/dotnet-hello-world.csproj -c Release -o out

# Stage 2: Runtime
FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build /app/out .
EXPOSE 80
ENTRYPOINT ["dotnet", "dotnet-hello-world.dll"]
```

---

## 4. Jenkinsfile

The Jenkinsfile automates build, push, and deploy steps:

```groovy
pipeline {
    agent any

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['UAT', 'PRODUCTION'], description: 'Select environment to deploy')
    }

    environment {
        DOCKER_HUB_CREDENTIALS = credentials('dockerhub-cred')
        AWS_CREDENTIALS = credentials('aws-cred')
        DOCKER_IMAGE = "your-dockerhub-username/dotnet-hello-world"
        UAT_IP = "UAT-EC2-IP"
        PROD_IP = "PROD-EC2-IP"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/Sachinkhillari0621/dotnet-hello-world.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE:${BUILD_NUMBER} .'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh '''
                    echo $PASS | docker login -u $USER --password-stdin
                    docker push $DOCKER_IMAGE:${BUILD_NUMBER}
                    '''
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    def TARGET_IP = (params.DEPLOY_ENV == 'UAT') ? UAT_IP : PROD_IP
                    sshagent(['aws-cred']) {
                        sh """
                        ssh -o StrictHostKeyChecking=no ec2-user@${TARGET_IP} '
                          docker pull $DOCKER_IMAGE:${BUILD_NUMBER} &&
                          docker stop dotnetapp || true &&
                          docker rm dotnetapp || true &&
                          docker run -d --name dotnetapp -p 80:80 $DOCKER_IMAGE:${BUILD_NUMBER}
                        '
                        """
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    def TARGET_IP = (params.DEPLOY_ENV == 'UAT') ? UAT_IP : PROD_IP
                    sh "curl -f http://${TARGET_IP}:80 || echo 'Health check failed'"
                }
            }
        }
    }
}
```

---

## 5. Jenkins Credentials Setup

Go to **Manage Jenkins → Credentials → Global** and add:

| ID               | Type                       | Description      |
| ---------------- | -------------------------- | ---------------- |
| `dockerhub-cred` | Username & Password        | Docker Hub login |
| `aws-cred`       | SSH Username & Private Key | EC2 SSH access   |

---

## 6. Environment Variables (inside Jenkinsfile)

| Variable                 | Description                     |
| ------------------------ | ------------------------------- |
| `UAT_IP`                 | EC2 Public IP for UAT           |
| `PROD_IP`                | EC2 Public IP for Production    |
| `DOCKER_IMAGE`           | Docker image name with repo     |
| `DOCKER_HUB_CREDENTIALS` | Jenkins Docker Hub credentials  |
| `AWS_CREDENTIALS`        | Jenkins SSH credentials for EC2 |

---

## 7. Creating the Jenkins Pipeline

1. Go to **Jenkins Dashboard → New Item → Pipeline**
2. Name it e.g. `dotnet-docker-deploy`
3. Under **Pipeline Definition → Pipeline script from SCM**

   * SCM: Git
   * Repository URL: `https://github.com/Sachinkhillari0621/dotnet-hello-world.git`
   * Script Path: `Jenkinsfile`

---

## 8. Running the Pipeline

1. Click **Build with Parameters**
2. Choose:

   * `DEPLOY_ENV` = `UAT` or `PRODUCTION`
3. Jenkins will:

   * Pull the source code
   * Build Docker image
   * Push image to Docker Hub
   * Deploy image on the chosen EC2 instance
   * Perform a health check

---

## 9. Verifying the Deployment

1. SSH into your EC2 instance:

   ```bash
   ssh ec2-user@<EC2-IP>
   docker ps
   ```

   → You should see a container named `dotnetapp`.

2. Visit in browser:

   ```
   http://<EC2-IP>:80
   ```

   → You should see your “Hello World” .NET app response.

---

## 🧹 10. Cleanup Commands

Stop and remove container:

```bash
docker stop dotnetapp
docker rm dotnetapp
```

---

## 🏁 Summary

| Step               | Purpose                                |
| ------------------ | -------------------------------------- |
| Dockerfile         | Builds and packages the .NET app       |
| Jenkinsfile        | Automates build → push → deploy        |
| Jenkins parameters | Control environment (UAT / Production) |
| Docker Hub         | Stores built images                    |
| EC2                | Runs the final container               |

---


