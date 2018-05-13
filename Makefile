OS = $(shell uname -s | tr A-Z a-z)

ifeq ($(OS),darwin)
	OS = osx
endif

# Istio
# Ref: https://github.com/istio/istio
# Daily releases: https://gcsweb.istio.io/gcs/istio-prerelease/daily-build/
ISTIO_VERSION = release-0.8-20180511-16-55
ISTIO_DAILY_RELEASE = true

.PHONY: all
all: buildnginx \
	deployistio \
	preparenamespaces \
	deployservices \
	releasestable

.PHONY: deployistio
deployistio:
	rm -rf istio-$(ISTIO_VERSION) istio-$(ISTIO_VERSION)-$(OS).tar.gz
	if [ "$(ISTIO_DAILY_RELEASE)" == "true" ]; then \
		wget https://storage.googleapis.com/istio-prerelease/daily-build/$(ISTIO_VERSION)/istio-$(ISTIO_VERSION)-$(OS).tar.gz; \
	else \
		wget https://github.com/istio/istio/releases/download/$(ISTIO_VERSION)/istio-$(ISTIO_VERSION)-$(OS).tar.gz; \
	fi
	tar -xvf istio-$(ISTIO_VERSION)-$(OS).tar.gz
	helm upgrade -i istio \
		--namespace=istio-system \
		--values ./istio.yaml \
		./istio-$(ISTIO_VERSION)/install/kubernetes/helm/istio

.PHONY: preparenamespaces
preparenamespaces:
	kubectl create ns services-v1 || true
	kubectl create ns services-v2 || true
	kubectl label ns services-v1 services-v2 istio-injection=enabled --overwrite

.PHONY: updateservicesdep
updateservicesdep:
	cd services && helm dep update --skip-refresh

.PHONY: deployservices
deployservices: updateservicesdep
	helm upgrade -i services-v1 \
		--namespace=services-v1 \
		./services
	helm upgrade -i services-v2 \
		--namespace=services-v2 \
		./services

.PHONY: releasestable
releasestable:
	helm upgrade -i traffic-manager \
		./traffic-manager

.PHONY: releasecanary
releasecanary:
	helm upgrade -i traffic-manager \
		--set canary.enabled=true \
		./traffic-manager

.PHONY: releasecanarymatchheader
releasecanarymatchheader:
	helm upgrade -i traffic-manager \
		--set canary.enabled=true \
		--set canary.onlyMatchHeader=true \
		./traffic-manager

.PHONY: buildnginx
buildnginx:
	eval $$(minikube docker-env); \
	docker build -t nginx:alpine-curl nginx
