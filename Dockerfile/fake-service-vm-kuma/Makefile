repository=gregoryhunt/kuma-dp-vault
version=v0.1.4

build:
	docker buildx create --use
	docker buildx build \
		-t ${repository}:${version} \
		--platform linux/arm64,linux/amd64 \
		--push \
		.

build_local_arm64:
	docker buildx create --use
	docker buildx build \
		-t ${repository}:${version} \
		--platform linux/arm64 \
		--load \
		.

build_local_amd64:
	docker buildx create --use
	docker buildx build \
		-t ${repository}:${version} \
		--platform linux/amd64 \
		--load \
		.