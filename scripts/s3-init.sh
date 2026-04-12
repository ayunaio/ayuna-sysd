#!/bin/sh

# Configure the mc alias using environment variables
/usr/bin/mc alias set seaweedfs http://ayuna-seaweedfs:8333 $ADMIN_S3_ACCESS_KEY $ADMIN_S3_SECRET_KEY

# Wait for the MinIO server to be ready
# /usr/bin/mc ready seaweedfs || exit 1

# Create the bucket if it doesn't exist (-p ensures no error if it already exists)
/usr/bin/mc mb -p seaweedfs/ayuna/workspace
/usr/bin/mc mb -p seaweedfs/ayuna/uploads
/usr/bin/mc mb -p seaweedfs/ayuna/otel

# Optional: Set a public download policy for the bucket
# /usr/bin/mc policy set download seaweedfs/downloads

exit 0
