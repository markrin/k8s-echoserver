note*: eu-central-1 region is used. substitute any if needed.

## test Docker

docker build -t pyecho:1 .
docker run --name pyecho -d -p 5000:5000 pyecho:1 --env=internal

## terraform container

docker build -t terraform -f ./tf/tf.Dockerfile ./tf
docker run --name terraform -d -v ./tf:/home/tf -e AWS_ACCESS_KEY_ID=x -e AWS_SECRET_ACCESS_KEY=y -e AWS_DEFAULT_REGION=eu-central-1 terraform

## ECR - push image

```
aws ecr get-login-password --profile <profile> --region eu-central-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.eu-central-1.amazonaws.com
docker tag pyecho:1 <account_id>.dkr.ecr.eu-central-1.amazonaws.com/mark-pyecho:1
docker push <account_id>.dkr.ecr.eu-central-1.amazonaws.com/mark-pyecho:1
```

## k8s

to get/update kubeconfig:
`aws eks --region eu-central-1 update-kubeconfig --name mark-assignment`
check connectivity:
`kubectl get ns`

## helm
```
helm package ./helm --version "0.0.1"
aws ecr get-login-password --profile <profile> --region eu-central-1 | helm registry login --username AWS --password-stdin <account_id>.dkr.ecr.eu-central-1.amazonaws.com
helm push ./mark-pyecho-0.0.1.tgz oci://<account_id>.dkr.ecr.eu-central-1.amazonaws.com
```
