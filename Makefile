.PHONY: infra-up infra-down swarm-setup verify-cluster swarm-stop swarm-start

infra-up:
	cd infra/terraform && terraform init && terraform apply -auto-approve
	$(MAKE) swarm-setup

infra-down:
	cd infra/terraform && terraform destroy -auto-approve

swarm-setup:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@eval "$$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa && \
	scp -o StrictHostKeyChecking=no infra/swarm-scripts/init-cluster.sh infra/swarm-scripts/join-worker.sh azureuser@$(MANAGER_IP):/home/azureuser/ && \
	ssh -o StrictHostKeyChecking=no -A azureuser@$(MANAGER_IP) "chmod +x init-cluster.sh join-worker.sh && ./init-cluster.sh" && \
	TOKEN=$$(ssh -o StrictHostKeyChecking=no azureuser@$(MANAGER_IP) "docker swarm join-token -q worker") && \
	ssh -o StrictHostKeyChecking=no -A azureuser@$(MANAGER_IP) "scp -o StrictHostKeyChecking=no join-worker.sh 10.0.1.5:/home/azureuser/ && ssh -o StrictHostKeyChecking=no 10.0.1.5 \"./join-worker.sh $$TOKEN 10.0.1.4\"" && \
	ssh -o StrictHostKeyChecking=no -A azureuser@$(MANAGER_IP) "scp -o StrictHostKeyChecking=no join-worker.sh 10.0.1.6:/home/azureuser/ && ssh -o StrictHostKeyChecking=no 10.0.1.6 \"./join-worker.sh $$TOKEN 10.0.1.4\""
	$(MAKE) verify-cluster

verify-cluster:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@ssh -o StrictHostKeyChecking=no azureuser@$(MANAGER_IP) "docker node ls"

swarm-stop:
	az vm deallocate --ids $$(az vm list --resource-group swarmfort-resources-v3 --query "[].id" -o tsv)
	@sleep 5
	az vm list -g swarmfort-resources-v3 -d --query "[].[name,powerState]" -o table

swarm-start:
	az vm start --ids $$(az vm list --resource-group swarmfort-resources-v3 --query "[].id" -o tsv)
	@sleep 8
	az vm list -g swarmfort-resources-v3 -d --query "[].[name,powerState]" -o table
# $(MAKE) swarm-setup



# ------------------(infra-up, swarm-setup, verify-cluster, ...)

.PHONY: setup-tls deploy-stack remove-stack

setup-tls:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	scp infra/swarm-scripts/generate-certs.sh azureuser@$(MANAGER_IP):/tmp/
	ssh azureuser@$(MANAGER_IP) "chmod +x /tmp/generate-certs.sh && /tmp/generate-certs.sh"

setup-app-secrets:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@ssh azureuser@$(MANAGER_IP) "printf 'SecureDbPass123!' | docker secret create db_password - || true"
	@ssh azureuser@$(MANAGER_IP) "printf 'SecureApiKey456!' | docker secret create api_key - || true"


deploy-stack:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	scp infra/docker/docker-stack.yml infra/docker/nginx.conf azureuser@$(MANAGER_IP):/tmp/
	ssh azureuser@$(MANAGER_IP) "docker stack deploy -c /tmp/docker-stack.yml swarmfort"


remove-stack:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	ssh azureuser@$(MANAGER_IP) "docker stack rm swarmfort"


test-stack:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	scp infra/tests/integration/test.sh azureuser@$(MANAGER_IP):/tmp/
	ssh azureuser@$(MANAGER_IP) "chmod +x /tmp/test.sh && /tmp/test.sh"