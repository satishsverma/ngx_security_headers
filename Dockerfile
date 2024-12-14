FROM debian:bullseye as builder

# Install necessary packages for building Nginx
RUN apt-get update && apt-get install -y \
    build-essential \
    libpcre3 \
    libpcre3-dev \
    zlib1g \
    zlib1g-dev \
    libssl-dev \
    wget \
    git \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV NGINX_VERSION=1.25.2 \
    NGX_SECURITY_HEADERS_REPO=https://github.com/GetPageSpeed/ngx_security_headers.git

# Download and extract Nginx source code
WORKDIR /usr/src/nginx
RUN wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && \
    tar -xzf nginx-$NGINX_VERSION.tar.gz && \
    rm nginx-$NGINX_VERSION.tar.gz

# Clone the ngx_security_headers module
RUN git clone $NGX_SECURITY_HEADERS_REPO /usr/src/ngx_security_headers

# Build Nginx with the ngx_security_headers module
WORKDIR /usr/src/nginx/nginx-$NGINX_VERSION
RUN ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_auth_request_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_realip_module \
    --with-stream_ssl_preread_module \
    --with-threads \
    --with-file-aio \
    --add-module=/usr/src/ngx_security_headers && \
    make && \
    make install

# Ensure directories exist
RUN mkdir -p /usr/lib/nginx/modules /var/cache/nginx

# Create a minimal runtime image for Nginx
FROM debian:bullseye-slim

# Install required runtime dependencies
RUN apt-get update && apt-get install -y \
    libpcre3 \
    zlib1g \
    openssl && \
    rm -rf /var/lib/apt/lists/*

# Copy built Nginx from the builder stage
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/lib/nginx /usr/lib/nginx
COPY --from=builder /var/cache/nginx /var/cache/nginx
COPY --from=builder /usr/src/ngx_security_headers /usr/src/ngx_security_headers

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
