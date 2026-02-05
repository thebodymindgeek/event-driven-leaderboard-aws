.PHONY: fmt init plan deploy destroy build clean outputs demo

INFRA_DIR=infra
LAMBDA_DIR=lambdas

fmt:
	cd $(INFRA_DIR) && terraform fmt -recursive

init:
	cd $(INFRA_DIR) && terraform init

plan:
	cd $(INFRA_DIR) && terraform plan

deploy:
	cd $(INFRA_DIR) && terraform apply

destroy:
	cd $(INFRA_DIR) && terraform destroy

outputs:
	cd $(INFRA_DIR) && terraform output

clean:
	rm -rf $(DIST)

# A convenience target for first-time setup (works whether you use archive_file or dist zips)
demo: fmt init build deploy outputs

simulate:
	@echo "Invoking activity simulator..."
	aws lambda invoke \
	  --function-name edl-dev-activity-simulator \
	  response.json \
	  --log-type Tail
	@cat response.json