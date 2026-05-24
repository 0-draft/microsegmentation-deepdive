.PHONY: help check-tools lint clean-all

help:
	@echo "Targets:"
	@echo "  check-tools   verify required CLIs are installed"
	@echo "  lint          shellcheck all run.sh / cleanup.sh"
	@echo "  clean-all     run cleanup.sh in every pattern dir"

check-tools:
	@bash lib/check-tools.sh

lint:
	@which shellcheck >/dev/null 2>&1 || { echo "install shellcheck"; exit 1; }
	@find . -name 'run.sh' -o -name 'cleanup.sh' | xargs shellcheck

clean-all:
	@for d in 0*-*; do \
		if [ -x "$$d/cleanup.sh" ]; then \
			echo "==> $$d/cleanup.sh"; \
			(cd "$$d" && ./cleanup.sh) || true; \
		fi; \
	done
