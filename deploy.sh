#!/bin/bash
set -e
set -x  # Enable debugging

# Step 1: Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Step 2: Apply Terraform configuration
echo "Applying Terraform configuration..."
terraform apply -auto-approve

# Step 3: Extract the public IP of the EC2 instance
echo "Fetching the public IP of the EC2 instance..."
INSTANCE_IP=$(terraform output -raw instance_public_ip)

# Debug: Print the instance IP
echo "Debug: Instance IP: $INSTANCE_IP"

# Check if the instance IP is valid
if [ -z "$INSTANCE_IP" ]; then
  echo "Error: Instance IP is empty. Check Terraform output."
  exit 1
fi

# Step 4: Generate the Ansible inventory file
echo "Creating inventory.ini..."
cat <<EOL > ansible/inventory.ini
[server]
$INSTANCE_IP ansible_user=ubuntu ansible_ssh_private_key_file=/home/pranav/Downloads/TF-key.pem
EOL

# Debug: Print the contents of inventory.ini
echo "Debug: Contents of inventory.ini:"
cat ansible/inventory.ini

echo "Inventory file created at ansible/inventory.ini"

# Step 5: Wait for SSH to be available
echo "Waiting for SSH to be available on the instance..."
while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i /home/pranav/Downloads/TF-key.pem ubuntu@$INSTANCE_IP exit; do   
  echo "Waiting for SSH..."
  sleep 5
done

echo "SSH is available. Proceeding with Ansible deployment."

# Step 6: Run Ansible playbook to install Docker and deploy the container
echo "Running Ansible playbook..."
ansible-playbook -i ansible/inventory.ini ansible/docker.yaml

echo "Ansible playbook executed successfully!"

# Step 7: SSH into the instance and pull + run the Docker image
echo "Pulling and running the Docker image on EC2 instance..."
ssh -o StrictHostKeyChecking=no -i /home/pranav/Downloads/TF-key.pem ubuntu@$INSTANCE_IP <<EOF
    # Update system and install Docker if not installed
    sudo apt update && sudo apt install -y docker.io

    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker

    # Pull the latest Docker image of the portfolio
    sudo docker pull pranav0001/my-web:latest

    # Stop and remove any existing container with the same name
    sudo docker stop portfolio-container || true
    sudo docker rm portfolio-container || true

    # Run the container and expose it on port 80
    sudo docker run -d -p 80:80 --name portfolio-container pranav0001/my-web:latest

    echo "Portfolio is now running at: http://$INSTANCE_IP"
EOF

echo "Deployment completed successfully!"
echo "Access your portfolio at: http://$INSTANCE_IP"