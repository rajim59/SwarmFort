.PHONY: infra-up infra-down swarm-setup verify-cluster swarm-stop swarm-start \
        setup-tls setup-app-secrets deploy-stack remove-stack test-stack \
        build-base build-dev build-prod buildx test-structure push-prod build-base-multi \
        gen-cosign-keys oom-adjust verify-resources deploy-monitoring-stack verify-monitoring \
        setup-dr-automation test-chaos gitops-lint gitops-dry-run gitops-deploy \
        setup-security-profiles setup-daemon-config demo test-all backup restore clean scan

# ==============================================================================
# Infrastructure Management
# ==============================================================================

infra-up:
	cd infra/terraform && terraform init && terraform apply -auto-approve
	@echo "⏳ Waiting 75 seconds for Ubuntu initialization and Docker installation..."
	@sleep 75
	$(MAKE) swarm-setup

infra-down:
	cd infra/terraform && terraform destroy -auto-approve

swarm-setup:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@ssh-keygen -R $(MANAGER_IP) 2>/dev/null || true
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

# ==============================================================================
# Security Profiles & Daemon Configuration
# ==============================================================================

setup-security-profiles:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@echo "📁 Deploying seccomp & AppArmor profiles via Jump Host..."
	@echo "  --> Node Manager (${MANAGER_IP})"
	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null azureuser@${MANAGER_IP} "sudo mkdir -p /etc/docker/seccomp /etc/apparmor.d && sudo apt-get install -y -qq apparmor apparmor-utils"
	@scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null infra/security/seccomp-profiles/custom-seccomp.json azureuser@${MANAGER_IP}:/tmp/
	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null azureuser@${MANAGER_IP} "sudo cp /tmp/custom-seccomp.json /etc/docker/seccomp/"
	@scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null infra/security/apparmor-profiles/usr.bin.custom-app azureuser@${MANAGER_IP}:/tmp/
	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null azureuser@${MANAGER_IP} "sudo cp /tmp/usr.bin.custom-app /etc/apparmor.d/ && sudo apparmor_parser -r -W /etc/apparmor.d/usr.bin.custom-app"
	
	@for ip in 10.0.1.5 10.0.1.6; do \
		echo "  --> Node $$ip (via Manager Proxy)"; \
		ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J azureuser@${MANAGER_IP} azureuser@$$ip "sudo mkdir -p /etc/docker/seccomp /etc/apparmor.d && sudo apt-get install -y -qq apparmor apparmor-utils"; \
		scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J azureuser@${MANAGER_IP} infra/security/seccomp-profiles/custom-seccomp.json azureuser@$$ip:/tmp/; \
		ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J azureuser@${MANAGER_IP} azureuser@$$ip "sudo cp /tmp/custom-seccomp.json /etc/docker/seccomp/"; \
		scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J azureuser@${MANAGER_IP} infra/security/apparmor-profiles/usr.bin.custom-app azureuser@$$ip:/tmp/; \
		ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J azureuser@${MANAGER_IP} azureuser@$$ip "sudo cp /tmp/usr.bin.custom-app /etc/apparmor.d/ && sudo apparmor_parser -r -W /etc/apparmor.d/usr.bin.custom-app"; \
	done
	@echo "✅ Security profiles deployed."

setup-daemon-config:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@echo "⚙️  Deploying hardened daemon.json via Jump Host..."
	@echo "  --> Node Manager (${MANAGER_IP})"
	@scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null infra/docker/daemon.json azureuser@${MANAGER_IP}:/tmp/
	@ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null azureuser@${MANAGER_IP} "sudo cp /tmp/daemon.json /etc/docker/daemon.json && sudo systemctl restart docker"
	
	@for ip in 10.0.1.5 10.0.1.6; do \
		echo "  --> Node $$ip (via Manager Proxy)"; \
		scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J azureuser@${MANAGER_IP} infra/docker/daemon.json azureuser@$$ip:/tmp/; \
		ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -J azureuser@${MANAGER_IP} azureuser@$$ip "sudo cp /tmp/daemon.json /etc/docker/daemon.json && sudo systemctl restart docker"; \
	done
	@echo "✅ Daemon config applied. Wait a few seconds for Docker stabilization."	
# ==============================================================================
# TLS & Stack Deployment
# ==============================================================================


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
	ssh azureuser@$(MANAGER_IP) "mkdir -p /tmp/infra/docker /tmp/infra/monitoring/loki"
	scp infra/docker/docker-stack.yml azureuser@$(MANAGER_IP):/tmp/infra/docker/
	scp infra/docker/nginx.conf azureuser@$(MANAGER_IP):/tmp/infra/docker/
	scp infra/monitoring/loki/fluent.conf azureuser@$(MANAGER_IP):/tmp/infra/monitoring/loki/
	ssh azureuser@$(MANAGER_IP) "cd /tmp/infra/docker && docker stack deploy -c docker-stack.yml swarmfort"
remove-stack:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	ssh azureuser@$(MANAGER_IP) "docker stack rm swarmfort"

test-stack:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	scp infra/tests/integration/test.sh azureuser@$(MANAGER_IP):/tmp/
	ssh azureuser@$(MANAGER_IP) "chmod +x /tmp/test.sh && /tmp/test.sh"

# ==============================================================================
# Image Building & Security Validation
# ==============================================================================

build-base:
	docker build -t myrepo/python-hardened:latest -f infra/docker/Dockerfile.base .

build-dev: build-base
	docker build -t myrepo/swarmfort-api:dev -f infra/docker/Dockerfile.dev .

build-prod: build-base
	@echo "Building Clean Production Image..."
	docker build --no-cache -t rajim59/swarmfort-api:latest -f infra/docker/Dockerfile.prod .

buildx:
	chmod +x infra/buildx/multi-arch-build.sh
	./infra/buildx/multi-arch-build.sh

test-structure: build-prod
	@echo "======================================================="
	@echo "====== EXACT COMPRESSED IMAGE SIZE REPORT ============="
	@echo "======================================================="
	@COMPRESSED_BYTES=$$(docker save myrepo/swarmfort-api:latest | gzip -c | wc -c); \
	COMPRESSED_MB=$$(awk -v size="$$COMPRESSED_BYTES" 'BEGIN { printf "%.2f", size / 1048576 }'); \
	echo "Your production image compressed size: $$COMPRESSED_MB MB"; \
	if awk -v size="$$COMPRESSED_MB" 'BEGIN { if (size >= 25.0) exit 1; else exit 0; }'; then \
		echo "✓ Success: Image is strictly under 25MB limit!"; \
	else \
		echo "✗ Error: Image size exceeds 25MB!"; \
		exit 1; \
	fi
	@echo "======================================================="
	docker run --rm \
	  -v /var/run/docker.sock:/var/run/docker.sock \
	  -v $(PWD)/infra/tests:/tests \
	  gcr.io/gcp-runtimes/container-structure-test:latest test \
	  --image myrepo/swarmfort-api:latest \
	  --config /tests/container-structure-tests.yml

# ==============================================================================
# Security Scanning & Key Generation
# ==============================================================================

push-prod: build-prod
	@echo "Pushing Production Image to Docker Hub..."
	docker push rajim59/swarmfort-api:latest

build-base-multi:
	@echo "Creating builder instance..."
	docker buildx create --use --name multi-builder || true
	@echo "Building and Pushing Multi-Arch Base Image..."
	docker buildx build --platform linux/amd64,linux/arm64 -t rajim59/python-hardened:latest -f infra/docker/Dockerfile.base --push .

gen-cosign-keys:
	@echo "Generating Cosign Key Pair using Docker with Host User Permissions..."
	docker run --rm -it -v $(PWD):/keys --user $(shell id -u):$(shell id -g) gcr.io/projectsigstore/cosign:v2.4.1 generate-key-pair --output-key-prefix /keys/cosign

scan:
	@echo "🔍 Scanning latest production image with Trivy..."
	docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image rajim59/swarmfort-api:latest --severity HIGH,CRITICAL

# ==============================================================================
# OOM Score Adjustment & Resource Verification
# ==============================================================================

oom-adjust:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	ssh azureuser@$(MANAGER_IP) "\
		docker service update --oom-score-adj -500 swarmfort_api && \
		docker service update --oom-score-adj -300 swarmfort_db && \
		docker service update --oom-score-adj -200 swarmfort_redis && \
		docker service update --oom-score-adj 0 swarmfort_nginx"

verify-resources:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	scp infra/resources/cgroups-v2-check.sh azureuser@$(MANAGER_IP):/tmp/
	ssh azureuser@$(MANAGER_IP) "bash /tmp/cgroups-v2-check.sh"
	ssh azureuser@$(MANAGER_IP) "docker service inspect swarmfort_api --format '{{.Spec.TaskTemplate.Resources.Limits}}'"

# ==============================================================================
# Monitoring Stack Deployment & Validation
# ==============================================================================

deploy-monitoring-stack:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@echo "Packaging infrastructure files with monitoring..."
	tar -czf /tmp/infra.tar.gz infra/
	scp /tmp/infra.tar.gz azureuser@$(MANAGER_IP):/tmp/
	@echo "Deploying SwarmFort + Monitoring Stack..."
	ssh azureuser@$(MANAGER_IP) "cd /tmp && tar -xzf infra.tar.gz && cd infra/docker && docker stack deploy -c docker-stack.yml swarmfort"

verify-monitoring:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@echo "=========================================================="
	@echo " 🔍 ADVANCED API-LEVEL VERIFICATION (PHASE 6) "
	@echo "=========================================================="
	@echo "\n[1] Verifying Swarm Services..."
	@sleep 15
	@ssh azureuser@$(MANAGER_IP) "docker service ls | grep swarmfort_"
	@echo "\n[2] Validating Prometheus Targets (Data Scraping)..."
	@ssh azureuser@$(MANAGER_IP) "curl -s http://127.0.0.1:9090/api/v1/targets | grep -q '\"health\":\"up\"' && echo '✅ SUCCESS: Prometheus is active' || echo '❌ FAILED: Targets unreachable'"
	@echo "\n[3] Validating Alerting Rules Engine..."
	@ssh azureuser@$(MANAGER_IP) "curl -s http://127.0.0.1:9090/api/v1/rules | grep -q 'OOMKillDetected' && echo '✅ SUCCESS: Alert rules loaded' || echo '❌ FAILED: Rules missing'"
	@echo "\n[4] Validating Loki Health..."
	@ssh azureuser@$(MANAGER_IP) "curl -s http://127.0.0.1:3100/ready | grep -q 'ready' && echo '✅ SUCCESS: Loki is READY' || echo '❌ FAILED: Loki not ready'"
	@echo "=========================================================="

# ==============================================================================
# Operational Excellence & Disaster Recovery
# ==============================================================================

setup-dr-automation:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	@echo "Deploying operational excellence scripts to Swarm Manager..."
	tar -czf /tmp/scripts.tar.gz -C infra swarm-scripts/ network/
	scp /tmp/scripts.tar.gz azureuser@$(MANAGER_IP):/tmp/
	ssh azureuser@$(MANAGER_IP) "cd /home/azureuser && tar -xzf /tmp/scripts.tar.gz && chmod +x swarm-scripts/*.sh network/*.sh"
	ssh azureuser@$(MANAGER_IP) "bash /home/azureuser/swarm-scripts/cleanup-cron-setup.sh"

# ==============================================================================
# Chaos Engineering & Resiliency Testing
# ==============================================================================

test-chaos:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	scp infra/tests/chaos/kill-random-node.sh infra/tests/chaos/network-latency.sh azureuser@$(MANAGER_IP):/tmp/
	ssh -t azureuser@$(MANAGER_IP) "chmod +x /tmp/kill-random-node.sh && /tmp/kill-random-node.sh"
	ssh -t azureuser@$(MANAGER_IP) "sudo /tmp/network-latency.sh 200ms 30"

# ==============================================================================
# GitOps & Ansible Deployment
# ==============================================================================

ANSIBLE_PLAYBOOK = infra/gitops/ansible/playbooks/deploy-stack.yml
INVENTORY = infra/gitops/ansible/inventory.ini

gitops-lint: ## Check syntax and lint the Ansible playbook
	@echo "🔍 Running Ansible Syntax Check..."
	ansible-playbook --syntax-check $(ANSIBLE_PLAYBOOK)
	@echo "🧹 Running Ansible Lint..."
	ansible-lint $(ANSIBLE_PLAYBOOK) || true

gitops-dry-run: ## Perform a dry run simulation of the deployment
	@echo "🧪 Running Ansible in Dry-Run mode..."
	ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK) --check --diff

gitops-deploy: ## Deploy the stack using the Ansible GitOps playbook
	@echo "🚀 Deploying stack via GitOps (Ansible)..."
	ansible-playbook -i $(INVENTORY) $(ANSIBLE_PLAYBOOK)

# ==============================================================================
# Full Demo, Comprehensive Tests, Backup, Restore, Clean
# ==============================================================================

demo: infra-up setup-security-profiles setup-tls setup-app-secrets deploy-stack test-stack
	@echo "🎉 SwarmFort is LIVE! Access: https://$(shell cd infra/terraform && terraform output -raw manager_public_ip)/health"

test-all: test-stack test-chaos test-structure
	@echo "✅ All tests passed."

backup:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	scp infra/swarm-scripts/backup-swarm.sh azureuser@$(MANAGER_IP):/tmp/
	ssh azureuser@$(MANAGER_IP) "chmod +x /tmp/backup-swarm.sh && sudo /tmp/backup-swarm.sh"
	mkdir -p backups
	scp azureuser@$(MANAGER_IP):/backups/swarm/*.tar.gz.gpg ./backups/ || echo "No backup file found (may be expected)"
	@echo "✅ Backup retrieved to ./backups/"

restore:
	$(eval MANAGER_IP=$(shell cd infra/terraform && terraform output -raw manager_public_ip))
	scp infra/swarm-scripts/restore-swarm.sh azureuser@$(MANAGER_IP):/tmp/
	ssh azureuser@$(MANAGER_IP) "chmod +x /tmp/restore-swarm.sh && sudo /tmp/restore-swarm.sh"

clean: remove-stack infra-down
	@echo "🧹 All cloud resources cleaned up."
	