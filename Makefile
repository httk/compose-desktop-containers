venv:
	if [ -e .venv ]; then \
	    LINK=$$(readlink .venv); \
            if [ "$${LINK}" != ".venvs/system" ]; then \
                echo "You already have a .venv, remove it to recreate"; \
                exit 1; \
            fi; \
        else \
	    ln -s .venvs/system .venv; \
        fi
	mkdir -p .venvs/
	if [ ! -e .venvs/system ]; then python3 -m venv .venvs/system; fi
	. .venv/bin/activate && python3 -m pip install -r requirements.txt && python3 -m pip install -e .
	echo -n "venv created, activate with:\n\n  source .venv/bin/activate\n\n"

.PHONY: venv
