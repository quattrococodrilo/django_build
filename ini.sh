#!/bin/bash

python_ver="python3.8"
python_path=./env/bin
python=./env/bin/python
pip=./env/bin/pip
compose="compose"
requirements="$compose/requirements"
environ="$compose/environ"
dev="$compose/dev"
prod="$compose/prod"

if [ ! -d compose ]; then
    mkdir -p $requirements
    mkdir $environ
    mkdir $dev
    mkdir $prod
fi

# VIRTUALENV

if [ ! -d env ]; then
    virtualenv env --python=$python_ver
fi

# REQUIREMENTS

cat >$requirements/base.txt <<EOF
django<3
pillow
celery
whitenoise
EOF

cat >$requirements/env_dev.txt <<EOF
# Dependences for virtual environment
-r base.txt
psycopg2-binary
ipython
EOF

cat >$requirements/local.txt <<EOF
-r base.txt
psycopg2
ipython
EOF

# ENVIRON FILES

cat >$environ/django.env <<EOF

EOF

cat >$environ/postgres.env <<EOF
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
EOF

# ENTRYPOINT

cat >$dev/entrypoint.sh <<"EOF"
postgres_ready() {
python << END
import sys
import psycopg2
try:
    psycopg2.connect(
        dbname="${POSTGRES_DB}",
        user="${POSTGRES_USER}",
        password="${POSTGRES_PASSWORD}",
        host="${POSTGRES_HOST}",
        port="${POSTGRES_PORT}",
    )
except psycopg2.OperationalError:
    sys.exit(-1)
sys.exit(0)
END
}
until postgres_ready; do
  >&2 echo 'Waiting for PostgreSQL to become available...'
  sleep 1
done
>&2 echo 'PostgreSQL is available'

exec "$@"
EOF

# DOKER

cat >$dev/Dockerfile <<EOF
FROM python:3
ENV PYTHONUNBUFFERED 1
RUN mkdir /django
WORKDIR /django
COPY ./compose/requirements/base.txt .
COPY ./compose/requirements/local.txt .
RUN pip install -r local.txt
COPY ./project .
WORKDIR ./project
EOF

cat >docker-compose.yml <<EOF
version: '3.7'
services:
    db:
        image: postgres
        env_file:
            - $environ/postgres.env
    web:
        build:
            context: .
            dockerfile: $dev/Dockerfile
        volumes:
            - ./project:/django/project
        ports:
            - "8000:8000"
        env_file:
            - $environ/django.env
            - $environ/postgres.env
        depends_on:
            - db
        command: python /project
EOF

# PYTHON REQUIREMENTS

$pip install -r $requirements/env_dev.txt

# DJANGO

if [ ! -d project ]; then
    $python_path/django-admin startproject project
fi
