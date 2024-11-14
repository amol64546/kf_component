FROM python:3.7
RUN python3 -m pip install --no-cache-dir keras
RUN git clone $GIT_REPO_URL /dir || { echo "Failed to clone GitHub repository." && exit 1; }
ENTRYPOINT ["python3", "/dir$PATH"]
