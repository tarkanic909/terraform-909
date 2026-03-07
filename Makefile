.PHONY: help init plan apply destroy validate fmt fmt-check clean info lab-up lab-down lab-list lab-info inventory vms-stop vms-start vms-undefine

.DEFAULT_GOAL := help

# Lab VMs lists (evaluated when used).
LAB_VMS_ALL = $(shell sudo virsh list --all | awk '$$2 ~ /^lab-/ {print $$2}')
LAB_VMS_ALL_LIST = $(shell sudo virsh list --all | awk '$$2 ~ /^lab-/ {print }')
LAB_VMS_RUNNING = $(shell sudo virsh list | awk '$$2 ~ /^lab-/ {print $$2}')

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
	terraform apply -auto-approve labplan

## destroy: - Destroy all resources
destroy:
	terraform destroy -auto-approve

## clean: - Clean up local terraform files
clean:
	rm -rf labplan .terraform

## info: - Show nodes info in json
info:
	terraform output -json node_info | jq '.'

## lab-up: - Quick cluster up
lab-up: init validate plan apply

## lab-down: - Quick cluster down
lab-down: destroy

## lab-list: - libvirt List lab VMs 
lab-list:
	@echo "List all lab vms (all states)"
	sudo virsh list --all | awk '$$2 ~ /^lab-/ {print }'

## vms-stop: - libvirt Stop all running lab VMs in 
vms-stop:
	@echo "Stopping running lab VMs..."
	@for vm in $(LAB_VMS_RUNNING); do \
		echo "  $$vm"; \
		sudo virsh destroy "$$vm" 2>/dev/null || true; \
	done
	@echo "Done."

## vms-start: - libvirt Start all lab VMs in libvirt
vms-start:
	@echo "Starting lab VMs..."
	@for vm in $(LAB_VMS_ALL); do \
		echo "  $$vm"; \
		sudo virsh start "$$vm" 2>/dev/null || true; \
	done
	@echo "Done."

## vms-undefine: - libvirt Undefine all lab VMs and remove their storage in libvirt
vms-undefine: vms-stop
	@echo "Undefining lab VMs..."
	@for vm in $(LAB_VMS_ALL); do \
		echo "  $$vm"; \
		sudo virsh undefine "$$vm" --remove-all-storage; \
	done
	@echo "Done."
