.PHONY: help tasks install doctor status cycle ci docker-test

help:
	@echo "Thin wrapper over mise"
	@echo "make tasks"
	@echo "make install"
	@echo "make doctor"
	@echo "make status"
	@echo "make cycle"
	@echo "make ci"
	@echo "make docker-test"

tasks:
	mise tasks

install:
	./install.sh

doctor:
	mise run doctor

status:
	mise run status

cycle:
	mise run cycle

ci:
	mise run ci:act

docker-test:
	docker build --target test -t dotfiles:test .
