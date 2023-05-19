
ARG VERSION

FROM public.ecr.aws/lambda/python:$VERSION AS base

RUN yum install -y amazon-linux-extras \
  && (export PYTHON=python2 && amazon-linux-extras install epel -y) \
  && yum install -y \
    boost-devel \
    jemalloc-devel \
    bison \
    make \
    gcc \
    gcc-c++ \
    flex \
    autoconf \
    zip \
    git \
    ninja-build \
  && yum clean all \
  && rm -rf /var/cache/yum


WORKDIR /root

RUN pip3 install --no-cache-dir --upgrade pip wheel \
  && pip3 install --no-cache-dir --upgrade six cython cmake hypothesis poetry


ADD https://raw.githubusercontent.com/aws/aws-sdk-pandas/main/pyproject.toml ./
ADD https://raw.githubusercontent.com/aws/aws-sdk-pandas/main/poetry.lock ./

RUN poetry config virtualenvs.create false --local \
  && poetry install --no-root --no-cache --no-dev

RUN yum install -y tar ccache \
  && yum clean all \
  && rm -rf /var/cache/yum


ENTRYPOINT ["/bin/sh"]
