pipeline {
    agent any

    environment {
        DOCKERHUB_USER  = 'yosra01'
        IMAGE_TAG       = 'v4.0'
        //BUILDER         = 'native'   -> mac specific
        DOCKER_USERNAME = "${DOCKERHUB_USER}"
        BACKEND_IMAGE   = "${DOCKERHUB_USER}/iot-backend:${IMAGE_TAG}"
        FRONTEND_IMAGE  = "${DOCKERHUB_USER}/iot-frontend:${IMAGE_TAG}"
    }

    stages {

        stage('Checkout Backend') {
            steps {
                dir('iot-backend') {
                    git url: 'https://github.com/Yosra-01/iot-backend.git',
                        branch: 'main'
                }
            }
        }

        stage('Checkout Frontend') {
            steps {
                dir('iot-frontend') {
                    git url: 'https://github.com/SalmaaKhaledd/iot-frontend.git',
                        branch: 'main'
                }
            }
        }

        stage('Test') {
            parallel {
                stage('Test Backend') {
                    steps {
                        dir('iot-backend') {
                            sh 'mvn test -Dspring.profiles.active=test'
                        }
                    }
                }
                stage('Test Frontend') {
                    steps {
                        dir('iot-frontend') {
                            sh 'rm -rf node_modules'
                            sh 'npm ci'
                            sh 'npm test -- --watch=false'
                        }
                    }
                }
            }
        }       

        stage('Build & Push Backend') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker build \
                            -t $BACKEND_IMAGE \
                            -f iot-backend/Dockerfile \
                            iot-backend/
                        docker push $BACKEND_IMAGE
                    '''
                }
            }
        }

        stage('Build & Push Frontend') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-credentials',
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh '''
                        docker build \
                            -t $FRONTEND_IMAGE \
                            -f iot-frontend/Dockerfile \
                            iot-frontend/
                        docker push $FRONTEND_IMAGE
                    '''
                }
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    string(credentialsId: 'db-password', variable: 'DB_PASSWORD'),
                    string(credentialsId: 'jwt-secret',  variable: 'JWT_SECRET')
                ]) {
                    sh '''
                        mkdir -p secrets
                        printf '%s' "\$DB_PASSWORD" > "\$WORKSPACE/secrets/db_password.txt"
                        printf '%s' "\$JWT_SECRET"  > "\$WORKSPACE/secrets/jwt_secret.txt"

                        DOCKER_USERNAME=$DOCKER_USERNAME \
                        IMAGE_TAG=$IMAGE_TAG \
                        SECRETS_PATH="${HOST_WORKSPACE_ROOT}/${JOB_NAME}/secrets" \
                        docker-compose -f docker-compose.yml up -d --force-recreate
                    '''
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh '''
                    sleep 20
                    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "backend|frontend|db"
                    docker logs iot-devops-pipeline-iot-backend-svc-1 --tail 20 | grep -iE "started|error|failed"
                '''
            }
        }
    }

    post {
        success {
            echo 'Pipeline passed. Sensorix is up.'
        }
        failure {
            echo 'Pipeline failed. Check stage logs above.'
            sh 'docker-compose logs --tail 30 || true'
        }
    }
}
