.PHONY: help init plan apply destroy validate fmt fmt-check info lab-up lab-down vms-list inventory

.DEFAULT_GOAL := help

help:
	@echo "Available targets:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

## init - Terraform init + backend
init:
	terraform init

## fmt - Format code
fmt:
	terraform fmt -recursive

# fmt-check - Check formatting (CI)
fmt-check:
	terraform fmt -recursive -check

## validate - Code formatting + validation
validate: fmt-check
	terraform validate

## plan - Plan (save to file)
plan:
	terraform plan -out=labplan

## apply - Apply saved plan
apply:
	terraform apply -auto-approve labplan

## destory - Destroy all resources
destroy:
	terraform destroy -auto-approve

## clean -  Clean up local terraform files
clean:
	rm -rf labplan .terraform

## info - Show nodes info in json
info:
	terraform output -json node_info | jq '.'

## lab-up - Quick cluster up
lab-up: init validate plan apply

## lab-down - Quick cluster down
lab-down: destroy
	
## vms-list - List vms in libvirt
vms-list:
	@sudo virsh list | grep vm | awk '{ print $$2 }'

vms-info:
	sudo virsh list | grep vm | awk '{ print $$2 }'

## inventory -  Generate Ansible inventory
inventory:
	@terraform output -json node_info | jq -r ' "[masters]", (to_entries[] | select(.key | startswith("k3s-master")) | .value.ip), "", "[workers]", (to_entries[] | select(.key | startswith("k3s-worker")) | .value.ip) ' > inventory.ini 
