from flask import Flask, render_template, request, redirect, session, g, flash, url_for, jsonify, flash
import sqlite3
import os
import paramiko
import subprocess
import json
import shutil
import urllib.parse
import telebot
import zipfile

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
        if session["username"] == "mastersandi":
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
            if username == "mastersandi":
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
    if "username" not in session or session["username"] == "mastersandi":
        return redirect("/login")
    username = session["username"]
    db = get_db()
    user = db.execute("SELECT balance FROM users WHERE username = ?", (username,)).fetchone()
    balance = user["balance"] if user else 0
    return render_template("dash_guest.html", username=username, balance=balance)

@app.route("/admin")
def admin_dashboard():
    if "username" not in session or session["username"] != "mastersandi":
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
        name = request.form.get('name')
        hostname = request.form.get('hostname')
        username = request.form.get('username')
        password = request.form.get('password')
        limit = request.form.get('limit')  # Ambil nilai limit dari form

        # Validasi input (contoh: semua field harus diisi)
        if not all([name, hostname, username, password, limit]):
            flash("Semua field harus diisi!", "error")
            return redirect(url_for('add_server_temp'))

        # Validasi format limit (misalnya, harus berupa angka integer)
        if not limit.isdigit():
            flash("Field 'Limit' harus berupa angka bulat!", "error")
            return redirect(url_for('add_server_temp'))

        # Buat data server baru
        new_server = {
            "name": name,
            "hostname": hostname,
            "username": username,
            "password": password,  # Perhatikan: Password sebaiknya dienkripsi
            "limit": int(limit)  # Konversi limit ke integer
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

# Lokasi file server.json (di folder yang sama dengan script)
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
SERVER_FILE = os.path.join(CURRENT_DIR, "server.json")

# Fungsi untuk memeriksa status VPS (ping)
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

# Fungsi untuk mendapatkan jumlah pengguna aktif dari VPS menggunakan SSH
def get_current_users(hostname, username, password):
    try:
        # Setup SSH client
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())  # Menerima host key yang tidak dikenal
        
        # Connect to the server
        ssh.connect(hostname, username=username, password=password)

        # Jalankan perintah untuk membaca file konfigurasi dan menghitung jumlah pengguna
        config_file = "/etc/xray/config.json"
        commands = [
            f"grep -c -E '^#& ' {config_file}",  # Menghitung vlx
            f"grep -c -E '^### ' {config_file}",  # Menghitung vmc
            f"grep -c -E '^#! ' {config_file}",  # Menghitung trx
            f"grep -c -E '^#ss# ' {config_file}",  # Menghitung ssx
            "awk -F: '$3 >= 1000 && $1 != \"nobody\" {print $1}' /etc/passwd | wc -l"  # Menghitung ssh1
        ]

        # Eksekusi semua perintah dan ambil hasilnya
        results = []
        for cmd in commands:
            stdin, stdout, stderr = ssh.exec_command(cmd)
            output = stdout.read().decode().strip()
            results.append(int(output) if output.isdigit() else 0)

        # Hitung total pengguna berdasarkan hasil
        vlx, vmc, trx, ssx, ssh1 = results
        vla = vlx // 2
        vma = vmc // 2
        trb = trx // 2
        ssa = ssx // 2
        total = vla + vma + trb + ssh1

        ssh.close()
        return total
    except Exception as e:
        print(f"Error: {e}")
        return 0  # Jika gagal, kembalikan 0

# Route untuk halaman utama
@app.route("/status_server")
def status_server():
    return render_template("status_server.html")

# Route untuk mendapatkan status VPS dan informasi lainnya
@app.route("/status", methods=["GET"])
def get_status():
    # Membaca data dari file JSON
    with open(SERVER_FILE, "r") as f:
        vps_list = json.load(f)
    
    # Memeriksa status masing-masing VPS
    for vps in vps_list:
        # Periksa status VPS (ping)
        vps_status = check_vps_status(vps["hostname"])
        vps["status"] = vps_status["status"]
        vps["latency"] = vps_status["latency"]
        
        # Ambil max_user dari field "limit" di JSON
        vps["max_user"] = vps.get("limit", 25)  # Default ke 25 jika "limit" tidak ada
        
        # Ambil current user menggunakan paramiko
        current_users = get_current_users(vps["hostname"], vps["username"], vps["password"])
        vps["current_users"] = current_users
    
    return jsonify(vps_list)

# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# REQUEST DEPOSIT. NOTIF KE BOT ADMIN TELE
# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════


# ══════════════════════════════⊹⊱≼≽⊰⊹══════════════════════════════
# RESTORE DATA WEB
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
    app.run(host="0.0.0.0", port=5007)
