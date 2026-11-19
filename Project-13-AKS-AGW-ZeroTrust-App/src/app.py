from flask import Flask, render_template, request
import os
import socket

app = Flask(__name__)

@app.route('/')
def index():
    secret_path = '/mnt/secrets-store/DatabaseConnectionString' # Key Vault CSI
    db_secret = "No access to the secret (CSI Driver did not mount the file)"
    
    if os.path.exists(secret_path):
        with open(secret_path, 'r') as file:
            raw_secret = file.read().strip()
            db_secret = raw_secret[:25] + "******" if len(raw_secret) > 25 else raw_secret # Mask the Key Vault secret for display

    hostname = socket.gethostname() # Retrieve Pod (node) data from AKS
    host_ip = socket.gethostbyname(hostname)

    headers = dict(request.headers) # Collect HTTP headers (X-Forwarded-For)

    return render_template('index.html', 
                           hostname=hostname, 
                           host_ip=host_ip, 
                           headers=headers, 
                           db_secret=db_secret)

@app.route('/healthz')
def healthz(): # Endpoint for Application Gateway Health Probe
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)