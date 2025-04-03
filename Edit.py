from flask import Flask, render_template, request, redirect, url_for, flash
import paramiko
import json
from datetime import datetime, timedelta

app = Flask(__name__)
app.secret_key = "supersecretkey"  # Kunci rahasia untuk flash messages

# Load server data from server.json for both Xray and SSH renewal
def load_servers():
    try:
        with open('server.json', 'r') as file:
            return json.load(file)
    except Exception as e:
        print(f"Error loading server.json: {e}")
        return []

# Function to execute a command on a remote server via SSH
def execute_remote_command(server, command):
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(server['hostname'], username=server['username'], password=server['password'])

        stdin, stdout, stderr = ssh.exec_command(command)
        output = stdout.read().decode().strip()
        error = stderr.read().decode().strip()

        ssh.close()

        if error:
            print(f"Error executing command: {error}")
            return None
        return output
    except Exception as e:
        print(f"Error connecting to remote server: {e}")
        return None

# Function to get current expiration date using Paramiko for Xray
def get_current_expiration_ssh_xray(server, user):
    command = f"grep '### {user}' /etc/xray/config.json"
    output = execute_remote_command(server, command)

    if output:
        parts = output.split()
        if len(parts) >= 3:
            return parts[2]  # Expiration date
    return None

# Function to update expiration date using Paramiko for Xray
def update_expiration_ssh_xray(server, user, new_expiration):
    command = f"sed -i 's/^### {user} .*/### {user} {new_expiration}/' /etc/xray/config.json"
    return execute_remote_command(server, command) is not None

# Function to restart Xray service using Paramiko
def restart_xray_ssh(server):
    command = "systemctl restart xray"
    return execute_remote_command(server, command) is not None

# Function to get current expiration date using Paramiko for SSH
def get_current_expiration_ssh_user(server, user):
    command = f"chage -l {user}"
    output = execute_remote_command(server, command)

    if output:
        for line in output.splitlines():
            if "Account expires" in line:
                expiration_str = line.split(":")[1].strip()
                if expiration_str == "never":
                    return None
                return datetime.strptime(expiration_str, "%b %d, %Y")
    return None

# Function to update expiration date using Paramiko for SSH
def update_expiration_ssh_user(server, user, new_expiration):
    new_expiration_str = new_expiration.strftime('%Y-%m-%d')
    command = f"usermod -e {new_expiration_str} {user}"
    return execute_remote_command(server, command) is not None

# Route for renewing Xray accounts
@app.route("/renewxray", methods=["GET", "POST"])
def renewxray():
    servers = load_servers()  # Load server list from JSON
    if request.method == "POST":
        selected_server_name = request.form.get("server")
        user = request.form.get("username").strip()
        masaaktif = request.form.get("days")

        # Find the selected server details
        selected_server = next((server for server in servers if server['name'] == selected_server_name), None)
        if not selected_server:
            flash("Invalid server selection.", "error")
            return redirect(url_for("renewxray"))

        # Validate input
        if not user:
            flash("Username cannot be empty!", "error")
            return redirect(url_for("renewxray"))
        
        try:
            masaaktif = int(masaaktif)
            if masaaktif <= 0:
                raise ValueError
        except ValueError:
            flash("Invalid input. Please enter a valid number of days.", "error")
            return redirect(url_for("renewxray"))

        # Get current expiration date
        exp = get_current_expiration_ssh_xray(selected_server, user)
        if not exp:
            flash(f"User '{user}' does not exist or expiration date not found.", "error")
            return redirect(url_for("renewxray"))

        # Calculate new expiration date
        try:
            exp_date = datetime.strptime(exp, "%Y-%m-%d")
            new_expiration = (exp_date + timedelta(days=masaaktif)).strftime("%Y-%m-%d")
        except ValueError:
            flash("Invalid expiration date format in config file.", "error")
            return redirect(url_for("renewxray"))

        # Update expiration date
        if not update_expiration_ssh_xray(selected_server, user, new_expiration):
            flash("Failed to update expiration date on the remote server.", "error")
            return redirect(url_for("renewxray"))

        # Restart Xray service
        if not restart_xray_ssh(selected_server):
            flash("Failed to restart Xray service on the remote server.", "error")
            return redirect(url_for("renewxray"))

        # Success message
        flash(f"Expiration date for user '{user}' has been updated to {new_expiration} on server '{selected_server_name}'. Xray service restarted successfully.", "success")
        return redirect(url_for("renewxray"))

    return render_template("renewxray.html", servers=servers)

# Route for renewing SSH accounts
@app.route("/renewssh", methods=["GET", "POST"])
def renewssh():
    servers = load_servers()  # Load server list from JSON
    if request.method == "POST":
        selected_server_name = request.form.get("server")
        user = request.form.get("username").strip()
        days = request.form.get("days")

        # Find the selected server details
        selected_server = next((server for server in servers if server['name'] == selected_server_name), None)
        if not selected_server:
            flash("Invalid server selection.", "error")
            return redirect(url_for("renewssh"))

        # Validate input
        if not user or not days:
            flash("Username and days are required!", "error")
            return redirect(url_for("renewssh"))

        try:
            days = int(days)
            if days <= 0:
                raise ValueError
        except ValueError:
            flash("Days must be a positive integer!", "error")
            return redirect(url_for("renewssh"))

        # Check if the user exists on the remote server
        command = f"id {user}"
        if execute_remote_command(selected_server, command) is None:
            flash(f"User '{user}' does not exist on the remote server.", "error")
            return redirect(url_for("renewssh"))

        # Get current expiration date
        current_expiration = get_current_expiration_ssh_user(selected_server, user)
        if current_expiration is None:
            current_expiration = datetime.now()

        # Calculate new expiration date
        new_expiration = current_expiration + timedelta(days=days)
        new_expiration_display = new_expiration.strftime('%d %b %Y')

        # Update expiration date
        if not update_expiration_ssh_user(selected_server, user, new_expiration):
            flash("Failed to update expiration date for user on the remote server.", "error")
            return redirect(url_for("renewssh"))

        # Success message
        flash(f"Expiration date for user '{user}' has been updated to {new_expiration_display} on server '{selected_server_name}'.", "success")
        return redirect(url_for("renewssh"))

    return render_template("renewssh.html", servers=servers)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5005, debug=True)
