pipeline {
    agent any

    parameters {
        choice(name: 'ENV', choices: ['UAT', 'PROD'], description: 'Select environment to deploy')
    }

    environment {
        IMAGE_NAME = "sachin621/dotnet-hello-world"
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
        EC2_UAT_IP = "UAT_EC2_PUBLIC_IP"
        EC2_PROD_IP = "PROD_EC2_PUBLIC_IP"
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/<your-username>/dotnet-hello-world.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh """
                    echo $PASS | docker login -u $USER --password-stdin
                    docker push $IMAGE_NAME:$IMAGE_TAG
                    docker logout
                    """
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([sshUserPrivateKey(credentialsId: 'ec2-key', keyFileVariable: 'KEYFILE')]) {
                    script {
                        def EC2_IP = (params.ENV == 'UAT') ? env.EC2_UAT_IP : env.EC2_PROD_IP
                        sh """
                        ssh -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$EC2_IP '
                            docker pull $IMAGE_NAME:$IMAGE_TAG &&
                            docker stop dotnetapp || true &&
                            docker rm dotnetapp || true &&
                            docker run -d --name dotnetapp -p 80:80 $IMAGE_NAME:$IMAGE_TAG
                        '
                        """
                        env.EC2_IP = EC2_IP
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    echo "Checking app health at http://${env.EC2_IP}"
                    // Try up to 3 times to allow container startup
                    retry(3) {
                        sh """
                        sleep 5
                        status=\$(curl -s -o /dev/null -w '%{http_code}' http://${env.EC2_IP} || echo 000)
                        echo "HTTP status: \$status"
                        if [ "\$status" != "200" ]; then
                            echo "App not healthy yet, retrying..."
                            exit 1
                        fi
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            echo "Deployment and health check passed for ${params.ENV}!"
        }
        failure {
            echo "Deployment failed. Check Jenkins logs."
        }
    }
}
