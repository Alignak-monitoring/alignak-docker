PACKAGE ?= "alignak"
DISTRO ?= ubuntu14 ubuntu16 debian8 centos7
TAG ?= ""
SRC_DIR ?= "$$HOME/repos"

build:
	for OS in $(DISTRO); do \
		docker build -f alignak_builder_$$OS -t alignak/alignak_builder:$$OS . ;\
	done

push:
	for OS in $(DISTRO); do \
		docker push alignak/alignak_builder:$$OS ;\
	done

package:
	for OS in $(DISTRO); do \
		docker run -e TAG=$(TAG) -e PACKAGE=$(PACKAGE) -v $(SRC_DIR):/root/src/ -v /tmp/build-dir:/root/build-dir  alignak_builder:$$OS bash /root/build-package.sh ;\
	done
