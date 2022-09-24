export DOCKER_BUILDKIT := 1

.PHONY: test
test:
	@echo -e "\n🛠️  Running unit tests..."
	go test ./...

.PHONY: build
build:
	@echo -e "\n🔧  Building Go binaries..."
	GOOS=darwin GOARCH=amd64 go build -o bin/admission-webhook-darwin-amd64 .
	GOOS=linux GOARCH=amd64 go build -o bin/admission-webhook-linux-amd64 .

.PHONY: docker-build
docker-build:
	@echo -e "\n📦 Building simple-kubernetes-webhook Docker image..."
	docker build -t simple-kubernetes-webhook:latest .

# From this point `kind` is required
.PHONY: cluster
cluster:
	@echo -e "\n🔧 Creating Kubernetes cluster..."
	kind create cluster --config dev/manifests/kind/kind.cluster.yaml

.PHONY: delete-cluster
delete-cluster:
	@echo -e "\n♻️  Deleting Kubernetes cluster..."
	kind delete cluster

.PHONY: push
push: docker-build
	@echo -e "\n📦 Pushing admission-webhook image into Kind's Docker daemon..."
	kind load docker-image simple-kubernetes-webhook:latest

.PHONY: deploy-config
deploy-config:
	@echo -e "\n⚙️  Applying cluster config..."
	kubectl apply -f dev/manifests/cluster-config/

.PHONY: delete-config
delete-config:
	@echo -e "\n♻️  Deleting Kubernetes cluster config..."
	kubectl delete -f dev/manifests/cluster-config/

.PHONY: deploy
deploy: push delete deploy-config
	@echo -e "\n🚀 Deploying simple-kubernetes-webhook..."
	kubectl apply -f dev/manifests/webhook/

.PHONY: delete
delete:
	@echo -e "\n♻️  Deleting simple-kubernetes-webhook deployment if existing..."
	kubectl delete -f dev/manifests/webhook/ || true

.PHONY: pod
pod:
	@echo -e "\n🚀 Deploying test pod..."
	kubectl apply -f dev/manifests/pods/lifespan-seven.pod.yaml

.PHONY: delete-pod
delete-pod:
	@echo -e "\n♻️ Deleting test pod..."
	kubectl delete -f dev/manifests/pods/lifespan-seven.pod.yaml

.PHONY: bad-pod
bad-pod:
	@echo -e "\n🚀 Deploying \"bad\" pod..."
	kubectl apply -f dev/manifests/pods/bad-name.pod.yaml

.PHONY: delete-bad-pod
delete-bad-pod:
	@echo -e "\n🚀 Deleting \"bad\" pod..."
	kubectl delete -f dev/manifests/pods/bad-name.pod.yaml

.PHONY: taint
taint:
	@echo -e "\n🎨 Taining Kubernetes node.."
	kubectl taint nodes kind-control-plane "acme.com/lifespan-remaining"=4:NoSchedule

.PHONY: logs
logs:
	@echo -e "\n🔍 Streaming simple-kubernetes-webhook logs..."
	kubectl logs -l app=simple-kubernetes-webhook -f

.PHONY: delete-all
delete-all: delete delete-config delete-pod delete-bad-pod
