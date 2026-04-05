set shell := ["bash", "-cu"]

fmt:
	zig fmt .

fmt-check:
	zig fmt --check .

build:
	zig build

test:
	zig build test

test-release:
	zig build test -Doptimize=ReleaseSafe

docs:
	zig build docs

check: fmt-check build test

ci: check

env:
	zig version
	just --version
