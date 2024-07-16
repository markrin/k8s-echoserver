import os
import argparse
import json
from flask import Flask, render_template, request
import socket
global env
import requests

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
    client_ip = request.remote_addr  # '54.48.0.1'
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
                        location=location_string #request.headers.get('x-forwarded-for', 'none'))
    )


if __name__ == '__main__':
    args = parse_args()
    env = args.env
    print("env =", env)
    app.run(host="0.0.0.0", port=5000)
