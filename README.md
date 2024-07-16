## test Docker

docker build -t pyecho:1 .
docker run --name pyecho -d -p 5000:5000 pyecho:1 --env=internal

## terraform container

docker build -t terraform -f tf/tf.Dockerfile ./tf
docker run --name terraform -d -v ./tf:/home/tf -e AWS_ACCESS_KEY_ID=x -e AWS_SECRET_ACCESS_KEY=y terraform
