.PHONY: help init plan apply destroy validate fmt fmt-check clean info lab-up lab-down lab-wait lab-list lab-info vms-stop vms-start vms-undefine

.DEFAULT_GOAL := help

VIRSH = virsh -c qemu:///system

# Lab VMs lists (evaluated when used).
LAB_VMS_ALL     = $(shell $(VIRSH) list --all | awk '$$2 ~ /^lab-/ {print $$2}')
LAB_VMS_RUNNING = $(shell $(VIRSH) list | awk '$$2 ~ /^lab-/ {print $$2}')

help:
	@echo "Available targets:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## init: - Terraform init + backend
init:
	terraform init

## fmt: - Format code
fmt:
	terraform fmt -recursive

## fmt-check: - Check formatting (CI)
fmt-check:
	terraform fmt -recursive -check

## validate: - Code formatting + validation
validate: fmt-check
	terraform validate

## plan: - Plan (save to file)
plan:
	terraform plan -out=labplan

## apply: - Apply saved plan
apply:
	@test -f labplan || (echo "Error: no plan file found, run 'make plan' first." && exit 1)
	terraform apply -auto-approve labplan

## destroy: - Destroy all resources
destroy:
	@read -p "Destroy ALL resources? [yes/N]: " confirm && \
	[ "$$confirm" = "yes" ] || (echo "Aborted." && exit 1)
	terraform destroy -auto-approve

## clean: - Clean up local terraform files
clean:
	rm -rf labplan .terraform

## info: - Show nodes info in json
info:
	terraform output -json node_info | jq '.'

## lab-up: - Quick cluster up (init → validate → plan → apply → wait for cloud-init)
lab-up: init validate plan apply lab-wait

## lab-down: - Quick cluster down
lab-down: destroy

## lab-wait: - Wait for all lab VMs to finish cloud-init (reboot included)
lab-wait:
	@echo "Waiting for cloud-init to finish on all lab VMs..."
	@for vm in $(LAB_VMS_ALL); do \
		echo "  Waiting for $$vm..."; \
		ip=$$(terraform output -json node_info 2>/dev/null | jq -r --arg vm "$$vm" '.[$vm].mgmt_ip // empty'); \
		if [ -z "$$ip" ]; then echo "  WARNING: no mgmt_ip for $$vm, skipping"; continue; fi; \
		for i in $$(seq 1 30); do \
			ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
				ansible@$$ip "cloud-init status --wait 2>/dev/null || true" 2>/dev/null && break; \
			echo "    attempt $$i/30 — not ready yet, retrying in 10s..."; \
			sleep 10; \
		done; \
		echo "  $$vm ready."; \
	done
	@echo "All VMs ready."

## lab-list: - libvirt List lab VMs
lab-list:
	@echo "List all lab vms (all states)"
	$(VIRSH) list --all | awk '$$2 ~ /^lab-/ {print }'

## lab-info: - libvirt Show lab VM details (CPU, memory, state)
lab-info:
	@for vm in $(LAB_VMS_ALL); do \
		echo "=== $$vm ==="; \
		$(VIRSH) dominfo "$$vm" | grep -E 'State|CPU|Max memory|Used memory'; \
	done

## vms-stop: - libvirt Stop all running lab VMs
vms-stop:
	@echo "Stopping running lab VMs..."
	@for vm in $(LAB_VMS_RUNNING); do \
		echo "  $$vm"; \
		$(VIRSH) destroy "$$vm" 2>/dev/null || true; \
	done
	@echo "Done."

## vms-start: - libvirt Start all lab VMs in libvirt
vms-start:
	@echo "Starting lab VMs..."
	@for vm in $(LAB_VMS_ALL); do \
		echo "  $$vm"; \
		$(VIRSH) start "$$vm" 2>/dev/null || true; \
	done
	@echo "Done."

## vms-undefine: - libvirt Undefine all lab VMs and remove their storage in libvirt
vms-undefine: vms-stop
	@echo "Undefining lab VMs..."
	@failed=0; \
	for vm in $(LAB_VMS_ALL); do \
		echo "  $$vm"; \
		$(VIRSH) undefine "$$vm" --remove-all-storage || { echo "ERROR: failed to undefine $$vm" >&2; failed=1; }; \
	done; \
	[ "$$failed" -eq 0 ] || (echo "Some VMs failed to undefine." >&2; exit 1)
	@echo "Done."
