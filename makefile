include .env
export

all: 
	forge install

coverage:
	forge coverage --report lcov && genhtml -o coverage-report ./lcov.info --ignore-errors category && open coverage-report/index.html

open-coverage:
	genhtml -o coverage-report ./lcov.info --ignore-errors category && open coverage-report/index.html

deploy:
	./script/deploy.sh

upgradeTo:
	./script/upgradeTo.sh
