note*: eu-central-1 region is used. substitute any if needed. neme "pyecho" can be changed to any using terraform input variables
note**: assumed you have docker, kubectl, helm, aws cli installed and configured

Preparation:
clone the repository and cd to it's root. You can also open the code in IDE.

## Docker image

Package application into docker image
```
docker build -t pyecho:1 .
# (optional) for testing purposes, open localhost:5000
docker run --name pyecho -d -p 5000:5000 pyecho:1 --env=internal
```
## Terraform container

Run terraform container with all installed dependencies and create infrastructure
Helm deployment will fail because no chart and docker image pushed yet

Optional preparations: create remote backend.
Copy provider.tf file to other folder, comment marked part and set backend = "local"
run tf init and tf apply. This should create s3 bucket and dynamodb table. 
Comment backend and uncomment s3 backend configs. Run tf plan and expect no changes.

```
docker build -t terraform -f ./tf/tf.Dockerfile ./tf
# set desired region for infrastructure using AWS_DEFAULT_REGION
docker run --name tf -d -v ./tf:/home/tf -e AWS_ACCESS_KEY_ID=x -e AWS_SECRET_ACCESS_KEY=y -e AWS_DEFAULT_REGION=eu-central-1 terraform
docker exec -it tf bash
> tf plan -var 'env=dev'
> tf apply -var 'env=dev'

```
Setup kubeconfig and check k8s connectivity
1) to get/update kubeconfig:
`aws eks --region eu-central-1 update-kubeconfig --name mark-assignment`
2) check connectivity:
`kubectl get ns`

Now we need to push helm chart and docker image to ECR

## ECR - push image

Use `--profile` flag if you are using different than default
```
aws ecr get-login-password --profile <profile> --region eu-central-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.eu-central-1.amazonaws.com
docker tag pyecho:1 <account_id>.dkr.ecr.eu-central-1.amazonaws.com/mark-pyecho:1
docker push <account_id>.dkr.ecr.eu-central-1.amazonaws.com/mark-pyecho:1
```

## Package Helm chart
```
helm package ./helm --version "0.0.1"
aws ecr get-login-password --profile <profile> --region eu-central-1 | helm registry login --username AWS --password-stdin <account_id>.dkr.ecr.eu-central-1.amazonaws.com
helm push ./mark-pyecho-0.0.1.tgz oci://<account_id>.dkr.ecr.eu-central-1.amazonaws.com
```
## Final setup

deploy helm chart using terraform container from previous stages
```
docker exec -it tf bash
> tf plan -var 'env=dev'
> tf apply -var 'env=dev'
```
Helm chart should be deployed. Check k8s resources in default namespace

```
kubectl get all -n default # app
kubectl get ingress
kubectl get all -n kube-system # alb controller and etc
```

---

access echoserver:
`kubectl get ingress -o yaml | grep hostname`
copy the address and access it using browser


## Extra: deploy using terragrunt

cd to tf/terragrunt/envs/dev or create your folder inside envs/, copy terragrunt.hcl file, modify variables
```
git config --global --add safe.directory '*' # supress modules ownership errors
terragrunt init
terragrunt plan
terragrunt apply
```
