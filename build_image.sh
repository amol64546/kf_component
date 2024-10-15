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
  
  # Make the API call
  response=$(curl --location --globoff --request POST "$SERVER_URL/v1.0/ml/brick/image/$IMAGE_STATUS_ID?status=COMPLETED" \
    --data '' --write-out "%{http_code}" --silent --output /dev/null)
  
  # Check if the API call was successful (HTTP status code 2xx)
  if [[ "$response" -ge 200 && "$response" -lt 300 ]]; then
    echo "Status update: COMPLETED"
  else
    # Log failure with the response code
    echo "API call failed with status code: $response"
  fi

  # Remove the local Docker image
  echo "Removing local Docker image..."
  sudo docker rmi "$DOCKERHUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG"

else
  echo "Docker image build and push failed."

  # If failed, make API call with status "FAILED"
  response=$(curl --location --globoff --request POST "$SERVER_URL/v1.0/ml/brick/image/$IMAGE_STATUS_ID?status=FAILED" \
    --data '' --write-out "%{http_code}" --silent --output /dev/null)
  
  # Check if the API call was successful (HTTP status code 2xx)
  if [[ "$response" -ge 200 && "$response" -lt 300 ]]; then
    echo "Status update: FAILED"
  else
    # Log failure with the response code
    echo "API call failed with status code: $response"
  fi
fi

# Clean up the temporary Dockerfile
rm -f Dockerfile
