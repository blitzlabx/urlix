# Urlix Makefile
# Creator: Blitz (blitzlabx)

.PHONY: test build run clean

test:
	@bash scripts/run_tests.sh

build:
	docker build -t urlix:latest .

run:
	docker run --rm -p 8080:8080 -e PORT=8080 --name urlix urlix:latest

clean:
	docker rm -f urlix 2>/dev/null || true
	docker rmi urlix:latest 2>/dev/null || true
