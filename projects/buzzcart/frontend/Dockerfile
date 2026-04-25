# Frontend Dockerfile - Flutter Web Multi-stage Build
FROM debian:stable-slim AS build

# Install Flutter dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter
ENV PATH="/flutter/bin:${PATH}"

WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build for web
RUN flutter build web --release

# Production stage with nginx
FROM nginx:alpine

# Copy the built web files
COPY --from=build /app/build/web /usr/share/nginx/html

# Create nginx config
RUN echo 'server { listen 80; root /usr/share/nginx/html; location / { try_files $uri $uri/ /index.html; } }' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
