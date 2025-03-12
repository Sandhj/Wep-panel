LINK="https://raw.githubusercontent.com/Sandhj/Wep-panel/main/"

mkdir -p /root/web/templates
cd web
wget -q ${LINK}app.py

cd templates
#Home
wget -q ${LINK}Home/login.html
wget -q ${LINK}Home/register.html
wget -q ${LINK}Home/dash_admin.html
wget -q ${LINK}Home/dash_guest.html

#Server
wget -q ${LINK}add_server.html
wget -q ${LINK}delete_server.html
wget -q ${LINK}status_server.html

#Users
wget -q ${LINK}add_balance.html
wget -q ${LINK}kurangi_saldo.html
wget -q ${LINK}users.html

#Vpn
wget -q ${LINK}create_ssh.html
wget -q ${LINK}create_vmess.html
wget -q ${LINK}create_vless.html
wget -q ${LINK}create_trojan.html
wget -q ${LINK}delete_account.html
wget -q ${LINK}result.html
wget -q ${LINK}riwayat.html
