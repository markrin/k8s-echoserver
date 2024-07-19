import os
import argparse
import json
from flask import Flask, render_template, request
import socket
global env
import requests
import logging
logging.basicConfig(level=logging.DEBUG)

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--env', type=str, default='env not set', help='environment name (dev|stage|int|...)')
    return parser.parse_args()

app = Flask(__name__)

@app.route('/')
def default():
    return render_template('index.html', message='')

@app.route('/healthz', methods=['GET'])
def health():
    return { 'msg': 'healthy' }

@app.route('/', methods=['POST'])
def echo():
    ip = socket.gethostbyname(socket.gethostname())
    headers = {key: value for key, value in request.headers}
    app.logger.debug("Request Headers:")
    for key, value in headers.items():
        app.logger.debug(f"{key}: {value}")
    app.logger.debug(f"access_route: {request.access_route}")
    x_forwarded_for = request.headers.get('X-Forwarded-For', None)
    if x_forwarded_for:
        client_ip = x_forwarded_for.split(',')[0]
        app.logger.debug("x-forwarde-for found")
    else:
        client_ip = request.remote_addr
        app.logger.debug("NO x-forwarde-for")
    string = request.form['string']
    location = requests.get(f'http://ip-api.com/json/{client_ip}', stream=True)
    location = json.loads(location.text)
    location_string = f"{client_ip} is a local address, can't get location"
    if location['status'] != "fail":
        location_string = f"{location['country']}, {location['regionName']}, {location['city']}"
    return render_template('index.html', 
                        message=string,
                        server_ip=ip,  # request.server[0],
                        env=env,
                        location=location_string
    )


if __name__ == '__main__':
    args = parse_args()
    env = args.env
    print("env =", env)
    app.run(host="0.0.0.0", port=5000)
