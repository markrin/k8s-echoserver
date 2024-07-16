FROM python:3.12-bullseye

RUN pip3 install flask requests

WORKDIR /app

COPY ./app .

EXPOSE 5000

ENTRYPOINT [ "python", "app.py"]
CMD [ "--env=dev" ]
