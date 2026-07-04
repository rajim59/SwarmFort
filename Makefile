# ============================================================
# SwarmFort - Complete Makefile
# ============================================================

.PHONY: infra-up infra-down swarm-setup verify-cluster swarm-stop swarm-start \
        setup-tls setup-app-secrets deploy-stack remove-stack test-stack \
        build-base build-dev build-prod buildx test-structure

# ---------- ইনফ্রা (Infrastructure) ----------
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

# ---------- TLS & Stack Deployment ----------
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

# ---------- Phase 2: Image Build & Security (Requirement 5-8) ----------
build-base:
	docker build -t myrepo/python-hardened:latest -f infra/docker/Dockerfile.base .

build-dev: build-base
	docker build -t myrepo/swarmfort-api:dev -f infra/docker/Dockerfile.dev .

build-prod: build-base
	docker build -t myrepo/swarmfort-api:latest -f infra/docker/Dockerfile.prod .

buildx:
	chmod +x infra/buildx/multi-arch-build.sh
	./infra/buildx/multi-arch-build.sh

test-structure: build-prod
	@echo "======================================================="
	@echo "====== EXACT COMPRESSED IMAGE SIZE REPORT ============="
	@echo "======================================================="
	@COMPRESSED_BYTES=$$(docker save myrepo/swarmfort-api:latest | gzip -c | wc -c); \
	COMPRESSED_MB=$$(awk -v size="$$COMPRESSED_BYTES" 'BEGIN { printf "%.2f", size / 1048576 }'); \
	echo "আপনার প্রোডাকশন ইমেজের আসল সাইজ: $$COMPRESSED_MB MB"; \
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


# ---------- Phase 4: Security Scanning (Requirment ) ----------

# প্রোডাকশন বিল্ড (DCT সাপোর্টের জন্য provenance=false করা হয়েছে)
build-prod:
	@echo "Building Production Image (DCT Compatible)..."
	docker build --provenance=false --no-cache -t rajim59/swarmfort-api:v1.0.2 -f infra/docker/Dockerfile.prod .

# DCT এনফোর্সমেন্ট দিয়ে সরাসরি পুশ ও সাইন
dct-push:
	@echo "Signing and Pushing image with DCT..."
	DOCKER_CONTENT_TRUST=1 docker push rajim59/swarmfort-api:v1.0.2

# DCT এনফোর্সমেন্ট দিয়ে পুল
dct-pull:
	@echo "Pulling with DCT enforcement..."
	DOCKER_CONTENT_TRUST=1 docker pull rajim59/swarmfort-api:v1.0.2