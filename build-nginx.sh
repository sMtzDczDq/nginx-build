#!/usr/bin/env bash
# Run as root or with sudo
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root or with sudo."
	exit 1
fi

# Make script exit if a simple command fails and
# Make script print commands being executed
set -e -x

# Ensure curl is installed
apt-get update && apt-get install curl jq -y

GH_API_HEADER="X-GitHub-Api-Version:2026-03-10"

# Set URLs to the source directories
REPO_PCRE="PCRE2Project/pcre2"
PCRE_TAR=$(
	curl --silent -H "Accept: application/vnd.github+json" -H "$GH_API_HEADER" --url https://api.github.com/repos/"$REPO_PCRE"/releases/latest --output - | jq -r '.assets[]|select(.content_type == "application/x-gzip")|.browser_download_url'
)
#source_pcre=https://onboardcloud.dl.sourceforge.net/project/pcre/pcre/8.45/
source_zlib=https://zlib.net/
source_openssl=https://www.openssl.org/source/
source_nginx=https://nginx.org/download/

# Look up latest versions of each package
version_pcre=$(echo "$PCRE_TAR" | awk -F '/' '{print $(NF-1)}')
version_zlib=$(curl -sL ${source_zlib} | grep -Eo 'zlib\-[0-9.]+[0-9]' | sort -V | tail -n 1)
version_openssl=$(curl -sL ${source_openssl} | grep -Po 'openssl\-[0-9]+\.[0-9]+\.[0-9]+[a-z]?(?=\.tar\.gz)' | sort -V | tail -n 1)
version_nginx=$(curl -sL ${source_nginx} | grep -Eo 'nginx\-[0-9.]+[13579]\.[0-9]+' | sort -V | tail -n 1)

# Set OpenPGP keys used to sign downloads
opgp_pcre=A95536204A3BB489715231282A98E77EB6F24CA8
opgp_zlib=5ED46A6721D365587791E2AA783FCD8E58BCAFBA
opgp_openssl_1=8657ABB260F056B1E5190839D9C4D26D0E604491 #Matt Caswell
opgp_openssl_2=B7C1C14360F353A36862E4D5231C84CDDCC69C45 #Paul Dale
opgp_openssl_3=7953AC1FBC3DC8B3B292393ED5E9E43F7DF9EE8C #Richaard Levitte
opgp_openssl_4=A21FAB74B0088AA361152586B8EF1A6BA9DA2D5C #Tomas Mrax
opgp_openssl_5=EFC0A467D613CB83C7ED6D30D894E2CE8B3D79F5 #OpenSSL OMC
opgp_openssl_6=BA5473A2B0587B07FB27CF2D216094DFD0CB81EF
opgp_nginx_1=13C82A63B603576156E30A4EA0EA981B66B0D967
opgp_nginx_2=D6786CE303D9A9022998DC6CC8464D549AF75C0A
opgp_nginx_3=43387825DDB1BB97EC36BA5D007C8D7C15D87369
opgp_nginx_4=8540A6F18833A80E9C1653A42FD21310B49F6B46
opgp_nginx_5=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62
opgp_nginx_6=9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3

# Set where OpenSSL and NGINX will be built
bpath=$(pwd)/build

# Make a "today" variable for use in back-up filenames later
today=$(date +"%Y-%m-%d")

# Clean out any files from previous runs of this script
rm -rf \
	"$bpath" \
	/etc/nginx-default
mkdir "$bpath"

# Ensure the required software to compile NGINX is installed
apt-get -y install \
	binutils \
	build-essential \
	curl \
	dirmngr \
	libssl-dev

# Download the source files
#curl -L "${source_pcre}${version_pcre}.tar.gz" -o "${bpath}/pcre.tar.gz"
curl -L "$PCRE_TAR" -o "${bpath}/pcre.tar.gz"
curl -L "${source_zlib}${version_zlib}.tar.gz" -o "${bpath}/zlib.tar.gz"
curl -L "${source_openssl}${version_openssl}.tar.gz" -o "${bpath}/openssl.tar.gz"
curl -L "${source_nginx}${version_nginx}.tar.gz" -o "${bpath}/nginx.tar.gz"

# Download the signature files
#curl -L "${source_pcre}${version_pcre}.tar.gz.sig" -o "${bpath}/pcre.tar.gz.sig"
curl -L "$PCRE_TAR".sig -o "${bpath}/pcre.tar.gz.sig"
curl -L "${source_zlib}${version_zlib}.tar.gz.asc" -o "${bpath}/zlib.tar.gz.asc"
curl -L "${source_openssl}${version_openssl}.tar.gz.asc" -o "${bpath}/openssl.tar.gz.asc"
curl -L "${source_nginx}${version_nginx}.tar.gz.asc" -o "${bpath}/nginx.tar.gz.asc"
#curl -L "https://github.com/maxmind/libmaxminddb/releases/download/1.11.0/libmaxminddb-1.11.0.tar.gz" -o libmaxminddb.tar.gz
# Verify the integrity and authenticity of the source files through their OpenPGP signature
cd "$bpath"
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME
gpg --keyserver keyserver.ubuntu.com --recv-keys "$opgp_pcre" "$opgp_zlib" "$opgp_openssl_1" "$opgp_openssl_2" "$opgp_openssl_3" "$opgp_openssl_4" "$opgp_openssl_5" "$opgp_openssl_6" "$opgp_nginx_1" "$opgp_nginx_2" "$opgp_nginx_3" "$opgp_nginx_4" "$opgp_nginx_5" "$opgp_nginx_6"
gpg --batch --verify pcre.tar.gz.sig pcre.tar.gz
gpg --batch --verify zlib.tar.gz.asc zlib.tar.gz
gpg --batch --verify openssl.tar.gz.asc openssl.tar.gz
gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz

# Expand the source files
cd "$bpath"
for archive in ./*.tar.gz; do
	tar xzf "$archive"
done

# Clean up source files
rm -rf \
	"$GNUPGHOME" \
	"$bpath"/*.tar.*

# Rename the existing /etc/nginx directory so it's saved as a back-up
if [ -d "/etc/nginx" ]; then
	mv /etc/nginx "/etc/nginx-${today}"
fi

# Create NGINX cache directories if they do not already exist
if [ ! -d "/var/lib/nginx/" ]; then
	mkdir -p \
		/var/lib/nginx/client \
		/var/lib/nginx/proxy \
		/var/lib/nginx/fastcgi \
		/var/lib/nginx/uwsgi \
		/var/lib/nginx/scgi
fi

# Add NGINX group and user if they do not already exist
id -g nginx &>/dev/null || addgroup --system nginx
id -u nginx &>/dev/null || adduser --disabled-password --system --home /var/lib/nginx --shell /sbin/nologin --group nginx

# Test to see if our version of gcc supports __SIZEOF_INT128__
if gcc -dM -E - </dev/null | grep -q __SIZEOF_INT128__; then
	ecflag="enable-ec_nistp_64_gcc_128"
else
	ecflag=""
fi

# Build NGINX, with various modules included/excluded
cd "$bpath/$version_nginx"
./configure \
	--conf-path=/etc/nginx/nginx.conf \
	--error-log-path=stderr \
	--http-client-body-temp-path=/var/lib/nginx/body \
	--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
	--http-log-path=/var/log/nginx/access.log \
	--http-proxy-temp-path=/var/lib/nginx/proxy \
	--http-scgi-temp-path=/var/lib/nginx/scgi \
	--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
	--lock-path=/var/lock/nginx.lock \
	--modules-path=/usr/lib/nginx/modules \
	--pid-path=/run/nginx.pid \
	--prefix=/usr/share/nginx \
	--sbin-path=/usr/sbin/nginx \
	--with-cc-opt="-g -O2 -Werror=implicit-function-declaration -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -fPIC -Wdate-time -D_FORTIFY_SOURCE=2" \
	--with-compat \
	--with-debug \
	--with-file-aio \
	--with-http_addition_module \
	--with-http_auth_request_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_geoip_module=dynamic \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_image_filter_module=dynamic \
	--with-http_mp4_module \
	--with-http_perl_module=dynamic \
	--with-http_random_index_module \
	--with-http_realip_module \
	--with-http_secure_link_module \
	--with-http_slice_module \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_sub_module \
	--with-http_v2_module \
	--with-http_v3_module \
	--with-http_xslt_module=dynamic \
	--with-ld-opt='-Wl,-z,relro -Wl,-z,now -fPIC' \
	--with-mail_ssl_module \
	--with-mail=dynamic \
	--with-openssl-opt="no-weak-ssl-ciphers no-ssl3 no-shared $ecflag -DOPENSSL_NO_HEARTBEATS -fstack-protector-strong" \
	--with-openssl="$bpath/$version_openssl" \
	--with-pcre-jit \
	--with-pcre="$bpath/$version_pcre" \
	--with-stream \
	--with-stream_geoip_module=dynamic \
	--with-stream_realip_module \
	--with-stream_ssl_module \
	--with-stream_ssl_preread_module \
	--with-stream=dynamic \
	--with-threads \
	--with-zlib="$bpath/$version_zlib" \
	--without-http_empty_gif_module \
	--without-http_split_clients_module \
	--without-http_ssi_module \
	--without-mail_imap_module \
	--without-mail_pop3_module \
	--without-mail_smtp_module

make -j"$(nproc)"
make install
make clean
strip -s /usr/sbin/nginx*

if [ -d "/etc/nginx-${today}" ]; then
	# Rename the default /etc/nginx settings directory so it's accessible as a reference to the new NGINX defaults
	mv /etc/nginx /etc/nginx-default

	# Restore the previous version of /etc/nginx to /etc/nginx so the old settings are kept
	mv "/etc/nginx-${today}" /etc/nginx
fi

# Create NGINX systemd service file if it does not already exist
if [ ! -e "/lib/systemd/system/nginx.service" ]; then
	# Control will enter here if the NGINX service doesn't exist.
	file="/lib/systemd/system/nginx.service"

	/bin/cat >$file <<'EOF'
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
fi

echo "All done."
echo "Start with sudo systemctl start nginx"
echo "or with sudo nginx"
