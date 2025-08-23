#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/devops_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Colors for output
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

msg() { echo -e "${GREEN}[INFO]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

update_system() {
    msg "Updating system packages..."
    sudo apt-get update -y && sudo apt-get upgrade -y
}

install_java() {
    msg "Installing Temurin 17 JDK..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | \
        sudo tee /etc/apt/keyrings/adoptium.asc > /dev/null

    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print $2}' /etc/os-release) main" | \
        sudo tee /etc/apt/sources.list.d/adoptium.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y temurin-17-jdk
    java -version
}

install_jenkins() {
    msg "Installing Jenkins..."
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
        sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | \
        sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y jenkins
    sudo systemctl enable jenkins
    sudo systemctl start jenkins
    msg "Jenkins installed and started!"
}

install_docker() {
    msg "Installing Docker..."
    sudo apt-get install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker

    # Add current user (not hardcoded 'ubuntu')
    sudo usermod -aG docker "$USER" || true
    msg "Docker installed. Logout/login again to apply group changes."
}

install_sonarqube() {
    msg "Deploying SonarQube container..."
    if ! docker ps -a --format '{{.Names}}' | grep -q sonar; then
        docker run -d --name sonar -p 9000:9000 sonarqube:lts-community
    else
        msg "SonarQube container already exists, skipping..."
    fi
}

install_trivy() {
    msg "Installing Trivy..."
    sudo apt-get install -y wget apt-transport-https gnupg lsb-release
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
        gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | \
        sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y trivy
}

main() {
    update_system
    install_java
    install_jenkins
    install_docker
    install_sonarqube
    install_trivy
    msg "✅ Setup completed successfully!"
}

main
