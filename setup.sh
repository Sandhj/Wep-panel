echo -e "Silahkan Masukkan Data Web anda :"
echo -e "══════════════════════⊹⊱≼≽⊰⊹══"
read -p "Nama Folder :" identity
read -p "Nama Admin :" admin
read -p "Domain :" DOMAIN
read -p "Port :" PORT
read -p "Token Tele :" tele
read -p "Id Tele :" idtele

cd
apt update 
sudo apt install git
apt install python3.11-venv

LINK="https://raw.githubusercontent.com/Sandhj/Wep-panel/main/"

mkdir -p /root/$identity/templates
mkdir -p /root/$identity/backup
mkdir -p /root/$identity/static

cd $identity
cat <<EOL > /root/$identity/app.py
from flask import Flask, render_template, request, redirect, session, g, flash, url_for, jsonify, flash
import sqlite3
import os
import paramiko
import subprocess
import json
import shutil
import urllib.parse
import telebot


app = Flask(__name__)
app.secret_key = os.urandom(24)
DATABASE = "database.db"

def get_db():
    db = getattr(g, "_database", None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, "_database", None)
    if db is not None:
        db.close()

def init_db():
    with app.app_context():
        db = get_db()
        cursor = db.cursor()
        # Tabel untuk menyimpan data pengguna
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                password TEXT NOT NULL,
                balance INTEGER DEFAULT 0
            )
        ''')
        # Tabel untuk menyimpan data session (pembuatan akun)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                operator TEXT,
                username TEXT,
                device TEXT,
                protocol TEXT,
                expired INTEGER,
                output TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        db.commit()

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# PAGE LOGIN & REGISTRASI 
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
@app.route("/")
def login_temp():
    if "username" in session:
        if session["username"] == "$admin":
            return redirect("/admin")
        else:
            return redirect("/guest")
    return redirect("/login")

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]
        db = get_db()
        user = db.execute("SELECT * FROM users WHERE username = ? AND password = ?", (username, password)).fetchone()
        if user:
            session["username"] = username
            if username == "$admin":
                return redirect("/admin")
            return redirect("/guest")
        else:
            flash("Username atau password salah!", "error")
            return redirect("/login")
    return render_template("login.html")

@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]
        db = get_db()
        try:
            db.execute("INSERT INTO users (username, password) VALUES (?, ?)", (username, password))
            db.commit()
            flash("Registrasi berhasil! Silakan login.", "success")
            return redirect("/login")
        except sqlite3.IntegrityError:
            flash("Username sudah digunakan!", "error")
            return redirect("/register")
    return render_template("register.html")

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# PAGE DASHBOARD ADMIN DAN PELANGGAN
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

@app.route("/guest")
def guest_dashboard():
    if "username" not in session or session["username"] == "$admin":
        return redirect("/login")
    username = session["username"]
    db = get_db()
    user = db.execute("SELECT balance FROM users WHERE username = ?", (username,)).fetchone()
    balance = user["balance"] if user else 0
    return render_template("dash_guest.html", username=username, balance=balance)

@app.route("/admin")
def admin_dashboard():
    if "username" not in session or session["username"] != "$admin":
        return redirect("/login")
    username = session["username"]
    db = get_db()
    user = db.execute("SELECT balance FROM users WHERE username = ?", (username,)).fetchone()
    balance = user["balance"] if user else 0
    return render_template("dash_admin.html", username=username, balance=balance)

@app.route("/home", methods=['GET'])
def home():
    username = session["username"]
    db = get_db()
    user = db.execute("SELECT balance FROM users WHERE username = ?", (username,)).fetchone()
    balance = user["balance"] if user else 0
    return render_template("home.html", username=username, balance=balance)



# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# TAMBAH SALDO USER
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

# Route untuk form tambah saldo
@app.route("/tambah_saldo_user", methods=["GET", "POST"])
def add_balance():
    db = get_db()
    cursor = db.cursor()

    if request.method == "POST":
        username = request.form.get("username")
        balance_to_add = request.form.get("balance")

        if not username or not balance_to_add:
            flash("Username dan jumlah saldo harus diisi.", "error")
            return redirect("/tambah_saldo_user")

        try:
            balance_to_add = int(balance_to_add)
            if balance_to_add <= 0:
                flash("Jumlah saldo harus lebih dari 0.", "error")
                return redirect("/tambah_saldo_user")
        except ValueError:
            flash("Jumlah saldo harus berupa angka.", "error")
            return redirect("/tambah_saldo_user")

        cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
        user = cursor.fetchone()

        if user:
            new_balance = user["balance"] + balance_to_add
            cursor.execute("UPDATE users SET balance = ? WHERE username = ?", (new_balance, username))
            db.commit()
            flash(f"Saldo berhasil ditambahkan untuk {username}. Saldo baru: {new_balance}", "success")
        else:
            flash(f"Pengguna dengan username '{username}' tidak ditemukan.", "error")

        return redirect("/tambah_saldo_user")

    # Untuk method GET, query semua username dari tabel users
    cursor.execute("SELECT username FROM users")
    # Jika cursor.fetchall() mengembalikan list of tuples, Anda bisa melakukan:
    users = [dict(row) for row in cursor.fetchall()]
    # Atau jika sudah dikonfigurasi agar mengembalikan dict, cukup:
    # users = cursor.fetchall()

    return render_template("tambah_saldo_user.html", users=users)


# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# LIHAT DATA USER
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

@app.route('/list_user', methods=['GET'])
def users():
    db = get_db()
    cursor = db.execute("SELECT username, balance FROM users")
    users = cursor.fetchall()
    return render_template('list_user.html', users=users)

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# KURANGI SALDO USER
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

@app.route('/kurangi_saldo_user', methods=['GET', 'POST'])
def kurangi_saldo():
    message = None
    if request.method == 'POST':
        username = request.form.get('username')
        amount_str = request.form.get('amount')

        # Validasi input jumlah
        try:
            amount = int(amount_str)
            if amount <= 0:
                message = "Jumlah harus lebih dari nol."
        except (ValueError, TypeError):
            message = "Jumlah tidak valid. Masukkan angka yang benar."

        if not message:
            db = get_db()
            # Ambil saldo pengguna berdasarkan username
            cursor = db.execute("SELECT balance FROM users WHERE username = ?", (username,))
            user = cursor.fetchone()
            if user:
                current_balance = user['balance']
                if current_balance < amount:
                    message = "Saldo tidak cukup untuk dikurangi."
                else:
                    new_balance = current_balance - amount
                    db.execute("UPDATE users SET balance = ? WHERE username = ?", (new_balance, username))
                    db.commit()
                    message = f"Saldo pengguna {username} berhasil dikurangi sebanyak {amount}."
            else:
                message = "Pengguna tidak ditemukan."

    return render_template('kurangi_saldo_user.html', message=message)

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# PAGE CREATE AKUN VPN PREMIUM 
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

# Fungsi untuk mendapatkan jumlah pengguna (current) melalui SSH
def get_current_users_vpn(hostname, username, password):
    try:
        # Setup SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())  # Menerima host key yang tidak dikenal
        
        # Connect to the server
        ssh.connect(hostname, username=username, password=password)

        # Jalankan script user.sh dan ambil outputnya
        stdin, stdout, stderr = ssh.exec_command("user.sh")
        output = stdout.read().decode().strip()  # Ambil hasil output
        
        ssh.close()
        
        # Kembalikan jumlah user yang sedang aktif (current) sebagai integer
        return int(output)
    except Exception as e:
        print(f"Error: {e}")
        return None  # Jika gagal, kembalikan None
# Fungsi untuk mendapatkan daftar VPS dari file server.json
def get_vps_list():
    with open('server.json', 'r') as f:
        return json.load(f)

@app.route('/vps-list', methods=['GET'])
def vps_list():
    # Membaca daftar VPS dari file JSON
    vps_list = get_vps_list()
    
    # Set max_user
    max_user = 25
    
    filtered_vps = []
    
    # Memeriksa jumlah pengguna (current) pada masing-masing VPS
    for vps in vps_list:
        current_users = get_current_users_vpn(vps["hostname"], vps["username"], vps["password"])
        
        # Jika jumlah pengguna belum mencapai max_user, tambahkan ke daftar
        if current_users is not None and current_users < max_user:
            vps["current_users"] = current_users
            vps["max_user"] = max_user
            filtered_vps.append(vps)
    
    # Mengirimkan daftar VPS yang belum mencapai max_user
    return jsonify(filtered_vps)

# Fungsi untuk menghubungkan ke VPS dan menjalankan skrip
def run_script_on_vps(vps, protocol, username, expired):
    try:
        # Koneksi SSH ke VPS
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())  # Menambahkan host key jika tidak ada
        ssh.connect(vps['hostname'], username=vps['username'], password=vps['password'])

        # Jalankan skrip di VPS
        command = f"create_{protocol}"
        stdin, stdout, stderr = ssh.exec_command(command)
        stdin.write(f"{username}\n{expired}\n")
        stdin.flush()

        # Ambil output dari skrip
        output = stdout.read().decode('utf-8')

        ssh.close()
        
        return output

    except Exception as e:
        print(f"Error: {str(e)}")
        return f"Error: {str(e)}"

@app.route('/create_temp', methods=['GET'])
def create_account_temp():
    return render_template('create.html')

@app.route('/create', methods=['POST'])
def create_account():
    # Cek sesi aktif
    if 'username' not in session:
        return redirect('/login')

    # Ambil username dari sesi aktif (operator yang melakukan transaksi)
    active_user = session['username']

    # Ambil data dari form
    protocol = request.form['protocol']
    device = request.form['device']
    username = request.form['username']  # username yang akan dibuat di VPS
    expired = int(request.form['expired'])
    vps_name = request.form['vps']  # Nama VPS yang dipilih dari dropdown

    # Logika pengurangan saldo
    cost_per_device = {'hp': 5000, 'stb': 10000}  # Biaya per device
    cost_per_expired = {30: 1, 60: 2, 90: 3, 120: 4}  # Faktor pengganda berdasarkan expired

    # Validasi device dan expired
    if device not in cost_per_device or expired not in cost_per_expired:
        return "Invalid device or expired value", 400

    # Hitung biaya pengurangan saldo
    total_cost = cost_per_device[device] * cost_per_expired[expired]

    # Cek saldo pengguna
    db = get_db()
    cursor = db.cursor()

    # Ambil saldo pengguna aktif
    cursor.execute("SELECT balance FROM users WHERE username = ?", (active_user,))
    user_data = cursor.fetchone()

    if not user_data:
        flash("Silahkan Login Kembali dan coba lagi", "error")
        return redirect('/create_temp')

    current_balance = user_data['balance']

    # Periksa apakah saldo mencukupi
    if current_balance < total_cost:
        flash("Saldo Kamu Tidak Mencukupi Untuk Melanjutkan Transaksi.", "error")
        return redirect('/create_temp')

    # Kurangi saldo
    new_balance = current_balance - total_cost
    cursor.execute("UPDATE users SET balance = ? WHERE username = ?", (new_balance, active_user))
    db.commit()

    # Ambil daftar VPS
    vps_list = get_vps_list()
    vps = next((v for v in vps_list if v['name'] == vps_name), None)

    if not vps:
        flash("VPS not found.", "error")
        return redirect('/create_temp')

    print(f"Received data - Protocol: {protocol}, Device: {device}, Username: {username}, Expired: {expired}, Cost: {total_cost}")

    # Menjalankan skrip shell di VPS yang dipilih
    output = run_script_on_vps(vps, protocol, username, expired)

    # Simpan data session ke dalam database
    try:
        cursor.execute(
            "INSERT INTO user_sessions (operator, username, device, protocol, expired, output) VALUES (?, ?, ?, ?, ?, ?)",
            (active_user, username, device, protocol, expired, output)
        )
        db.commit()

    except Exception as e:
        print(f"Error saat menyimpan session: {e}")
        # Anda bisa menambahkan flash atau logging error di sini jika diperlukan

    return render_template(
        'result.html',
        username=username,
        device=device,
        expired=expired,
        protocol=protocol,
        output=output,
        cost=total_cost,
        balance=new_balance
    )

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# RIWAYAT DAN DETAIL AKUN USER
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

@app.route('/riwayat_akun', methods=['GET'])
def riwayat():
    # Cek apakah pengguna sudah login
    if 'username' not in session:
        flash("Silahkan login terlebih dahulu", "error")
        return redirect('/login')
    
    active_user = session['username']
    db = get_db()
    cursor = db.cursor()
    # Mengambil data session berdasarkan operator yang login
    cursor.execute(
        "SELECT * FROM user_sessions WHERE operator = ? ORDER BY created_at DESC", 
        (active_user,)
    )
    sessions_data = cursor.fetchall()
    return render_template('riwayat.html', sessions=sessions_data)

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# TAMBAH DAN HAPUS SERVER
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

# Lokasi file server.json (di folder yang sama dengan script)
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVER_FILE = os.path.join(CURRENT_DIR, "server.json")

def load_servers():
    """Load servers from the JSON file."""
    if os.path.exists(SERVER_FILE):
        with open(SERVER_FILE, "r") as file:
            return json.load(file)
    return []

def save_servers(servers):
    """Save servers to the JSON file."""
    with open(SERVER_FILE, "w") as file:
        json.dump(servers, file, indent=4)

@app.route('/add_server_temp')
def add_server_temp():
    """Halaman Form untuk menambah server."""
    return render_template('add_server.html')

@app.route('/add_server', methods=['POST'])
def add_server():
    try:
        # Ambil data dari form
        name = request.form['name']
        hostname = request.form['hostname']
        username = request.form['username']
        password = request.form['password']

        # Validasi input (contoh: semua field harus diisi)
        if not all([name, hostname, username, password]):
            flash("Semua field harus diisi!", "error")
            return redirect(url_for('home'))

        # Buat data server baru
        new_server = {
            "name": name,
            "hostname": hostname,
            "username": username,
            "password": password
        }

        # Load server list dan tambahkan server baru
        servers = load_servers()
        servers.append(new_server)
        save_servers(servers)

        flash("Server berhasil ditambahkan!", "success")
        return redirect(url_for('add_server_temp'))

    except Exception as e:
        flash(f"Terjadi kesalahan: {e}", "error")
        return redirect(url_for('add_server_temp'))

@app.route('/delete_server', methods=['GET', 'POST'])
def delete_server():
    if request.method == 'GET':
        # Menampilkan daftar server
        servers = load_servers()
        return render_template('delete_server.html', servers=servers)

    elif request.method == 'POST':
        # Menghapus server berdasarkan nama
        name_to_delete = request.form['name']
        servers = load_servers()
        updated_servers = [server for server in servers if server['name'] != name_to_delete]

        if len(servers) == len(updated_servers):
            flash(f"Server dengan nama '{name_to_delete}' tidak ditemukan!", "error")
        else:
            save_servers(updated_servers)
            flash(f"Server '{name_to_delete}' berhasil dihapus!", "success")
        
        return redirect(url_for('delete_server'))


# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# STATUS SERVER
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

#Fungsi untuk memeriksa status VPS (ping)
def check_vps_status(hostname):
    try:
        # Perintah ping ke setiap VPS
        result = subprocess.run(
            ["ping", "-c", "1", hostname],  # Ganti dengan IP/hostname VPS
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        if result.returncode == 0:
            # Ambil latensi dari hasil ping
            for line in result.stdout.split("\n"):
                if "time=" in line:
                    latency = line.split("time=")[1].split(" ")[0]
                    # Ubah latensi ke milidetik (ms)
                    latency_ms = int(float(latency) * 500)
                    return {"status": "ON", "latency": f"{latency_ms} ms"}
        return {"status": "OFF", "latency": "-"}
    except Exception as e:
        return {"status": "OFF", "latency": "-"}

# Fungsi untuk mendapatkan jumlah pengguna (current) melalui SSH
def get_current_users(hostname, username, password):
    try:
        # Setup SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())  # Menerima host key yang tidak dikenal
        
        # Connect to the server
        ssh.connect(hostname, username=username, password=password)

        # Jalankan script user.sh dan ambil outputnya
        stdin, stdout, stderr = ssh.exec_command("user.sh")
        output = stdout.read().decode().strip()  # Ambil hasil output
        
        ssh.close()
        
        # Kembalikan jumlah user yang sedang aktif (current) sebagai integer
        return int(output)
    except Exception as e:
        print(f"Error: {e}")
        return None  # Jika gagal, kembalikan None

# Route untuk halaman utama
@app.route("/status_server")
def status_server():
    return render_template("status_server.html")

# Route untuk mendapatkan status VPS dan informasi lainnya
@app.route("/status", methods=["GET"])
def get_status():
    # Membaca data dari file JSON
    with open('server.json') as f:
        vps_list = json.load(f)
    
    # Set max_user
    max_user = 25

    # Memeriksa status masing-masing VPS
    for vps in vps_list:
        vps_status = check_vps_status(vps["hostname"])
        vps["status"] = vps_status["status"]
        vps["latency"] = vps_status["latency"]
        
        # Ambil current user menggunakan paramiko
        current_users = get_current_users(vps["hostname"], vps["username"], vps["password"])  # Pastikan menambahkan username dan password di server.json
        vps["current_users"] = current_users if current_users is not None else 0
        vps["max_user"] = max_user
    
    return jsonify(vps_list)

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# REQUEST DEPOSIT. NOTIF KE BOT ADMIN TELE
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# Konfigurasi bot Telegram
TELEGRAM_BOT_TOKEN = '$tele'
TELEGRAM_CHAT_ID = '$idtele'
bot = telebot.TeleBot(TELEGRAM_BOT_TOKEN, parse_mode=None)

@app.route('/deposit', methods=['GET', 'POST'])
def deposit():
    if request.method == 'POST':
        username = request.form['username']
        amount = request.form['amount']
        return render_template('payment_confirmation.html', username=username, amount=amount)
    return render_template('deposit_form.html')

@app.route('/confirm', methods=['POST'])
def confirm():
    username = request.form['username']
    amount = request.form['amount']
    proof = request.files['proof']

    if proof:
        proof_path = os.path.join('static', proof.filename)
        proof.save(proof_path)

        # Kirim pesan ke bot Telegram
        message = f"Permintaan Deposit.\nUsername: {username}\nJumlah: {amount}"
        with open(proof_path, 'rb') as photo:
            bot.send_message(chat_id=TELEGRAM_CHAT_ID, text=message)
            bot.send_photo(chat_id=TELEGRAM_CHAT_ID, photo=photo)

        flash('Permintaan deposit telah berhasil dikirim ke admin.', 'success')
        return redirect(url_for('deposit'))
    else:
        flash('Harap unggah bukti transfer.', 'danger')
        return redirect(url_for('deposit'))

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# RESTORE DATABASE WEB
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
@app.route('/restore', methods=['GET', 'POST'])
def restore():
    message = None
    status = None

    if request.method == 'POST':
        if 'file' not in request.files:
            message = "No file part"
            status = "error"
        else:
            file = request.files['file']
            if file.filename == '':
                message = "No selected file"
                status = "error"
            elif file and file.filename.endswith('.zip'):
                # Simpan file zip sementara
                zip_path = os.path.join(os.getcwd(), 'temp_restore.zip')
                file.save(zip_path)

                try:
                    # Ekstrak file zip
                    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                        zip_ref.extractall(os.getcwd())

                    # Hapus file zip sementara
                    os.remove(zip_path)

                    message = "Restore berhasil!"
                    status = "success"
                except Exception as e:
                    message = f"Error saat ekstraksi: {e}"
                    status = "error"
            else:
                message = "File harus berupa .zip"
                status = "error"

    return render_template('restore.html', message=message, status=status)
    
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# RENEW ACCOUNT 
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# KELUAR SESI ATAU LOGOUT
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════

@app.route("/logout")
def logout():
    session.pop("username", None)
    flash("Anda telah logout.", "info")
    return redirect("/login")


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=$PORT)
EOL

cd templates

cat <<EOL > /root/$identity/run.sh
#!/bin/bash
source /root/$identity/web/bin/activate
python /root/$identity/app.py
EOL

#Home
wget -q ${LINK}/templates/Home/login.html
wget -q ${LINK}/templates/Home/register.html
wget -q ${LINK}/templates/Home/dash_admin.html
wget -q ${LINK}/templates/Home/dash_guest.html
wget -q ${LINK}/templates/Home/home.html

#Server
wget -q ${LINK}templates/server/add_server.html
wget -q ${LINK}templates/server/delete_server.html
wget -q ${LINK}templates/server/status_server.html

#Users
wget -q ${LINK}templates/users/tambah_saldo_user.html
wget -q ${LINK}templates/users/kurangi_saldo_user.html
wget -q ${LINK}templates/users/list_user.html

#Vpn
wget -q ${LINK}templates/Vpn/create.html
wget -q ${LINK}templates/Vpn/result.html
wget -q ${LINK}templates/Vpn/riwayat.html

#Deposit
wget -q ${LINK}templates/deposit/deposit_form.html
wget -q ${LINK}templates/deposit/payment_confirmation.html

cd
cd /root/$identity
python3 -m venv web
source web/bin/activate

pip install flask
pip install requests
pip install paramiko
pip install pyTelegramBotAPI
deactivate

#══════════════════════════════
#Buat System Service
cd
cat <<EOL > /etc/systemd/system/$identity.service
[Unit]
Description=Run $identity script
After=network.target

[Service]
ExecStart=/bin/bash /root/$identity/run.sh
WorkingDirectory=/root/$identity
User=root
Group=root
Restart=always
StandardOutput=journal
StandardError=journal
RestartSec=5

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd dan aktifkan service
systemctl daemon-reload
systemctl enable $identity.service

# Menjalankan service
systemctl start $identity.service


# Setup Script Backup
cat <<EOL > /root/$identity/backup.py
import os
import zipfile
import telebot
from datetime import datetime

# Konfigurasi bot Telegram
BOT_TOKEN = '$tele'
CHAT_ID = '$idtele'

# Inisialisasi bot Telegram
bot = telebot.TeleBot(BOT_TOKEN)

def backup_and_send_to_telegram():
    try:
        # Nama file backup
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        zip_filename = f"backup_{timestamp}.zip"

        # File yang akan di-backup
        files_to_backup = ['database.db', 'server.json']

        # Membuat file zip
        with zipfile.ZipFile(zip_filename, 'w') as zipf:
            for file in files_to_backup:
                if os.path.exists(file):
                    zipf.write(file)
                else:
                    print(f"File {file} tidak ditemukan.")

        # Mengirim file zip ke bot Telegram
        with open(zip_filename, 'rb') as zip_file:
            bot.send_document(CHAT_ID, zip_file)

        print(f"Backup berhasil dikirim ke Telegram: {zip_filename}")

        # Hapus file zip setelah dikirim
        os.remove(zip_filename)

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    backup_and_send_to_telegram()
EOL

#Buat Run Backup
cat <<EOL > /root/$identity/run_backup.sh
#!/bin/bash
source /root/$identity/web/bin/activate
python /root/$identity/backup.py
EOL

#Buat System Service Backup 
cat <<EOL > /etc/systemd/system/${identity}_backup.service
[Unit]
Description=Run Backup Script
After=network.target

[Service]
Type=oneshot
ExecStart=/root/${identity}/run_backup.sh
User=root
Group=root
EOL

#Buat Timer
cat <<EOL > /etc/systemd/system/${identity}_backup.timer
[Unit]
Description=Run Backup Script Every 3 Hours

[Timer]
OnCalendar=*-*-* 00/3:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOL

#Restar Layanan
sudo systemctl daemon-reload
sudo systemctl enable ${identity}_backup.timer
sudo systemctl start ${identity}_backup.timer

#Pasang Domain Dan SSL

# Pastikan script dijalankan dengan akses root
if [ "$(id -u)" -ne 0 ]; then
    echo "Script ini harus dijalankan dengan akses root."
    exit 1
fi


# Lokasi file konfigurasi Nginx
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

# Membuat file konfigurasi Nginx
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://$FLASK_IP:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "File konfigurasi telah dibuat: $NGINX_CONF"

# Membuat symbolic link ke sites-enabled jika belum ada
if [ ! -L "/etc/nginx/sites-enabled/$DOMAIN" ]; then
    ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/
    echo "Symbolic link dibuat: /etc/nginx/sites-enabled/$DOMAIN"
fi

# Uji konfigurasi Nginx
nginx -t
if [ $? -eq 0 ]; then
    # Reload Nginx
    systemctl reload nginx
    echo "Nginx berhasil di-reload dan konfigurasi telah aktif."
else
    echo "Terdapat kesalahan dalam konfigurasi Nginx. Silahkan periksa kembali file $NGINX_CONF."
fi

#pasang SSL
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d $DOMAIN

#Kembali Ke Root dan Hapus File Setup
cd
rm -r setup.sh



