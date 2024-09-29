# Spring Boot GitHub Actions Demo Project

[![Java CI with Maven in SKG Meetup](https://github.com/LefterisXris/actions-demo/actions/workflows/maven.yml/badge.svg)](https://github.com/LefterisXris/actions-demo/actions/workflows/maven.yml)

This project is a **Spring Boot Application** that demonstrates the usage of **GitHub Actions** for Continuous Integration (CI) and Continuous Deployment (CD) pipelines. 
The purpose of the project is to provide examples of how to set up and automate various tasks using GitHub Actions, including building, testing, deploying, and more. 
Anyone can fork this repository, configure it, and experiment with the workflows provided.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Examples Overview](#examples-overview)
  - [1. Setup Java](#1-setup-java)
  - [2. Caching Mechanism](#2-caching-mechanism)
  - [3. Replace Secrets in Configuration](#3-replace-secrets-in-configuration)
  - [4. Build Project](#4-build-project)
  - [5. Archive Test and Coverage Reports](#5-archive-test-and-coverage-reports)
  - [6. Comment Coverage in PR](#6-comment-coverage-in-pr)
  - [7. Build Docker Image and Push to GHCR](#7-build-docker-image-and-push-to-ghcr)
  - [8. Deploy to a Server using SSH or SCP](#8-deploy-to-a-server-using-ssh-or-scp)
  - [9. Notifications to Slack](#9-notifications-to-slack)
  - [10. Draft Release Creation on PR Merge](#10-draft-release-creation-on-pr-merge)
  - [11. Matrix CI Workflow](#11-matrix-ci-workflow)

## Features

- **CI/CD Workflows** for Spring Boot applications using GitHub Actions.
- **Build, Test, and Deploy** automation.
- **Java Version Matrix** with testing on multiple OS environments.
- Integration with **Docker** and **GitHub Container Registry** (GHCR).
- **Slack Notifications** for build status.
- Draft Release creation and executable JAR file upload on Pull Request (PR) merge.

## Prerequisites

Before you begin, ensure that you have:

- A **GitHub account**.
- A **fork** of this repository in your GitHub account.
- [OPTIONAL] **GITHUB_SECRETS** configured for H2 (or any other DB) secret values replacement.
- [OPTIONAL] **GITHUB_SECRETS** configured for SSH/SCP deployment, Slack notifications, and Docker registry access.

### GitHub Secrets:
- DB Credentials
  - `DB_USERNAME`: Username for the H2 database
  - `DB_PASSWORD`: Password for the H2 database
- Deployment
  - `SERVER_HOST`: Hostname or IP of the server for deployment (if using SSH/SCP).
  - `SERVER_USER`: SSH username for server deployment.
  - `SSH_PRIVATE_KEY`: SSH private key for the server.
- Notifications
- `SLACK_WEBHOOK`: Webhook URL for Slack notifications.

## Setup Instructions

To experiment with this project, follow the steps below:

1. **Fork the Repository**:
   - Click on the "Fork" button in GitHub to fork this repository to your account.

2. **Configure GitHub Secrets**:
   - Go to the "Settings" tab of your forked repository.
   - Under "Security," click on "Secrets and variables" > "Actions".
   - Add the required secrets mentioned in the [Prerequisites](#prerequisites).

3. **Uncomment Steps as Needed**:
   - Some steps in the workflows are commented out. You can find the commented-out steps in `.yml` files under `.github/workflows/`.
   - Uncomment the steps you want to use in your experiments.

4. **Trigger Actions**:
   - You can trigger the GitHub Actions workflows by pushing code, opening pull requests, or manually triggering them from the Actions tab.

## Examples Overview

### 1. Setup Java
This step sets up the required version of Java for building and testing the Spring Boot application.

```yaml
- name: Set up JDK 17
  uses: actions/setup-java@v4.4.0 # https://github.com/marketplace/actions/setup-java-jdk
  with:
    java-version: '17'
    distribution: 'temurin'
    cache: maven
```

### 2. Caching Mechanism
Caching the Maven dependencies between builds speeds up the process. This example uses the `actions/cache` to cache dependencies based on the `pom.xml` file.

```yaml
# Caching Mechanism (not needed as it has been incorporated to setup-java action by declaring "cache: maven"
- name: Cache local Maven repository
  uses: actions/cache@v4.0.2 # https://github.com/marketplace/actions/cache
  with:
    path: ~/.m2/repository
    key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}
    restore-keys: |
      ${{ runner.os }}-maven-
```

### 3. Replace Secrets in Configuration
A simple step that uses `sed` to replace patterns (e.g., secrets) in the `application.yml` file with environment variables.

```yaml
# Use this when working with a database, to replace secrets with their values
- name: Set Database Secrets
  run: |
    sed -i 's/##db.username##/${{ secrets.DB_USERNAME }}/g' src/main/resources/application.yaml
    sed -i 's/##db.password##/${{ secrets.DB_PASSWORD }}/g' src/main/resources/application.yaml
```

### 4. Build Project
This step compiles the project and packages it into a JAR file (depending on pom.xml of course).

```yaml
- name: Build Project
  run: mvn -B package
```

### 5. Archive Test and Coverage Reports
After tests are run, this step uploads the test and coverage reports (e.g., Jacoco - should be configured in `pom.xml` first) as artifacts for later review.

```yaml
- name: Archive Test Reports
  # Always run even if the build fails
  if: always()
  uses: actions/upload-artifact@v4.4.0 # https://github.com/marketplace/actions/upload-a-build-artifact
  with:
    name: test-reports
    path: target/surefire-reports/

- name: Archive Code Coverage Report
  if: always()
  uses: actions/upload-artifact@v4.4.0 # https://github.com/marketplace/actions/upload-a-build-artifact
  with:
    name: coverage-report
    path: target/site/jacoco/

- name: Upload .jar artifacts
  uses: actions/upload-artifact@v4.4.0
  with:
    name: app-executables
    path: target/*.jar
```

### 6. Comment Coverage in PR
This step Writes a comment on the open Pull Request including the Coverage for the PR and the project overall along with the status.
Can be configured to fail the PR if coverage is under the configured thresshold.
```yaml
- name: Add coverage to PR
  id: jacoco
  uses: madrapps/jacoco-report@v1.7.1 # https://github.com/marketplace/actions/jacoco-report
  with:
    paths: |
      target/site/jacoco/jacoco.xml
    token: ${{ secrets.GITHUB_TOKEN }}
    min-coverage-overall: 30
    min-coverage-changed-files: 90
    title: '# :lobster: Coverage Report'
    pass-emoji: ':green_circle:'
    fail-emoji: ':red_circle:'

- name: Fail PR if overall coverage is less than 30%
  if: ${{ steps.jacoco.outputs.coverage-overall < 30.0 }}
  uses: actions/github-script@v7.0.1 # https://github.com/marketplace/actions/github-script
  with:
    script: |
      core.setFailed('Coverage is less than 30%!')
```

### 7. Build Docker Image and Push to GHCR
This step builds a Docker image from the Spring Boot project and pushes it to GitHub Container Registry (GHCR).

```yaml
# Log in to GitHub Container Registry
- name: Log in to GitHub Container Registry
  run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

# Build Image. TODO: make sure you change the image name properly (username should your user)
# Check more here: https://docs.github.com/en/actions/use-cases-and-examples/publishing-packages/publishing-docker-images#publishing-images-to-github-packages
- name: Build Docker image
  run: docker build -t ghcr.io/lefterisxris/actions-demo:latest .

# Push Docker images to GitHub Container Registry. TODO: make sure you change the image name properly (username should your user)
# Check more here: https://docs.github.com/en/actions/use-cases-and-examples/publishing-packages/publishing-docker-images#publishing-images-to-github-packages
- name: Push Docker image to GHCR
  run: docker push ghcr.io/lefterisxris/actions-demo:latest
```

### 8. Deploy to a Server using SSH or SCP
Deploy the built JAR file to a remote server using SCP or SSH.

```yaml
# SSH into a Server and deploy. TODO: Configure the GitHub secrets for your server
- name: Deploy to Server over SSH
  env:
    SSH_PRIVATE_KEY: ${{ secrets.SERVER_DEPLOY_KEY }}
    SERVER_HOST: ${{ secrets.SERVER_HOST }}
    SERVER_USER: ${{ secrets.SERVER_USER }}
    PKI_SSH_PASSPHRASE: ${{ secrets.PKI_SSH_PASSPHRASE }}
  run: |
    mkdir -p ~/.ssh
    echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    eval $(ssh-agent -s)
    echo "$PKI_SSH_PASSPHRASE" | ssh-add ~/.ssh/id_rsa
    ssh-keyscan $SERVER_HOST >> ~/.ssh/known_hosts

    ssh $SERVER_USER@$SERVER_HOST << 'EOF'
      cd /home/user/project_with_docker_compose_file
      docker compose down 2>&1
      docker compose pull 2>&1
      docker compose up -d 2>&1
    EOF

# Alternative deployment of target file (might zip or any other file), using scp utility
# scp app.jar $SERVER_USER@$SERVER_HOST:$TARGET_DIR/app.jar
```

### 9. Notifications to Slack
Sends a notification to a Slack channel using the `slack-github-action` after the workflow completes.

```yaml
# Notification to Slack
# If enabled, you should declare SLACK_WEBHOOK_URL from your Slack account and also in previous steps
# fill with contents the payload that will be sent to Slack (file payload-slack.json)
- name: Send custom JSON data to Slack workflow
  id: slack
  uses: slackapi/slack-github-action@v1.27.0
  with:
    payload-file-path: "./payload-slack.json"
    # Or direct payload:
    #payload: '{"text":"Deployment succeeded!"}'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

```

### 10. Draft Release Creation on PR Merge
This job runs when a pull request is merged. It creates a draft release, uploads the executable JAR file, and adds a sample changelog.

```yaml
- name: Download build artifacts
  uses: actions/download-artifact@v4.1.8
  with:
    name: app-executables
    path: ./downloads

- name: Create Draft Release
  uses: softprops/action-gh-release@v2.0.8
  with:
    files: ./downloads/**
    name: "Draft release after so much good work!"
    body: |
      # The anticipated Release is here! :lobster:

      ## Changelog:
      - Feature 1: Added support for X
      - Feature 2: Improved performance for Y
      - Bugfix: Resolved issue with Z

      Thank you for your contributions!
    draft: true
    tag_name: ${{ github.sha }}
```

### 11. Matrix CI Workflow
This workflow demonstrates running tests on multiple versions of Java (17 and 19) and on different OS environments (Windows and Ubuntu).

```yaml
jobs:
  build:

    # Strategy gives the ability to declare set of variables and based on them, parallel runs will start using
    # all the combinations of the variables in matrix.
    strategy:
      matrix:
        java-version: [17, 19]
        os: [windows-latest, ubuntu-latest]

    runs-on: ${{ matrix.os }} # That means we will have at least 2 runs. One on windows-latest and one on ubuntu-latest

    steps:
      - uses: actions/checkout@v4.1.7 # https://github.com/marketplace/actions/checkout

      - name: Set up JDK ${{ matrix.java-version }}
        uses: actions/setup-java@v4.4.0 # https://github.com/marketplace/actions/setup-java-jdk
        with:
          java-version: ${{ matrix.java-version }}
          distribution: 'temurin'
          cache: maven

      - name: Build with Maven
        run: mvn -B package

      - name: Archive Test Reports
        # Always run even if the build fails. Can be set to fail only
        if: always()
        uses: actions/upload-artifact@v4.4.0 # https://github.com/marketplace/actions/upload-a-build-artifact
        with:
          name: ${{ matrix.os }}_jdk${{ matrix.java-version }}_test-reports
          path: target/surefire-reports/

      - name: Archive Code Coverage Report
        if: always()
        uses: actions/upload-artifact@v4.4.0 # https://github.com/marketplace/actions/upload-a-build-artifact
        with:
          name: ${{ matrix.os }}_jdk${{ matrix.java-version }}_coverage-report
          path: target/site/jacoco/
```

## Conclusion

This project serves as a practical demonstration of GitHub Actions with a Spring Boot application. 
Feel free to fork, experiment with the provided workflows, and adjust them to your use case. 
Whether you're looking to automate builds, run tests, deploy to servers, or simply notify your team via Slack, the included examples cover a wide range of common CI/CD tasks.
