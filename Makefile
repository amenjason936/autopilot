.PHONY: check test lint syntax training
check: lint syntax test
lint:
	shellcheck -x -P scripts scripts/*.sh
syntax:
	@for script in scripts/*.sh; do bash -n "$$script" || exit; done
	python3 -c 'import ast,pathlib; [ast.parse(p.read_text(), filename=str(p)) for p in pathlib.Path("scripts").glob("*.py")]'
test:
	bats tests
training:
	bash scripts/training-ground.sh "$${TRAINING_DIR:?Set TRAINING_DIR to a new directory}"
