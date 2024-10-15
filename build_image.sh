#!/bin/bash

# Ensure required variables are passed
if [ -z "$IMAGE_NAME" ] || [ -z "$GIT_REPO_URL" ] || [ -z "$SERVER_URL" ] || [ -z "$IMAGE_TAG" ] || [ -z "$DOCKERHUB_USERNAME" ] || [ -z "$IMAGE_STATUS_ID" ]; then
  echo "Error: Missing required environment variables."
  exit 1
fi

echo "Image name: $IMAGE_NAME"
echo "Github repo url: $GIT_REPO_URL"
echo "Server url: $SERVER_URL"
echo "Image tag: $IMAGE_TAG"
echo "Dockerhub username: $DOCKERHUB_USERNAME"
echo "Image status id: $IMAGE_STATUS_ID"

# Create a Dockerfile dynamically
cat <<EOF > Dockerfile
FROM python:3.7
RUN python3 -m pip install --no-cache-dir keras
RUN git clone $GIT_REPO_URL /dir || { echo "Failed to clone GitHub repository." && exit 1; }
ENTRYPOINT ["python3", "/dir/pipelines/component/src/program.py"]
EOF


# Build, tag, and push Docker image
echo "Building and pushing Docker image..."
sudo docker build --push \
  --tag "$DOCKERHUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG" .

# Check if the build was successful
if [ $? -eq 0 ]; then
  echo "Docker image pushed successfully: $DOCKERHUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG"
  
  # If successful, make API call with status "COMPLETED"
  curl --location --globoff --request POST "$SERVER_URL/v1.0/ml/brick/image/$IMAGE_STATUS_ID?status=COMPLETED" \
  --data ''
  echo "Status update: COMPLETED"

  # Remove the local Docker image
  echo "Removing local Docker image..."
  sudo docker rmi "$DOCKERHUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG"

else
  echo "Docker image build and push failed."

  # If failed, make API call with status "FAILED"
  curl --location --globoff --request POST "$SERVER_URL/v1.0/ml/brick/image/$IMAGE_STATUS_ID?status=FAILED" \
  --data ''
  echo "Status update: FAILED"
fi

# Clean up the temporary Dockerfile
rm -f Dockerfile
