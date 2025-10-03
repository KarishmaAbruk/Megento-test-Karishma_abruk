pipeline {
  agent any
  environment {
    // Jenkins credentials IDs (configure in Jenkins > Credentials)
    AWS_CRED_ID = 'aws-creds'                 // Username: AWS_ACCESS_KEY_ID, Password: AWS_SECRET_ACCESS_KEY
    SSH_KEY_ID  = 'jenkins-ssh-key'           // SSH private key credential (for test-ssh)
    MAGENTO_DB_PASS = credentials('magento-db-pass')
    MAGENTO_ADMIN_PASS = credentials('magento-admin-pass')
    COMPOSER_AUTH = credentials('magento-composer-auth') // secret text or username/password for repo.magento.com
    TERRAFORM_WORKDIR = 'infra'
    ANSIBLE_PLAYBOOK = 'ansible/playbooks/site.yml'
    ANSIBLE_INVENTORY = 'ansible/inventory/generated_inventory.ini'
  }

  options { timestamps() ansiColor('xterm') }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Terraform Init & Plan') {
      steps {
        dir("${env.TERRAFORM_WORKDIR}") {
          withEnv(["AWS_ACCESS_KEY_ID=${env.AWS_CRED_ID_USR ?: ''}", "AWS_SECRET_ACCESS_KEY=${env.AWS_CRED_ID_PSW ?: ''}"]) {
            sh '''
              terraform init -input=false
              terraform plan -out=tfplan -input=false \
                -var="ssh_key_name=jenkins_key"
            '''
          }
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        dir("${env.TERRAFORM_WORKDIR}") {
          withEnv(["AWS_ACCESS_KEY_ID=${env.AWS_CRED_ID_USR ?: ''}", "AWS_SECRET_ACCESS_KEY=${env.AWS_CRED_ID_PSW ?: ''}"]) {
            sh 'terraform apply -input=false -auto-approve tfplan'
          }
        }
      }
    }

    stage('Collect Terraform Outputs') {
      steps {
        dir("${env.TERRAFORM_WORKDIR}") {
          script {
            SERVER_IP = sh(script: "terraform output -raw server_public_ip", returnStdout: true).trim()
            echo "Server IP: ${SERVER_IP}"
            env.SERVER_IP = SERVER_IP
          }
        }
      }
    }

    stage('Generate Ansible Inventory') {
      steps {
        writeFile file: "${ANSIBLE_INVENTORY}", text: """
[magento]
${env.SERVER_IP} ansible_user=test-ssh ansible_private_key_file=/tmp/jenkins_ssh_key ansible_python_interpreter=/usr/bin/python3
"""
        // pull SSH key from Jenkins SSH credentials into a temporary file
        sshagent([SSH_KEY_ID]) {
          sh '''
            # copy SSH key to temp path (ansible will reference it)
            cp ~/.ssh/id_rsa /tmp/jenkins_ssh_key || true
            chmod 600 /tmp/jenkins_ssh_key || true
          '''
        }
      }
    }

    stage('Wait for SSH') {
      steps {
        timeout(time: 3, unit: 'MINUTES') {
          retry(12) {
            sh "nc -z -w5 ${env.SERVER_IP} 22 || (sleep 5; false)"
          }
        }
      }
    }

    stage('Run Ansible Playbook') {
      steps {
        // run ansible-playbook from Jenkins agent
        sh """
          export ANSIBLE_HOST_KEY_CHECKING=False
          ansible-playbook -i ${ANSIBLE_INVENTORY} ${ANSIBLE_PLAYBOOK} \
            -e magento_db_password='${MAGENTO_DB_PASS}' \
            -e magento_admin_password='${MAGENTO_ADMIN_PASS}' \
            -e magento_base_domain='test.mgt.com' \
            -e pma_domain='pma.mgt.com'
        """
      }
    }

    stage('Deploy PHP code (artifact)') {
      steps {
        // Option A: Build artifact in Jenkins & copy to server using Ansible
        sh """
          cd app
          # Option: composer install --no-dev (if building artifact)
          tar -czf /tmp/magento_app.tar.gz .
        """
        sh """
          ansible -i ${ANSIBLE_INVENTORY} magento -m copy -a "src=/tmp/magento_app.tar.gz dest=/home/test-ssh/magento_app.tar.gz mode=0644" 
          ansible -i ${ANSIBLE_INVENTORY} magento -m shell -a "sudo tar -xzf /home/test-ssh/magento_app.tar.gz -C /var/www/magento && sudo chown -R test-ssh:clp /var/www/magento"
        """
      }
    }

    stage('Post-deploy tasks & Smoke tests') {
      steps {
        sh """
          # run remote curl to the site (accept self-signed)
          ansible -i ${ANSIBLE_INVENTORY} magento -m shell -a "curl -k -I https://test.mgt.com || true"
        """
      }
    }
  }

  post {
    failure { echo "Pipeline failed" }
    success { echo "Done" }
  }
}
