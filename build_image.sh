#!/bin/bash

# Ensure required variables are passed
if [ -z "$IMAGE_NANE" ] || [ -z "$PYTHON_SCRIPT" ] || [ -z "$IMAGE_TAG" ] || [ -z "$DOCKERHUB_USERNAME" ] || [ -z "$DOCKERHUB_TOKEN" ] || [ -z "$IMAGE_STATUS_ID" ]; then
  echo "Error: Missing required environment variables."
  exit 1
fi

# Create a Dockerfile dynamically
cat <<EOF > Dockerfile
FROM python:3.7
RUN python3 -m pip install --no-cache-dir keras
COPY ./program.py /pipelines/component/src/program.py
ENTRYPOINT ["python3", "/pipelines/component/src/program.py"]
EOF

echo "Fetching Python script from $PYTHON_SCRIPT..."
curl -o ./program.py "$PYTHON_SCRIPT"

if [ $? -ne 0 ]; then
  echo "Failed to download Python script."
  exit 1
fi

# Set up Docker Buildx (if not already available, this step assumes buildx is available)
echo "Setting up Docker Buildx..."
docker buildx version || docker buildx create --use

# Log in to Docker Hub
echo "Logging in to Docker Hub..."
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
if [ $? -ne 0 ]; then
  echo "Docker login failed."
  exit 1
fi

# Build, tag, and push Docker image
echo "Building and pushing Docker image..."
docker buildx build --push \
  --tag "$DOCKERHUB_USERNAME/$IMAGE_NANE:$IMAGE_TAG" .

# Check if the build was successful
if [ $? -eq 0 ]; then
  echo "Docker image pushed successfully: $DOCKERHUB_USERNAME/$IMAGE_NANE:$IMAGE_TAG"
  
  # If successful, make API call with status "COMPLETED"
  curl --location --globoff --request POST "https://ig.aidtaas.com/bob-service/v1.0/ml/brick/image/$IMAGE_STATUS_ID?status=COMPLETED" \
  --data ''
  echo "Status update: COMPLETED"
else
  echo "Docker image build and push failed."

  # If failed, make API call with status "FAILED"
  curl --location --globoff --request POST "https://ig.aidtaas.com/bob-service/v1.0/ml/brick/image/$IMAGE_STATUS_ID?status=FAILED" \
  --data ''
  echo "Status update: FAILED"
fi

# Clean up the temporary Dockerfile
rm -f Dockerfile
