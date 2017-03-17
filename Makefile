PACKAGE ?= "alignak"
DISTRO ?= ubuntu14 ubuntu16 debian8 centos7
TAG_SRC ?= "develop"
TAG_PACKAGING ?= "develop"
REPOS_DIR ?= "$$HOME/repos"

pull:
	for OS in $(DISTRO); do \
		docker pull alignak/alignak_builder:$$OS ;\
	done

build: pull
	for OS in $(DISTRO); do \
		docker build -f alignak_builder_$$OS -t alignak/alignak_builder:$$OS . ;\
	done

push:
	for OS in $(DISTRO); do \
		docker push alignak/alignak_builder:$$OS ;\
	done

package:
	for OS in $(DISTRO); do \
		docker run -e TAG_SRC=$(TAG_SRC) -e TAG_PACKAGING=$(TAG_PACKAGING) -e PACKAGE=$(PACKAGE) -v $(REPOS_DIR):/root/repos -v /tmp/build-dir:/root/build-dir  alignak/alignak_builder:$$OS bash /root/build-package.sh ;\
	done
