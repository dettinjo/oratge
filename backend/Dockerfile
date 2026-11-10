FROM python:3.12-slim
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY oratge ./oratge
ENV ORATGE_DB=/data/oratge.db
RUN mkdir -p /data && useradd -r -u 10001 oratge && chown oratge /data
USER oratge
VOLUME /data
EXPOSE 8000
HEALTHCHECK --interval=60s --timeout=5s CMD python -c "import urllib.request;urllib.request.urlopen('http://127.0.0.1:8000/health')"
CMD ["uvicorn", "oratge.api:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
