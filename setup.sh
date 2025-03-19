LINK="https://raw.githubusercontent.com/Sandhj/Wep-panel/main/"

mkdir -p /root/web/templates
cd web
wget -q ${LINK}app.py

cd templates
#Home
wget -q ${LINK}/templates/Home/login.html
wget -q ${LINK}/templates/Home/register.html
wget -q ${LINK}/templates/Home/dash_admin.html
wget -q ${LINK}/templates/Home/dash_guest.html

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
