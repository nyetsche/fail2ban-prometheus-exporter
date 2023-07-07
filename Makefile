DESTDIR?=
PREFIX?=/usr/local
EXECUTABLE?=fail2ban_exporter

CONTAINER_RUNTIME?=$(shell which docker)

# List make commands
.PHONY: ls
ls:
	cat Makefile | grep "^[a-zA-Z#].*" | cut -d ":" -f 1 | sed s';#;\n#;'g

# Download dependencies
.PHONY: download
download:
	go mod download

# Update project dependencies
.PHONY: update
update:
	go get -u
	go mod download
	go mod tidy

# Run project tests
.PHONY: test
test: download
	go test ./... -v -race

# Look for "suspicious constructs" in source code
.PHONY: vet
vet: download
	go vet ./...

# Format code
.PHONY: fmt
fmt: download
	go mod tidy
	go fmt ./...

# Check for unformatted go code
.PHONY: check/fmt
check/fmt: download
	test -z $(shell gofmt -l .)

# Build project
.PHONY: build
build:
	CGO_ENABLED=0 go build \
	-ldflags "\
	-X main.version=${shell git describe --tags} \
	-X main.commit=${shell git rev-parse HEAD} \
	-X main.date=${shell date --iso-8601=seconds} \
	-X main.builtBy=manual \
	" \
	-trimpath \
	-o ${EXECUTABLE} \
	exporter.go

# build container-image
.PHONY: build/container-image
build/container-image:
	${CONTAINER_RUNTIME} build \
		--tag ${EXECUTABLE} \
		.

.PHONY: install
install: build
	mkdir --parents ${DESTDIR}/usr/lib/systemd/system
	sed -e "s/EXECUTABLE/${EXECUTABLE}/gm" systemd/systemd.service > ${DESTDIR}/usr/lib/systemd/system/${EXECUTABLE}.service
	chmod 0644 ${DESTDIR}/usr/lib/systemd/system/${EXECUTABLE}.service

	install -D --mode 0755 --target-directory ${DESTDIR}${PREFIX}/bin ${EXECUTABLE}

# NOTE: Set restrict file permissions by default to protect optional basic auth credentials
	install -D --mode 0600 env ${DESTDIR}/etc/conf.d/${EXECUTABLE}

	install -D --mode 0755 --target-directory ${DESTDIR}${PREFIX}/share/licenses/${EXECUTABLE} LICENSE

.PHONY: uninstall
uninstall:
	-rm --recursive --force \
		${DESTDIR}${PREFIX}/bin/${EXECUTABLE} \
		${DESTDIR}/usr/lib/systemd/system/${EXECUTABLE}.service \
		${DESTDIR}/etc/conf.d/${EXECUTABLE} \
		${DESTDIR}${PREFIX}/share/licenses/${EXECUTABLE}/LICENSE
