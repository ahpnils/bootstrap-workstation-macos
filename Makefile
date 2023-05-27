help:
	@echo 'Makefile for bootstrap-workstation-macos'
	@echo ' '
	@echo 'Usage:'
	@echo 'make clean                   remove stale files'
	@echo 'make devdeps                 install development tools'
	@echo 'make lint                    check role for errors'
	@echo ' '

clean:
	rm -f *~ .*~
	find . -iname *~ -delete
	find . -iname .*~ -delete

devdeps:
	# shellcheck does not seems available for pkgin/macOS
	sudo pkgin -y install ansible-core \
		ansible-lint

lint:
	ansible-lint ./ansible/playbooks/bootstrap_workstation.yml

scheck:
	shellcheck -x ./bin/bootstrap.sh

