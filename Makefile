.PHONY: infra-up infra-down swarm-init swarm-token get-tokens

infra-up:
	cd infra/terraform && terraform init && terraform apply -auto-approve
	@echo "Infrastructure ready. Manager public IP: $$(cd infra/terraform && terraform output -raw manager_public_ip)"

infra-down:
	cd infra/terraform && terraform destroy -auto-approve

# Run AFTER SSH-ing into manager (or via remote execution)
swarm-init:
	@echo "Initialising Swarm on manager. Use the manager's private IP:"
	@echo "Run on manager: docker swarm init --advertise-addr \$$(hostname -I | awk '{print \$$1}')"

# Fetch join tokens (run after manager init) - you can script this later
get-tokens:
	@echo "SSH into manager and run:"
	@echo "  docker swarm join-token manager"
	@echo "  docker swarm join-token worker"

# Simple stop/start to save credits
swarm-stop:
	az vm deallocate --ids $$(az vm list --resource-group swarmfort-resources-v3 --query "[].id" -o tsv)
	@echo "Waiting 15 seconds for deallocation..."
	sleep 5
	az vm list -g swarmfort-resources-v3 -d --query "[].[name,powerState]" -o table

swarm-start:
	az vm start --ids $$(az vm list --resource-group swarmfort-resources-v3 --query "[].id" -o tsv)
	@echo "Waiting 10s for VMs to start..."
	sleep 8
	az vm list -g swarmfort-resources-v3 -d --query "[].[name,powerState]" -o table