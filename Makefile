# Makefile for Llama Stack Tutorial

# Environment variables with defaults
LLAMA_STACK_MODEL ?= meta-llama/Llama-3.2-3B-Instruct
INFERENCE_MODEL ?= meta-llama/Llama-3.2-3B-Instruct
SAFETY_MODEL_ID ?= meta-llama/Llama-Guard-3-8B
SAFETY_MODEL_OLLAMA ?= llama-guard3:8b-q4_0
OLLAMA_URL ?= http://host.containers.internal:11434
LLAMA_STACK_PORT ?= 8321
LLAMA_STACK_SERVER ?= http://localhost:$(LLAMA_STACK_PORT)
LLAMA_STACK_CONFIG_FILE ?= $(PWD)/apps/all-in-one/run-all.yaml

# Default target
.PHONY: all
all: run-all start-playground register-mcp

# Start Jaeger for telemetry
.PHONY: start-jaeger
start-jaeger:
	@echo "Starting Jaeger for telemetry..."
	podman run --rm --name jaeger \
		-p 16686:16686 -p 4318:4318 \
		-e COLLECTOR_OTLP_ENABLED=true \
		-e COLLECTOR_OTLP_HTTP_ENABLED=true \
		jaegertracing/jaeger:2.1.0 &

# Start MCP Weather service
.PHONY: start-mcp
start-mcp:
	@echo "Starting MCP Weather service..."
	podman run -p 3001:3001 quay.io/rh-aiservices-bu/mcp-weather:0.1.0 &

# Start Ollama models
.PHONY: start-ollama
start-ollama:
	@echo "Starting Ollama models..."
	ollama run llama3.2:3b-instruct-fp16 --keepalive 60m &
	ollama run llama-guard3:8b-q4_0 --keepalive 60m &

# Run the complete Llama Stack with all services
.PHONY: run-all
run-all: start-jaeger start-mcp start-ollama
	@echo "Starting Llama Stack with all services and auto-registered MCP..."
	@sleep 5
	podman run -d --name llama-stack \
		-p $(LLAMA_STACK_PORT):$(LLAMA_STACK_PORT) \
		-e INFERENCE_MODEL=$(LLAMA_STACK_MODEL) \
		-e SAFETY_MODEL_ID=$(SAFETY_MODEL_ID) \
		-e SAFETY_MODEL_OLLAMA=$(SAFETY_MODEL_OLLAMA) \
		-e OLLAMA_URL=$(OLLAMA_URL) \
		-v $(LLAMA_STACK_CONFIG_FILE):/root/my-run.yaml:ro \
		llamastack/distribution-ollama:0.2.9 \
		--port $(LLAMA_STACK_PORT) \
		--yaml-config /root/my-run.yaml
	@echo "Llama Stack started with MCP weather tools auto-registered!"
	@echo "Access the API at: http://localhost:$(LLAMA_STACK_PORT)"

# Register MCP toolgroup
.PHONY: register-mcp
register-mcp:
	@echo "Registering MCP Weather toolgroup..."
	curl -X POST -H "Content-Type: application/json" \
		--data '{ "provider_id" : "model-context-protocol", "toolgroup_id" : "mcp::weather", "mcp_endpoint" : { "uri" : "http://host.containers.internal:3001/sse"}}' \
		http://localhost:$(LLAMA_STACK_PORT)/v1/toolgroups

# Start playground UI
.PHONY: start-playground
start-playground:
	@echo "Waiting for Llama Stack to be ready before starting playground..."
	@for i in $$(seq 1 30); do \
		if curl -s http://localhost:$(LLAMA_STACK_PORT)/v1/models >/dev/null 2>&1; then \
			echo "Llama Stack is ready! Starting playground..."; \
			break; \
		fi; \
		echo "Waiting for Llama Stack... ($$i/30)"; \
		sleep 3; \
		if [ $$i -eq 30 ]; then \
			echo "Warning: Llama Stack may not be ready, starting playground anyway..."; \
		fi; \
	done
	podman run -d --name llama-playground -p 8502:8501 \
		-e LLAMA_STACK_ENDPOINT=http://host.containers.internal:$(LLAMA_STACK_PORT) \
		quay.io/rh-aiservices-bu/llama-stack-playground:0.2.11
	@echo "Llama Stack Playground started!"
	@echo "Access the playground at: http://localhost:8502"

# Stop and remove all containers but preserve databases
.PHONY: stop
stop:
	@echo "Stopping and removing all containers..."
	-podman rm -f llama-stack 2>/dev/null || true
	-podman rm -f jaeger 2>/dev/null || true
	-podman rm -f llama-playground 2>/dev/null || true
	@for container in $$(podman ps -aq --filter "ancestor=quay.io/rh-aiservices-bu/mcp-weather:0.1.0"); do \
		echo "Removing MCP weather container: $$container"; \
		podman rm -f $$container 2>/dev/null || true; \
	done
	@echo "All containers stopped and removed (databases preserved)"

# Clean up generated files and databases
.PHONY: clean
clean:
	@echo "Cleaning up databases and temporary files..."
	rm -f /var/tmp/telemetry.db
	rm -rf ~/.llama/distributions/ollama/*.db 2>/dev/null || true
	@echo "Cleanup completed (all data removed)"

# Setup environment
.PHONY: setup
setup:
	@echo "Setting up environment..."
	@echo "Environment setup completed"

# Check status
.PHONY: status
status:
	@echo "Checking Llama Stack status..."
	@echo "Llama Stack Model: $(LLAMA_STACK_MODEL)"
	@echo "Inference Model: $(INFERENCE_MODEL)"
	@echo "Safety Model ID: $(SAFETY_MODEL_ID)"
	@echo "Safety Model Ollama: $(SAFETY_MODEL_OLLAMA)"
	@echo "Ollama URL: $(OLLAMA_URL)"
	@echo "Llama Stack Port: $(LLAMA_STACK_PORT)"
	@echo "Config File: $(LLAMA_STACK_CONFIG_FILE)"

# Help
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all             - Run complete Llama Stack with playground (default)"
	@echo "  start-jaeger    - Start Jaeger for telemetry"
	@echo "  start-mcp       - Start MCP Weather service"
	@echo "  start-ollama    - Start Ollama models"
	@echo "  run-all         - Run complete Llama Stack with all services"
	@echo "  register-mcp    - Register MCP Weather toolgroup"
	@echo "  start-playground - Start Llama Stack Playground UI"
	@echo "  stop            - Stop and remove all containers (preserve databases)"
	@echo "  setup           - Setup environment"
	@echo "  clean           - Clean up database files and data"
	@echo "  status          - Show current configuration"
	@echo "  help            - Show this help message"