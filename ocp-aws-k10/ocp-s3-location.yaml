kind: Profile
apiVersion: config.kio.kasten.io/v1alpha1
metadata:
  name: ${OCP_AWS_MY_OBJECT_STORAGE_PROFILE}
  namespace: kasten-io
spec:
  locationSpec:
    type: ObjectStore
    objectStore:
      endpoint: s3.ap-southeast-1.wasabisys.com
      name: ${OCP_AWS_MY_BUCKET}
      objectStoreType: S3
      region: ${OCP_AWS_MY_REGION}
    credential:
      secretType: AwsAccessKey
      secret:
        apiVersion: v1
        kind: secret
        name: k10-s3-secret
        namespace: kasten-io
  type: Location