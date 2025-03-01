# the name of this package
PKG  := $(shell go list .)
PROTOC_VER := $(shell protoc --version | cut -d' ' -f2)

.PHONY: bootstrap
bootstrap: testdata # set up the project for development

.PHONY: quick
quick: testdata # runs all tests without the race detector or coverage
ifeq ($(PROTOC_VER), 3.17.0)
	go test $(PKGS) --tags=proto3_presence
else
	go test $(PKGS)
endif

.PHONY: tests
tests: testdata # runs all tests against the package with race detection and coverage percentage
ifeq ($(PROTOC_VER), 3.17.0)
	go test -race -cover ./... --tags=proto3_presence
else
	go test -race -cover ./...
endif

.PHONY: cover
cover: testdata # runs all tests against the package, generating a coverage report and opening it in the browser
ifeq ($(PROTOC_VER), 3.17.0)
	go test -race -covermode=atomic -coverprofile=cover.out ./... --tags=proto3_presence || true
else
	go test -race -covermode=atomic -coverprofile=cover.out ./... || true
endif
	go tool cover -html cover.out -o cover.html
	open cover.html

.PHONY: docs
docs: # starts a doc server and opens a browser window to this package
	(sleep 2 && open http://localhost:6060/pkg/$(PKG)/) &
	godoc -http=localhost:6060

#.PHONY: testdata
#testdata: testdata-graph testdata-go testdata/generated testdata/fdset.bin # generate all testdata

.PHONY: testdata-graph
testdata-graph: bin/protoc-gen-debug # parses the proto file sets in testdata/graph and renders binary CodeGeneratorRequest
	set -e; for subdir in `find ./testdata/graph -mindepth 1 -maxdepth 1 -type d`; do \
		protoc -I ./testdata/graph \
			--plugin=protoc-gen-debug=./bin/protoc-gen-debug \
			--debug_out="$$subdir:$$subdir" \
			`find $$subdir -name "*.proto"`; \
	done

#testdata/generated: protoc-gen-go bin/protoc-gen-example
#	which protoc-gen-go || (go install github.com/golang/protobuf/protoc-gen-go)
#	rm -rf ./testdata/generated && mkdir -p ./testdata/generated
#	# generate the official go code, must be one directory at a time
#	set -e; for subdir in `find ./testdata/protos -mindepth 1 -type d`; do \
#		files=`find $$subdir -maxdepth 1 -name "*.proto"`; \
#		[ ! -z "$$files" ] && \
#		protoc -I ./testdata/protos \
#			--go_out="$$GOPATH/src" \
#			$$files; \
#	done
#	# generate using our demo plugin, don't need to go directory at a time
#	set -e; for subdir in `find ./testdata/protos -mindepth 1 -maxdepth 1 -type d`; do \
#		protoc -I ./testdata/protos \
#			--plugin=protoc-gen-example=./bin/protoc-gen-example \
#			--example_out="paths=source_relative:./testdata/generated" \
#			`find $$subdir -name "*.proto"`; \
#	done

testdata/fdset.bin:
	@protoc -I ./testdata/protos \
		-o ./testdata/fdset.bin \
		--include_imports \
		testdata/protos/**/*.proto

.PHONY: testdata-go-v2
testdata-go-v2: protoc-gen-go-v2 bin/protoc-gen-debug # generate go-specific testdata
	cd v2/lang/go && $(MAKE) \
		testdata-names \
		testdata-packages \
		testdata-outputs
ifeq ($(PROTOC_VER), 3.17.0)
	cd v2/lang/go && $(MAKE) \
		testdata-presence
endif

vendor: # install project dependencies
	which glide || (curl https://glide.sh/get | sh)
	glide install

#.PHONY: protoc-gen-go
#protoc-gen-go:
#	which protoc-gen-go || (go install github.com/golang/protobuf/protoc-gen-go)

.PHONY: protoc-gen-go-v2
protoc-gen-go-v2:
	go install google.golang.org/protobuf/cmd/protoc-gen-go


bin/protoc-gen-example: # creates the demo protoc plugin for demonstrating uses of PG*
	go build -o ./bin/protoc-gen-example ./testdata/protoc-gen-example

bin/protoc-gen-debug: # creates the protoc-gen-debug protoc plugin for output ProtoGeneratorRequest messages
	go build -o ./bin/protoc-gen-debug ./protoc-gen-debug

.PHONY: clean
clean:
	rm -rf vendor
	rm -rf bin
	rm -rf testdata/generated
	set -e; for f in `find . -name *.pb.bin`; do \
		rm $$f; \
	done
	set -e; for f in `find . -name *.pb.go`; do \
		rm $$f; \
	done

.PHONY: tests-v2
tests-v2: testdata-v2 # runs all tests against the package with race detection and coverage percentage
ifeq ($(PROTOC_VER), 3.17.0)
	cd v2 && go test -race -cover ./... --tags=proto3_presence
else
	cd v2 && go test -race -cover ./...
endif

.PHONY: testdata-v2
testdata-v2: testdata-graph testdata-go-v2 testdata/generated-v2 testdata/fdset.bin # generate all testdata

testdata/generated-v2: protoc-gen-go-v2 bin/protoc-gen-example
	go install google.golang.org/protobuf/cmd/protoc-gen-go
	rm -rf ./testdata/generated/v2 && mkdir -p ./testdata/generated/v2
	# generate the official go code, must be one directory at a time
	set -e; for subdir in `find ./testdata/protos -mindepth 1 -type d`; do \
		files=`find $$subdir -maxdepth 1 -name "*.proto"`; \
		[ ! -z "$$files" ] && \
		protoc -I ./testdata/protos \
			--go_out="$$GOPATH/src" \
			$$files; \
	done
	# generate using our demo plugin, don't need to go directory at a time
	set -e; for subdir in `find ./testdata/protos -mindepth 1 -maxdepth 1 -type d`; do \
		protoc -I ./testdata/protos \
			--plugin=protoc-gen-example=./bin/protoc-gen-example \
			--example_out="paths=source_relative:./testdata/generated/v2" \
			`find $$subdir -name "*.proto"`; \
	done